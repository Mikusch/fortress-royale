#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#define TF_MAXPLAYERS	32

#define TARGETNAME_BATTLEBUS_TRACK_DEST		"fr_battlebus_path_dest"
#define TARGETNAME_BATTLEBUS_PROP			"fr_battlebus_prop"
#define TARGETNAME_BATTLEBUS_DROP_DEST		"fr_battlebus_drop_dest"

#define CONTENTS_REDTEAM	CONTENTS_TEAM1
#define CONTENTS_BLUETEAM	CONTENTS_TEAM2

// TF2 Mannpower Powerups
enum TFRune
{
	TFRune_Strength = 0, 
	TFRune_Haste, 
	TFRune_Regen, 
	TFRune_Defense, 
	TFRune_Vampire, 
	TFRune_Reflect, 
	TFRune_Precision, 
	TFRune_Agility, 
	TFRune_Knockout, 
	TFRune_King, 
	TFRune_Plague, 
	TFRune_Supernova
}

bool g_IsRoundActive;

#include "royale/stocks.sp"
#include "royale/player.sp"
#include "royale/convar.sp"
#include "royale/sdk.sp"
#include "royale/battlebus.sp"

public void OnPluginStart()
{
	ConVar_Init();
	SDK_Init();
	
	ConVar_Toggle(true);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
	
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("arena_win_panel", Event_ArenaWinPanel);
}

public Action Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_IsRoundActive = true;
}

public Action Event_ArenaWinPanel(Event event, const char[] name, bool dontBroadcast)
{
	g_IsRoundActive = false;
}

public void OnPluginEnd()
{
	ConVar_Toggle(false);
}

public void OnMapStart()
{
	BattleBus_Precache();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_ShouldCollide, Client_ShouldCollide);
	
	BattleBus_SpectateBus(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_pipe"))
		SDKHook(entity, SDKHook_Touch, Pipebomb_Touch);
	else if (StrEqual(classname, "path_track"))
		SDKHook(entity, SDKHook_Spawn, PathTrack_Spawn);
	else if (StrEqual(classname, "prop_dynamic_override"))
		SDKHook(entity, SDKHook_Spawn, PropDynamicOverride_Spawn);
	else if (StrEqual(classname, "info_teleport_destination"))
		SDKHook(entity, SDKHook_Spawn, InfoTeleportDestination_Spawn);
	else if (StrContains(classname, "tf_weapon_sniperrifle") == 0 || StrEqual(classname, "tf_weapon_knife"))
		SDK_HookPrimaryAttack(entity);
	else if (StrEqual(classname, "tf_weapon_flamethrower"))
		SDK_HookFlamethrower(entity);
}

public Action Client_SetTransmit(int entity, int client)
{
	//Don't allow teammates see invis spy
	
	if (entity == client
		 || TF2_GetClientTeam(client) <= TFTeam_Spectator
		 || TF2_IsPlayerInCondition(entity, TFCond_Bleeding)
		 || TF2_IsPlayerInCondition(entity, TFCond_Jarated)
		 || TF2_IsPlayerInCondition(entity, TFCond_Milked)
		 || TF2_IsPlayerInCondition(entity, TFCond_OnFire)
		 || TF2_IsPlayerInCondition(entity, TFCond_Gas))
	{
		return Plugin_Continue;
	}
	
	if (TF2_GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public bool Client_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if (contentsmask & CONTENTS_REDTEAM || contentsmask & CONTENTS_BLUETEAM)
		return true;
	
	return originalResult;
}

public void Pipebomb_Touch(int entity, int other)
{
	//This function have team check, change grenade pipe to enemy team
	
	if (other == GetEntPropEnt(entity, Prop_Send, "m_hThrower"))
		return;
	
	TFTeam team = TF2_GetEnemyTeam(other);
	if (team <= TFTeam_Spectator)
		return;
	
	TF2_ChangeTeam(entity, team);
}

public void PathTrack_Spawn(int entity)
{
	char targetname[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	if (StrEqual(targetname, TARGETNAME_BATTLEBUS_TRACK_DEST))
		BattleBus_OnDestPathTrackSpawn(entity);
}

public void PropDynamicOverride_Spawn(int entity)
{
	char targetname[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	if (StrEqual(targetname, TARGETNAME_BATTLEBUS_PROP))
		BattleBus_OnPropSpawn(entity);
}

public void InfoTeleportDestination_Spawn(int entity)
{
	char targetname[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	if (StrEqual(targetname, TARGETNAME_BATTLEBUS_DROP_DEST))
		BattleBus_OnDropDestinationSpawn(entity);
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Changed;
}
