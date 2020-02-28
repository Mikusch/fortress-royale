#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#define TF_MAXPLAYERS	32

#define CONTENTS_REDTEAM	CONTENTS_TEAM1
#define CONTENTS_BLUETEAM	CONTENTS_TEAM2

#define MODEL_EMPTY			"models/empty.mdl"

const TFTeam TFTeam_Alive = TFTeam_Red;
const TFTeam TFTeam_Dead = TFTeam_Blue;

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

enum
{
	LifeState_Alive = 0,
	LifeState_Dead = 2
}

enum SolidType_t
{
	SOLID_NONE			= 0,	// no solid model
	SOLID_BSP			= 1,	// a BSP tree
	SOLID_BBOX			= 2,	// an AABB
	SOLID_OBB			= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM		= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
};

//bool g_IsRoundActive;

#include "royale/player.sp"

#include "royale/battlebus.sp"
#include "royale/console.sp"
#include "royale/convar.sp"
#include "royale/event.sp"
#include "royale/sdk.sp"
#include "royale/stocks.sp"

public void OnPluginStart()
{
	BattleBus_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
	SDK_Init();
	
	ConVar_Toggle(true);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	ConVar_Toggle(false);
}

public void OnMapStart()
{
	BattleBus_Precache();
	SDK_HookGamerules();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_ShouldCollide, Client_ShouldCollide);
	
	BattleBus_SpectateBus(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (FRPlayer(client).InBattleBus)
	{
		if (buttons & IN_JUMP)
			BattleBus_EjectClient(client);
		else
			buttons = 0;	//Don't allow client in battle bus process any other buttons
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_pipe"))
		SDKHook(entity, SDKHook_Touch, Pipebomb_Touch);
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

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Changed;
}
