/**
 * Copyright (C) 2023  Mikusch
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
#include <vscript>
#include <tf2items>
#include <pluginstatemanager>

#define PLUGIN_VERSION	"2.0.0"

ConVar fr_setup_length;
ConVar fr_truce_duration;
ConVar fr_crate_open_time;
ConVar fr_crate_open_range;
ConVar fr_crate_max_drops;
ConVar fr_crate_max_extra_drops;
ConVar fr_max_ammo_boost;
ConVar fr_parachute_auto_height;
ConVar fr_fists_damage_multiplier;
ConVar fr_medigun_damage;
ConVar fr_dropped_weapon_ammo_percentage;
ConVar fr_health_multiplier[view_as<int>(TFClass_Engineer) + 1];

ConVar mp_disable_respawn_times;
ConVar spec_freeze_traveltime;

bool g_bIsMapRunning;
bool g_bBypassGiveNamedItemHook;
bool g_bAllowForceRespawn;
bool g_bInHealthKitTouch;
bool g_bInGiveAmmo;
bool g_bFoundCrate;
FRRoundState g_nRoundState;

int g_iOffset_CTFDroppedWeapon_m_nAmmo;

#include "royale/shareddefs.sp"

#include "royale/battlebus.sp"
#include "royale/callbacks.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convars.sp"
#include "royale/player.sp"
#include "royale/dhooks.sp"
#include "royale/entity.sp"
#include "royale/events.sp"
#include "royale/sdkcalls.sp"
#include "royale/sdkhooks.sp"
#include "royale/truce.sp"
#include "royale/util.sp"
#include "royale/zone.sp"

public Plugin myinfo =
{
	name = "Fortress Royale",
	author = "Mikusch",
	description = "FFA Battle Royale gamemode for Team Fortress 2.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/fortress-royale"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("royale.phrases");
	
	GameData gamedata = new GameData("royale");
	if (!gamedata)
		SetFailState("Could not find royale gamedata");
	
	PSM_Init("fr_enabled", gamedata);
	PSM_AddPluginStateChangedHook(OnPluginStateChanged);

	FREntity.Init();
	
	Console_Init();
	ConVars_Init();
	DHooks_Init();
	Events_Init();
	
	SDKCalls_Init(gamedata);
	
	g_iOffset_CTFDroppedWeapon_m_nAmmo = gamedata.GetOffset("CTFDroppedWeapon::m_nAmmo");

	delete gamedata;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		strcopy(error, err_max, "This plugin is only compatible with Team Fortress 2!");
		return APLRes_Failure;
	}
	
	return APLRes_Success;
}

public void OnMapStart()
{
	g_bIsMapRunning = true;
	g_nRoundState = FRRoundState_Init;
	
	Config_Parse();
	Events_Precache();
	Truce_Precache();
	Zone_Precache();
}

public void OnMapEnd()
{
	g_bIsMapRunning = false;
	
	Config_Delete();
}

public void OnConfigsExecuted()
{
	PSM_TogglePluginState();
}

public void OnGameFrame()
{
	if (!PSM_IsEnabled())
		return;
	
	Zone_Think();
	
	// Switch between round states
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
			if (ShouldTryToEndMatch())
			{
				TryToEndMatch();
			}
		}
	}
	
	// Continuously damage medigun healing targets
	if (!GameRules_GetProp("m_bTruceActive"))
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || !IsPlayerAlive(client))
				continue;
			
			if (TF2_GetPlayerClass(client) != TFClass_Medic)
				continue;
			
			if (FRPlayer(client).m_flLastMedigunDrainTime >= GetGameTime() - 0.1)
				continue;
			
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(weapon) && IsWeaponOfID(weapon, TF_WEAPON_MEDIGUN))
			{
				int target = GetEntPropEnt(weapon, Prop_Send, "m_hHealingTarget");
				if (IsValidClient(target) && IsPlayerAlive(target))
				{
					float flMult = SDKCall_CTFPlayer_IsCritBoosted(client) ? 3.0 : 1.0;
					SDKHooks_TakeDamage(target, client, client, fr_medigun_damage.FloatValue * flMult, DMG_ENERGYBEAM);
					FRPlayer(client).m_flLastMedigunDrainTime = GetGameTime();
				}
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

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &item)
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;
	
	if (g_bBypassGiveNamedItemHook)
		return Plugin_Continue;
	
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	TFClassType nClass = TF2_GetPlayerClass(client);
	int iLoadoutSlot = TF2Econ_GetItemLoadoutSlot(itemDefIndex, nClass);
	
	if (iLoadoutSlot == -1)
		return Plugin_Continue;
	
	switch (nClass)
	{
		case TFClass_Engineer:
		{
			// Engineers keep their toolbox and their PDAs
			if (iLoadoutSlot == LOADOUT_POSITION_BUILDING || iLoadoutSlot == LOADOUT_POSITION_PDA || iLoadoutSlot == LOADOUT_POSITION_PDA2)
				return Plugin_Continue;
		}
		case TFClass_Spy:
		{
			// Spies keep their invis watch
			if (iLoadoutSlot == LOADOUT_POSITION_PDA2)
				return Plugin_Continue;
		}
	}
	
	// Keep cosmetics and action items (except Grappling Hook)
	if (iLoadoutSlot > LOADOUT_POSITION_PDA2 && !StrEqual(classname, "tf_weapon_grapplinghook"))
		return Plugin_Continue;
	
	// Remove everything else
	return Plugin_Handled;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefIndex, int level, int quality, int entity)
{
	Config_ApplyWeaponAttributes(entity, itemDefIndex);
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char section[32];
	if (kv.GetSectionName(section, sizeof(section)))
	{
		if (StrEqual(section, "+use_action_slot_item_server"))
		{
			if (FRPlayer(client).TryToPickupDroppedWeapon())
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;
	
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	Action action = Plugin_Continue;

	if (FRPlayer(client).m_nQueuedButtons != 0)
	{
		buttons |= FRPlayer(client).m_nQueuedButtons;
		FRPlayer(client).m_nQueuedButtons = 0;
		action = Plugin_Changed;
	}
	
	if (FRPlayer(client).m_bIsParachuting)
	{
		// Do not allow manual opening/closing of the parachute
		if (TF2_IsPlayerInCondition(client, TFCond_Parachute) && buttons & IN_JUMP)
		{
			buttons &= ~IN_JUMP;
			action = Plugin_Changed;
		}
		
		if (!TF2_IsPlayerInCondition(client, TFCond_Parachute))
		{
			float vecOrigin[3];
			CBaseEntity(client).GetAbsOrigin(vecOrigin);
			
			TR_TraceRayFilter(vecOrigin, { 90.0, 0.0, 0.0 }, MASK_SOLID, RayType_Infinite, TraceEntityFilter_HitWorld, _, TRACE_WORLD_ONLY);
			if (TR_DidHit() && TR_GetEntityIndex() == 0)
			{
				float vecEndPos[3];
				TR_GetEndPosition(vecEndPos);
				
				// Automatically open parachute a certain distance from the ground
				if (GetVectorDistance(vecOrigin, vecEndPos) <= fr_parachute_auto_height.FloatValue)
				{
					TF2_AddCondition(client, TFCond_Parachute);
					action = Plugin_Changed;
				}
			}
		}
	}
	
	return action;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	int afButtonChanged = GetEntProp(client, Prop_Data, "m_afButtonPressed") | GetEntProp(client, Prop_Data, "m_afButtonReleased");
	bool bInAttack2 = (buttons & IN_ATTACK2 && afButtonChanged & IN_ATTACK2);
	bool bInAttack3 = (buttons & IN_ATTACK3 && afButtonChanged & IN_ATTACK3);
	bool bInReload = (buttons & IN_RELOAD && afButtonChanged & IN_RELOAD);
	bool bInUse = (buttons & IN_USE && afButtonChanged & IN_USE);
	
	// Find a crate in range and open it
	if (OpenCrateInRange(client, buttons))
		return;
	else
		FRPlayer(client).StopOpeningCrate();
	
	// Ejecting from the bus (only allows +attack3 and +reload)
	if (bInAttack3 || bInReload || bInUse)
	{
		if (FRPlayer(client).GetPlayerState() == FRPlayerState_InBattleBus && BattleBus_EjectPlayer(client))
			return;
	}
	
	// Allow picking up weapons with +attack2, +attack3 and +reload
	if (bInAttack2 || bInAttack3 || bInReload || bInUse)
	{
		KeyValues kv = new KeyValues("+use_action_slot_item_server");
		FakeClientCommandKeyValues(client, kv);
		delete kv;

		kv = new KeyValues("-use_action_slot_item_server");
		FakeClientCommandKeyValues(client, kv);
		delete kv;
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (!PSM_IsEnabled())
		return;
	
	if (!IsPlayerAlive(client))
		return;
	
	if (condition == TFCond_Parachute && FRPlayer(client).m_bIsParachuting)
	{
		FRPlayer(client).m_bIsParachuting = false;
		
		// Remove our starting parachute
		for (int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); ++i)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if (weapon == -1)
				continue;
			
			if (!TF2Util_IsEntityWeapon(weapon) || TF2Util_GetWeaponID(weapon) != TF_WEAPON_PARACHUTE)
				continue;
			
			FRPlayer(client).RemoveItem(weapon);
			break;
		}
	}
}

static bool OpenCrateInRange(int client, int buttons)
{
	if (!IsPlayerAlive(client))
		return false;
	
	if (FRPlayer(client).IsInAVehicle())
		return false;
	
	if (TF2_IsPlayerInCondition(client, TFCond_Stealthed))
		return false;
	
	// Pressing and holding +attack2, +attack3 or +reload
	if (!(buttons & IN_ATTACK2 || buttons & IN_ATTACK3 || buttons & IN_RELOAD || buttons & IN_USE))
		return false;
	
	float vecEyeAngles[3], vecForward[3];
	GetClientEyeAngles(client, vecEyeAngles);
	GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
	
	float vecCenter[3];
	CBaseEntity(client).WorldSpaceCenter(vecCenter);
	
	ScaleVector(vecForward, fr_crate_open_range.FloatValue);
	AddVectors(vecCenter, vecForward, vecCenter);
	float vecSize[3] = { 24.0, 24.0, 24.0 };
	
	float vecMins[3], vecMaxs[3];
	SubtractVectors(vecCenter, vecSize, vecMins);
	AddVectors(vecCenter, vecSize, vecMaxs);
	
	g_bFoundCrate = false;
	TR_EnumerateEntitiesBox(vecMins, vecMaxs, PARTITION_NON_STATIC_EDICTS, EnumerateCrates, client);
	
	return g_bFoundCrate;
}

static bool EnumerateCrates(int entity, int client)
{
	if (FREntity(entity).IsValidCrate() && FRCrate(entity).CanBeOpenedBy(client))
	{
		g_bFoundCrate = true;
		FRPlayer(client).TryToOpenCrate(entity);
	}
	
	return !g_bFoundCrate;
}

public void OnClientPutInServer(int client)
{
	if (!PSM_IsEnabled())
		return;
	
	FRPlayer(client).Init();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!PSM_IsEnabled())
		return;
	
	DHooks_HookEntity(entity, classname);
	SDKHooks_HookEntity(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	if (!PSM_IsEnabled())
		return;
	
	PSM_SDKUnhook(entity);
	
	if (FREntity.IsEntityTracked(entity))
		FREntity(entity).Destroy();
}

static void OnPluginStateChanged(bool bEnabled)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1)
	{
		if (bEnabled)
		{
			char classname[64];
			if (!GetEntityClassname(entity, classname, sizeof(classname)))
				continue;
			
			OnEntityCreated(entity, classname);
		}
		else
		{
			if (FREntity.IsEntityTracked(entity))
				FREntity(entity).Destroy();
		}
	}

	if (GameRules_GetRoundState() >= RoundState_Preround && !GameRules_GetProp("m_bInWaitingForPlayers"))
	{
		ServerCommand("mp_restartgame_immediate 1");
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
		DispatchKeyValueFloat(timer, "setup_length", fr_setup_length.FloatValue);
		DispatchKeyValueInt(timer, "show_in_hud", 1);
		DispatchKeyValueInt(timer, "start_paused", 0);
		
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

void TryToEndMatch()
{
	int winner = -1;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (!FRPlayer(client).IsAlive())
			continue;
		
		// There is still more than one player alive, exit now
		if (IsValidClient(winner))
			return;
		
		winner = client;
	}
	
	g_nRoundState = FRRoundState_RoundEnd;
	
	if (IsValidClient(winner))
	{
		SetWinningTeam(TFTeam_Red);
		PrintToChatAll("%t", "MatchEnd_PlayerWin", winner);
	}
	else
	{
		// Stalemate
		SetWinningTeam(TFTeam_Spectator);
		PrintToChatAll("%t", "MatchEnd_Stalemate");
	}
}

static void EntityOutput_OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	if (IsInWaitingForPlayers())
		return;
	
	g_nRoundState = FRRoundState_RoundRunning;
	
	BattleBus_OnSetupFinished();
	Truce_OnSetupFinished();
	Zone_OnSetupFinished();
	
	int nCount = GetActivePlayerCount();
	float flPercentage = Max(0.5, float(nCount) / float(MaxClients));
	
	int crate = -1;
	while ((crate = FindEntityByClassname(crate, "prop_*")) != -1)
	{
		// Remove crates on low player counts
		if (FREntity(crate).IsValidCrate() && GetRandomFloat() > flPercentage)
		{
			RemoveEntity(crate);
		}
	}

	RemoveEntity(caller);
}
