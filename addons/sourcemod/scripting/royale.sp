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
	SDKHook(client, SDKHook_ShouldCollide, Entity_ShouldCollide);
}

public bool Entity_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if (contentsmask & CONTENTS_REDTEAM || contentsmask & CONTENTS_BLUETEAM)
		return true;
	
	return originalResult;
}