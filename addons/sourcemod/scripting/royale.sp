/**
 * Copyright (C) 2022  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sdkhooks>
#include <regex>
#include <tf2utils>
#include <tf_econ_data>
#include <tf2attributes>
#include <cbasenpc>
#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

ConVar fr_enable;
ConVar fr_setup_length;
ConVar fr_crate_open_time;
ConVar fr_crate_open_range;
ConVar fr_crate_max_drops;
ConVar fr_crate_max_extra_drops;
ConVar fr_zone_startdisplay;
ConVar fr_zone_startdisplay_player;
ConVar fr_zone_display;
ConVar fr_zone_display_player;
ConVar fr_zone_shrink;
ConVar fr_zone_shrink_player;
ConVar fr_zone_nextdisplay;
ConVar fr_zone_nextdisplay_player;
ConVar fr_zone_damage;
ConVar fr_parachute_auto_height;

ConVar mp_disable_respawn_times;
ConVar spec_freeze_traveltime;

bool g_bEnabled;
bool g_bTF2Items;
bool g_bBypassGiveNamedItemHook;
bool g_bAllowForceRespawn;
FRRoundState g_nRoundState;

#include "royale/shareddefs.sp"

#include "royale/battlebus.sp"
#include "royale/callbacks.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convars.sp"
#include "royale/data.sp"
#include "royale/dhooks.sp"
#include "royale/entity.sp"
#include "royale/events.sp"
#include "royale/sdkcalls.sp"
#include "royale/sdkhooks.sp"
#include "royale/util.sp"
#include "royale/zone.sp"

public Plugin myinfo =
{
	name = "Fortress Royale",
	author = "Mikusch",
	description = "FFA Battle Royale gamemode in Team Fortress 2.",
	version = "2.0.0",
	url = "https://github.com/Mikusch/fortress-royale"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("royale.phrases");
	
	g_bTF2Items = LibraryExists("TF2Items");
	
	ConVars_Init();
	Events_Init();
	
	GameData gamedata = new GameData("royale");
	if (gamedata)
	{
		DHooks_Init(gamedata);
		SDKCalls_Init(gamedata);
		
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find royale gamedata");
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "TF2Items"))
	{
		g_bTF2Items = true;
		
		if (g_bEnabled)
		{
			// Loading TF2Items while the plugin is active leads to crashes, pull the plug!
			if (DHooks_IsGiveNamedItemHookActive())
			{
				SetFailState("TF2Items was loaded while Fortress Royale is active, aborting plugin!");
			}
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "TF2Items"))
	{
		g_bTF2Items = false;
		
		// If TF2Items is being unloaded, use our own hook
		if (g_bEnabled)
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (!IsClientInGame(client))
					continue;
				
				DHooks_HookGiveNamedItem(client);
			}
		}
	}
}

public void OnMapStart()
{
	PrecacheSound(")ui/item_open_crate.wav");
	PrecacheSound(")ui/itemcrate_smash_rare.wav");
	
	g_nRoundState = FRRoundState_Init;
	
	Config_Parse();
	Zone_Precache();
}

public void OnMapEnd()
{
	Config_Delete();
}

public void OnConfigsExecuted()
{
	if (g_bEnabled != fr_enable.BoolValue)
	{
		TogglePlugin(fr_enable.BoolValue);
	}
}

public void OnGameFrame()
{
	if (!g_bEnabled)
		return;
	
	Zone_Think();
	
	switch (g_nRoundState)
	{
		case FRRoundState_WaitingForPlayers:
		{
			// Do we have enough players to start the game?
			if (ShouldGoToSetup())
			{
				g_nRoundState = FRRoundState_Setup;
				
				// Restart the map to go to setup
				ServerCommand("mp_restartgame_immediate 1");
			}
		}
		case FRRoundState_RoundRunning:
		{
			// Have all valid players died?
			if (ShouldTryToEndGame())
			{
				g_nRoundState = FRRoundState_PlayerWin;
				
				// Declare a winner!
				SetWinningTeam(TFTeam_Red);
			}
		}
	}
}

public void TF2_OnWaitingForPlayersStart()
{
	mp_disable_respawn_times.BoolValue = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	mp_disable_respawn_times.BoolValue = false;
	
	// If we have enough players, go straight to setup
	g_nRoundState = ShouldGoToSetup() ? FRRoundState_Setup : FRRoundState_WaitingForPlayers;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int index, Handle &item)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	return FR_OnGiveNamedItem(client, classname, index);
}

public Action FR_OnGiveNamedItem(int client, const char[] szWeaponName, int iItemDefIndex)
{
	if (g_bBypassGiveNamedItemHook)
		return Plugin_Continue;
	
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	TFClassType nClass = TF2_GetPlayerClass(client);
	int iLoadoutSlot = TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass);
	
	if (iLoadoutSlot == -1)
		return Plugin_Continue;
	
	// Let Engineer keep his toolbox
	if (iLoadoutSlot == LOADOUT_POSITION_BUILDING && nClass == TFClass_Engineer)
		return Plugin_Continue;
	
	// Let players keep their cosmetics and action items (except Grappling Hook)
	if (iLoadoutSlot > LOADOUT_POSITION_PDA2 && !StrEqual(szWeaponName, "tf_weapon_grapplinghook"))
		return Plugin_Continue;
	
	// Remove everything else
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	ProcessCrateOpening(client, buttons);
	
	if (FRPlayer(client).GetPlayerState() == FRPlayerState_InBattleBus)
	{
		if (buttons & IN_RELOAD)
		{
			BattleBus_EjectPlayer(client);
		}
	}
	
	// We are falling from the bus...
	if (FRPlayer(client).m_bIsParachuting)
	{
		if (TF2_IsPlayerInCondition(client, TFCond_Parachute))
		{
			// Don't allow closing the starting parachute
			if (buttons & IN_JUMP)
			{
				buttons &= ~IN_JUMP;
				return Plugin_Changed;
			}
		}
		else
		{
			float vecOrigin[3];
			CBaseCombatCharacter(client).GetAbsOrigin(vecOrigin);
			
			TR_TraceRayFilter(vecOrigin, { 90.0, 0.0, 0.0 }, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitPlayers, client);
			if (TR_DidHit())
			{
				float vecEndPos[3];
				TR_GetEndPosition(vecEndPos);
				
				// Automatically open our parachute
				if (GetVectorDistance(vecOrigin, vecEndPos) <= fr_parachute_auto_height.FloatValue)
				{
					buttons |= IN_JUMP;
					return Plugin_Changed;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (!g_bEnabled)
		return;
	
	if (!IsPlayerAlive(client))
		return;
	
	if (condition == TFCond_Parachute && FRPlayer(client).m_bIsParachuting)
	{
		FRPlayer(client).m_bIsParachuting = false;
		
		// Remove the starting parachute
		for (int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); ++i)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if (weapon == -1)
				continue;
			
			if (!TF2Util_IsEntityWeapon(weapon))
				continue;
			
			if (TF2Util_GetWeaponID(weapon) != TF_WEAPON_PARACHUTE)
				continue;
			
			FRPlayer(client).RemoveItem(weapon);
			break;
		}
	}
}

static bool ProcessCrateOpening(int client, int buttons)
{
	if (IsPlayerAlive(client) && (buttons & IN_RELOAD) && !FRPlayer(client).IsInAVehicle())
	{
		float vecEyePosition[3], vecEyeAngles[3];
		GetClientEyePosition(client, vecEyePosition);
		GetClientEyeAngles(client, vecEyeAngles);
		
		float vecForward[3];
		GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
		
		ScaleVector(vecForward, fr_crate_open_range.FloatValue);
		AddVectors(vecForward, vecEyePosition, vecForward);
		
		TR_TraceRayFilter(vecEyePosition, vecForward, MASK_SOLID, RayType_EndPoint, TraceEntityFilter_HitCrates, client, TRACE_ENTITIES_ONLY);
		
		if (TR_GetFraction() != 1.0 && TR_DidHit())
		{
			int entity = TR_GetEntityIndex();
			return FREntity(entity).IsValidCrate() && FRCrate(entity).CanUse(client) && FRPlayer(client).TryToOpenCrate(entity);
		}
	}
	
	FRPlayer(client).StopOpeningCrate();
	return false;
}

static bool TraceEntityFilter_HitCrates(int entity, int mask, int client)
{
	return FREntity(entity).IsValidCrate() && FRCrate(entity).CanUse(client);
}

static bool TraceEntityFilter_DontHitPlayers(int entity, int mask, int client)
{
	return !(0 < entity <= MaxClients);
}

public void OnClientPutInServer(int client)
{
	if (!g_bEnabled)
		return;
	
	FRPlayer(client).Init();
	
	DHooks_OnClientPutInServer(client);
	SDKHooks_OnClientPutInServer(client);
}

public void OnEntityDestroyed(int entity)
{
	if (!g_bEnabled)
		return;
	
	FREntity(entity).Destroy();
}

void TogglePlugin(bool bEnable)
{
	g_bEnabled = bEnable;
	
	Console_Toggle(bEnable);
	ConVars_Toggle(bEnable);
	DHooks_Toggle(bEnable);
	Events_Toggle(bEnable);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (bEnable)
			{
				OnClientPutInServer(client);
			}
			else
			{
				SDKHooks_UnhookClient(client);
			}
		}
	}
}

void OnRoundStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		// Init player and set them into waiting state
		FRPlayer(client).Init();
		
		if (TF2_GetClientTeam(client) > TFTeam_Spectator)
		{
			FRPlayer(client).RemoveAllItems();
			
			if (IsPlayerAlive(client))
			{
				// Make sure the player is actually dead
				SetEntProp(client, Prop_Send, "m_lifeState", LIFE_DEAD);
				TF2_ChangeClientTeam(client, TFTeam_Spectator);
			}
			
			// Move all non-spectators to dead team
			TF2_ChangeClientTeam(client, TFTeam_Blue);
		}
	}
	
	// Create a setup timer
	int timer = CreateEntityByName("team_round_timer");
	if (IsValidEntity(timer))
	{
		char szSetupLength[8];
		fr_setup_length.GetString(szSetupLength, sizeof(szSetupLength));
		
		DispatchKeyValue(timer, "setup_length", szSetupLength);
		DispatchKeyValue(timer, "show_in_hud", "1");
		DispatchKeyValue(timer, "start_paused", "0");
		
		if (DispatchSpawn(timer))
		{
			AcceptEntityInput(timer, "Enable");
			HookSingleEntityOutput(timer, "OnSetupFinished", EntityOutput_OnSetupFinished, true);
			
			Event event = CreateEvent("teamplay_update_timer");
			if (event)
			{
				event.Fire();
			}
		}
	}
	
	Zone_OnRoundStart();
}

static void EntityOutput_OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
}
