#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#define CONTENTS_REDTEAM	CONTENTS_TEAM1
#define CONTENTS_BLUETEAM	CONTENTS_TEAM2

#include "royale/convar.sp"
#include "royale/sdk.sp"
#include "royale/stocks.sp"

public void OnPluginStart()
{
	ConVar_Init();
	SDK_Init();
	
	ConVar_Toggle(true);
	
	for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client))
			OnClientPutInServer(client);
}

public void OnPluginEnd()
{
	ConVar_Toggle(false);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_ShouldCollide, Client_ShouldCollide);
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