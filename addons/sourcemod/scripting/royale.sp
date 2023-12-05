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
#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

ConVar sm_fr_enable;
ConVar sm_fr_setup_length;
ConVar sm_fr_truce_duration;
ConVar sm_fr_crate_open_time;
ConVar sm_fr_crate_open_range;
ConVar sm_fr_crate_max_drops;
ConVar sm_fr_crate_max_extra_drops;
ConVar sm_fr_max_ammo_boost;
ConVar sm_fr_parachute_auto_height;
ConVar sm_fr_fists_damage_multiplier;
ConVar sm_fr_medigun_damage;
ConVar sm_fr_dropped_weapon_ammo_percentage;
ConVar sm_fr_zone_startdisplay;
ConVar sm_fr_zone_startdisplay_player;
ConVar sm_fr_zone_display;
ConVar sm_fr_zone_display_player;
ConVar sm_fr_zone_shrink;
ConVar sm_fr_zone_shrink_player;
ConVar sm_fr_zone_nextdisplay;
ConVar sm_fr_zone_nextdisplay_player;
ConVar sm_fr_zone_damage_min;
ConVar sm_fr_zone_damage_max;
ConVar sm_fr_health_multiplier[view_as<int>(TFClass_Engineer) + 1];

ConVar mp_disable_respawn_times;
ConVar spec_freeze_traveltime;

bool g_bEnabled;
bool g_bTF2Items;
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
#include "royale/data.sp"
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
	version = "2.0.0",
	url = "https://github.com/Mikusch/fortress-royale"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("royale.phrases");
	
	g_bTF2Items = LibraryExists(LIBRARY_TF2ITEMS);
	
	Console_Init();
	ConVars_Init();
	Events_Init();
	
	GameData gamedata = new GameData("royale");
	if (gamedata)
	{
		DHooks_Init(gamedata);
		SDKCalls_Init(gamedata);
		
		g_iOffset_CTFDroppedWeapon_m_nAmmo = gamedata.GetOffset("CTFDroppedWeapon::m_nAmmo");
		
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find royale gamedata");
	}
}

public void OnPluginEnd()
{
	if (!g_bEnabled)
		return;
	
	TogglePlugin(false);
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

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, LIBRARY_TF2ITEMS))
	{
		g_bTF2Items = true;
		
		// Loading TF2Items while our own GiveNamedItem hook is active leads to crashes. Abort now!
		if (g_bEnabled && DHooks_IsGiveNamedItemHookActive())
		{
			SetFailState("TF2Items was loaded while Fortress Royale is active!");
		}
	}
	
	ConVars_OnLibraryAdded(name);
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, LIBRARY_TF2ITEMS))
	{
		g_bTF2Items = false;
		
		// If TF2Items is being unloaded, use our own hook instead
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
	
	ConVars_OnLibraryRemoved(name);
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
	if (g_bEnabled != sm_fr_enable.BoolValue)
	{
		TogglePlugin(sm_fr_enable.BoolValue);
	}
	else if (g_bEnabled)
	{
		OnPluginEnabled();
	}
}

public void OnGameFrame()
{
	if (!g_bEnabled)
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
					SDKHooks_TakeDamage(target, client, client, sm_fr_medigun_damage.FloatValue * flMult, DMG_ENERGYBEAM);
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
	if (!g_bEnabled)
		return Plugin_Continue;
	
	return FR_OnGiveNamedItem(client, classname, itemDefIndex);
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
	
	int afButtonChanged = GetEntProp(client, Prop_Data, "m_afButtonPressed") | GetEntProp(client, Prop_Data, "m_afButtonReleased");
	bool bInAttack2 = (buttons & IN_ATTACK2 && afButtonChanged & IN_ATTACK2);
	bool bInAttack3 = (buttons & IN_ATTACK3 && afButtonChanged & IN_ATTACK3);
	bool bInReload = (buttons & IN_RELOAD && afButtonChanged & IN_RELOAD);
	
	// Find a crate in range and open it
	if (OpenCrateInRange(client, buttons))
		return Plugin_Continue;
	else
		FRPlayer(client).StopOpeningCrate();
	
	// Ejecting from the bus (only allows +attack3 and +reload)
	if (bInAttack3 || bInReload)
	{
		if (FRPlayer(client).GetPlayerState() == FRPlayerState_InBattleBus && BattleBus_EjectPlayer(client))
			return Plugin_Continue;
	}
	
	// Allow picking up weapons with +attack2, +attack3 and +reload
	if (bInAttack2 || bInAttack3 || bInReload)
	{
		if (SDKCall_CTFPlayer_TryToPickupDroppedWeapon(client))
			return Plugin_Continue;
	}
	
	Action action = Plugin_Continue;
	
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
				if (GetVectorDistance(vecOrigin, vecEndPos) <= sm_fr_parachute_auto_height.FloatValue)
				{
					TF2_AddCondition(client, TFCond_Parachute);
					action = Plugin_Changed;
				}
			}
		}
	}
	
	return action;
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
	if (!(buttons & IN_ATTACK2 || buttons & IN_ATTACK3 || buttons & IN_RELOAD))
		return false;
	
	float vecEyeAngles[3], vecForward[3];
	GetClientEyeAngles(client, vecEyeAngles);
	GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
	
	float vecCenter[3];
	CBaseEntity(client).WorldSpaceCenter(vecCenter);
	
	ScaleVector(vecForward, sm_fr_crate_open_range.FloatValue);
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
	if (!g_bEnabled)
		return;
	
	FRPlayer(client).Init();
	
	DHooks_OnClientPutInServer(client);
	SDKHooks_OnClientPutInServer(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnabled)
		return;
	
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	FREntity(entity).Destroy();
	
	if (!g_bEnabled)
		return;
	
	BattleBus_OnEntityDestroyed(entity);
}

void TogglePlugin(bool bEnable)
{
	g_bEnabled = bEnable;
	
	Console_Toggle(bEnable);
	ConVars_Toggle(bEnable);
	DHooks_Toggle(bEnable);
	Events_Toggle(bEnable);
	
	if (bEnable)
	{
		OnPluginEnabled();
	}
	else
	{
		OnPluginDisabled();
	}
	
	ServerCommand("mp_restartgame_immediate 1");
}

void OnPluginEnabled()
{
	SetVariantString("ForceEnableUpgrades(2)");
	AcceptEntityInput(0, "RunScriptCode");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		OnClientPutInServer(client);
	}
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1)
	{
		char classname[64];
		if (GetEntityClassname(entity, classname, sizeof(classname)))
		{
			OnEntityCreated(entity, classname);
		}
	}
}

void OnPluginDisabled()
{
	SetVariantString("ForceEnableUpgrades(0)");
	AcceptEntityInput(0, "RunScriptCode");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		SDKHooks_UnhookClient(client);
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
		DispatchKeyValueFloat(timer, "setup_length", sm_fr_setup_length.FloatValue);
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
	RemoveEntity(caller);
}
