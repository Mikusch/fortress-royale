/*
 * Copyright (C) 2020  Mikusch & 42
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

enum struct DetourInfo
{
	DynamicDetour detour;
	char name[64];
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

enum ThinkFunction
{
	ThinkFunction_None,
	ThinkFunction_SapperThink,
	ThinkFunction_DispenseThink,
	ThinkFunction_SentryThink,
	ThinkFunction_RegenThink,
	ThinkFunction_TossJarThink,
}

static DynamicHook g_DHookGetMaxHealth;
static DynamicHook g_DHookForceRespawn;
static DynamicHook g_DHookGiveNamedItem;
static DynamicHook g_DHookGrenadeExplode;
static DynamicHook g_DHookFireballExplode;
static DynamicHook g_DHookGetLiveTime;
static DynamicHook g_DHookStartBuilding;
static DynamicHook g_DHookGetBaseHealth;
static DynamicHook g_DHookSetPassenger;

static int g_HookIdGiveNamedItem[TF_MAXPLAYERS + 1];
static int g_HookIdGetMaxHealthPre[TF_MAXPLAYERS + 1];
static int g_HookIdGetMaxHealthPost[TF_MAXPLAYERS + 1];
static int g_HookIdForceRespawnPre[TF_MAXPLAYERS + 1];
static int g_HookIdForceRespawnPost[TF_MAXPLAYERS + 1];

static ArrayList g_DetourInfo;
static ThinkFunction g_ThinkFunction;

void DHook_Init(GameData gamedata)
{
	g_DetourInfo = new ArrayList(sizeof(DetourInfo));
	
	DHook_CreateDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHook_PhysicsDispatchThinkPre, DHook_PhysicsDispatchThinkPost);
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeamPre, _);
	DHook_CreateDetour(gamedata, "CTFDroppedWeapon::Create", DHook_CreatePre, _);
	DHook_CreateDetour(gamedata, "CEyeballBoss::FindClosestVisibleVictim", DHook_FindClosestVisibleVictimPre, DHook_FindClosestVisibleVictimPost);
	DHook_CreateDetour(gamedata, "CLagCompensationManager::StartLagCompensation", DHook_StartLagCompensationPre, DHook_StartLagCompensationPost);
	DHook_CreateDetour(gamedata, "CTFPlayerMove::SetupMove", DHook_SetupMovePre, _);
	
	g_DHookGetMaxHealth = DHook_CreateVirtual(gamedata, "CBaseEntity::GetMaxHealth");
	g_DHookForceRespawn = DHook_CreateVirtual(gamedata, "CBasePlayer::ForceRespawn");
	g_DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	g_DHookGrenadeExplode = DHook_CreateVirtual(gamedata, "CBaseGrenade::Explode");
	g_DHookFireballExplode = DHook_CreateVirtual(gamedata, "CTFProjectile_SpellFireball::Explode");
	g_DHookGetLiveTime = DHook_CreateVirtual(gamedata, "CTFGrenadePipebombProjectile::GetLiveTime");
	g_DHookStartBuilding = DHook_CreateVirtual(gamedata, "CBaseObject::StartBuilding");
	g_DHookGetBaseHealth = DHook_CreateVirtual(gamedata, "CBaseObject::GetBaseHealth");
	g_DHookSetPassenger = DHook_CreateVirtual(gamedata, "CBaseServerVehicle::SetPassenger");
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		DetourInfo info;
		info.detour = detour;
		strcopy(info.name, sizeof(info.name), name);
		info.callbackPre = callbackPre;
		info.callbackPost = callbackPost;
		g_DetourInfo.PushArray(info);
	}
}

static DynamicHook DHook_CreateVirtual(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create virtual: %s", name);

	return hook;
}

void DHook_Enable()
{
	int length = g_DetourInfo.Length;
	for (int i = 0; i < length; i++)
	{
		DetourInfo info;
		g_DetourInfo.GetArray(i, info);
		
		if (info.callbackPre != INVALID_FUNCTION)
			if (!info.detour.Enable(Hook_Pre, info.callbackPre))
				LogError("Failed to enable pre detour: %s", info.name);
		
		if (info.callbackPost != INVALID_FUNCTION)
			if (!info.detour.Enable(Hook_Post, info.callbackPost))
				LogError("Failed to enable post detour: %s", info.name);
	}
}

void DHook_Disable()
{
	int length = g_DetourInfo.Length;
	for (int i = 0; i < length; i++)
	{
		DetourInfo info;
		g_DetourInfo.GetArray(i, info);
		
		if (info.callbackPre != INVALID_FUNCTION)
			if (!info.detour.Disable(Hook_Pre, info.callbackPre))
				LogError("Failed to disable pre detour: %s", info.name);
		
		if (info.callbackPost != INVALID_FUNCTION)
			if (!info.detour.Disable(Hook_Post, info.callbackPost))
				LogError("Failed to disable post detour: %s", info.name);
	}
}

void DHook_HookGiveNamedItem(int client)
{
	if (g_DHookGiveNamedItem && !g_TF2Items)
		g_HookIdGiveNamedItem[client] = g_DHookGiveNamedItem.HookEntity(Hook_Pre, client, DHook_GiveNamedItemPre, DHook_GiveNamedItemRemoved);
}

void DHook_UnhookGiveNamedItem(int client)
{
	if (g_HookIdGiveNamedItem[client])
	{
		DynamicHook.RemoveHook(g_HookIdGiveNamedItem[client]);
		g_HookIdGiveNamedItem[client] = 0;
	}
}

bool DHook_IsGiveNamedItemActive()
{
	for (int client = 1; client <= MaxClients; client++)
		if (g_HookIdGiveNamedItem[client])
			return true;
	
	return false;
}

void DHook_HookClient(int client)
{
	g_HookIdGetMaxHealthPre[client] = g_DHookGetMaxHealth.HookEntity(Hook_Pre, client, DHook_GetMaxHealthPre);
	g_HookIdGetMaxHealthPost[client] = g_DHookGetMaxHealth.HookEntity(Hook_Post, client, DHook_GetMaxHealthPost);
	g_HookIdForceRespawnPre[client] = g_DHookForceRespawn.HookEntity(Hook_Pre, client, DHook_ForceRespawnPre);
	g_HookIdForceRespawnPost[client] = g_DHookForceRespawn.HookEntity(Hook_Post, client, DHook_ForceRespawnPost);
}

void DHook_UnhookClient(int client)
{
	DynamicHook.RemoveHook(g_HookIdGetMaxHealthPre[client]);
	DynamicHook.RemoveHook(g_HookIdGetMaxHealthPost[client]);
	DynamicHook.RemoveHook(g_HookIdForceRespawnPre[client]);
	DynamicHook.RemoveHook(g_HookIdForceRespawnPost[client]);
}

void DHook_HookVehicle(int vehicle)
{
	g_DHookSetPassenger.HookRaw(Hook_Pre, GetServerVehicle(vehicle), DHook_SetPassenger);
}

void DHook_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "tf_projectile_jar") == 0 || StrEqual(classname, "tf_projectile_spellbats"))
	{
		g_DHookGrenadeExplode.HookEntity(Hook_Pre, entity, DHook_GrenadeExplodePre);
		g_DHookGrenadeExplode.HookEntity(Hook_Post, entity, DHook_GrenadeExplodePost);
	}
	else if (StrEqual(classname, "tf_projectile_spellfireball"))
	{
		g_DHookFireballExplode.HookEntity(Hook_Pre, entity, DHook_FireballExplodePre);
		g_DHookFireballExplode.HookEntity(Hook_Post, entity, DHook_FireballExplodePost);
	}
	else if (StrContains(classname, "tf_projectile_pipe") == 0)
	{
		g_DHookGetLiveTime.HookEntity(Hook_Pre, entity, DHook_GetLiveTimePre);
		g_DHookGetLiveTime.HookEntity(Hook_Post, entity, DHook_GetLiveTimePost);
	}
	else if (StrContains(classname, "obj_") == 0)
	{
		g_DHookStartBuilding.HookEntity(Hook_Pre, entity, DHook_StartBuildingPre);
		g_DHookStartBuilding.HookEntity(Hook_Post, entity, DHook_StartBuildingPost);
		g_DHookGetBaseHealth.HookEntity(Hook_Post, entity, DHook_GetBaseHealthPost);
	}
}

public MRESReturn DHook_PhysicsDispatchThinkPre(int entity)
{
	//This detour calls everytime an entity was about to call a think function, useful as it only requires 1 gamedata
	
	char classname[256];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (StrEqual(classname, "obj_attachment_sapper"))
	{
		g_ThinkFunction = ThinkFunction_SapperThink;
		
		//Always set team to spectator so sapper can sap both teams
		TF2_ChangeTeam(entity, TFTeam_Spectator);
		
		//Vampire powerup heals owner on damaging building
		GameRules_SetProp("m_bPowerupMode", true);
	}
	else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		if (!GetEntProp(entity, Prop_Send, "m_bPlacing") && !GetEntProp(entity, Prop_Send, "m_bBuilding") && SDKCall_GetNextThink(entity, "DispenseThink") == TICK_NEVER_THINK)	// CObjectDispenser::DispenseThink
		{
			g_ThinkFunction = ThinkFunction_DispenseThink;
			
			//Disallow players able to be healed from dispenser
			TFTeam team = TF2_GetTeam(entity);
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					FRPlayer(client).Team = TF2_GetTeam(client);
					bool friendly = TF2_IsObjectFriendly(entity, client);
					
					if (friendly && FRPlayer(client).Team != team)
						FRPlayer(client).SwapToEnemyTeam();
					else if (!friendly && FRPlayer(client).Team == team)
						FRPlayer(client).SwapToEnemyTeam();
				}
			}
		}
	}
	else if (StrEqual(classname, "obj_sentrygun"))	// CObjectSentrygun::SentryThink
	{
		g_ThinkFunction = ThinkFunction_SentryThink;
		
		//Sentry can only target one team, move all friendly to sentry team, move everyone else to enemy team.
		//CTeam class is used to collect players, so m_iTeamNum change wont be enough to fix it.
		TFTeam teamFriendly = TF2_GetTeam(entity);
		TFTeam teamEnemy = TF2_GetEnemyTeam(teamFriendly);
		Address team = SDKCall_GetGlobalTeam(teamEnemy);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				FRPlayer(client).Team = TF2_GetTeam(client);
				bool friendly = TF2_IsObjectFriendly(entity, client);
				
				if (friendly && FRPlayer(client).Team == teamEnemy)
					SDKCall_RemovePlayer(team, client);
				else if (!friendly && FRPlayer(client).Team != teamEnemy)
					SDKCall_AddPlayer(team, client);
			}
		}
		
		int building = MaxClients + 1;
		while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
		{
			if (!GetEntProp(building, Prop_Send, "m_bPlacing"))
			{
				FREntity(building).Team = TF2_GetTeam(building);
				if (TF2_IsObjectFriendly(entity, building))
					SDKCall_ChangeTeam(building, teamFriendly);
				else
					SDKCall_ChangeTeam(building, teamEnemy);
			}
		}
		
		//eyeball_boss uses InSameTeam check but obj_sentrygun owner is itself
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", GetEntPropEnt(entity, Prop_Send, "m_hBuilder"));
	}
	
	else if (StrEqual(classname, "player"))
	{
		if (IsPlayerAlive(entity) && SDKCall_GetNextThink(entity, "RegenThink") == TICK_NEVER_THINK)	// CTFPlayer::RegenThink
		{
			g_ThinkFunction = ThinkFunction_RegenThink;
			
			//Disable Medic health regen
			FRPlayer(entity).ChangeToUnknown();
		}
	}
	
	else if (StrEqual(classname, "tf_weapon_spellbook"))	// CTFJar::TossJarThink
	{
		g_ThinkFunction = ThinkFunction_TossJarThink;
		
		//Allow self-spell only take effects to themself
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (0 < owner <= MaxClients && IsClientInGame(owner))
			FRPlayer(owner).ChangeToSpectator();
	}
}

public MRESReturn DHook_PhysicsDispatchThinkPost(int entity)
{
	switch (g_ThinkFunction)
	{
		case ThinkFunction_SapperThink:
		{
			GameRules_SetProp("m_bPowerupMode", false);
		}
		case ThinkFunction_DispenseThink:
		{
			TFTeam team = TF2_GetTeam(entity);
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					bool friendly = TF2_IsObjectFriendly(entity, client);
					
					if (friendly && FRPlayer(client).Team != team)
						FRPlayer(client).SwapToOriginalTeam();
					else if (!friendly && FRPlayer(client).Team == team)
						FRPlayer(client).SwapToOriginalTeam();
				}
			}
		}
		
		case ThinkFunction_SentryThink:
		{
			TFTeam enemyTeam = TF2_GetEnemyTeam(TF2_GetTeam(entity));
			Address team = SDKCall_GetGlobalTeam(enemyTeam);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					bool friendly = TF2_IsObjectFriendly(entity, client);
					
					if (friendly && FRPlayer(client).Team == enemyTeam)
						SDKCall_AddPlayer(team, client);
					else if (!friendly && FRPlayer(client).Team != enemyTeam)
						SDKCall_RemovePlayer(team, client);
				}
			}
			
			int building = MaxClients + 1;
			while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
				if (!GetEntProp(building, Prop_Send, "m_bPlacing"))
					SDKCall_ChangeTeam(building, FREntity(building).Team);
			
			SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", entity);
		}
		
		case ThinkFunction_RegenThink:
		{
			FRPlayer(entity).ChangeToClass();
		}
		
		case ThinkFunction_TossJarThink:
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			if (0 < owner <= MaxClients && IsClientInGame(owner))
				FRPlayer(owner).ChangeToTeam();
		}
	}
	
	g_ThinkFunction = ThinkFunction_None;
}

public MRESReturn DHook_InSameTeamPre(int entity, DHookReturn ret, DHookParam param)
{
	//In friendly fire we only want to return true if both entity owner is the same
	
	if (param.IsNull(1))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	int other = param.Get(1);
	
	entity = GetOwnerLoop(entity);
	other = GetOwnerLoop(other);
	
	ret.Value = entity == other;
	return MRES_Supercede;
}

public MRESReturn DHook_CreatePre(DHookReturn ret, DHookParam param)
{
	//Don't create any dropped weapon created by TF2 (TF2_CreateDroppedWeapon passes client param as NULL)
	if (!GameRules_GetProp("m_bInWaitingForPlayers") && !param.IsNull(1))
	{
		ret.Value = 0;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_FindClosestVisibleVictimPre(int eyeball)
{
	//This function only targets one team, red or blu team
	//Move owner back to normal team, move everyone else to enemy team
	int client = GetEntPropEnt(eyeball, Prop_Send, "m_hOwnerEntity");
	if (client <= 0 || client > MaxClients)
		return;
	
	TFTeam teamFriendly = TF2_GetTeam(client);
	TFTeam teamEnemy = TF2_GetEnemyTeam(teamFriendly);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && i != client)
		{
			FRPlayer(i).Team = TF2_GetTeam(i);
			TF2_ChangeTeam(i, teamEnemy);
		}
	}
	
	int building = MaxClients + 1;
	while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
	{
		FREntity(building).Team = TF2_GetTeam(building);
		if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") == client)
			TF2_ChangeTeam(building, teamFriendly);
		else
			TF2_ChangeTeam(building, teamEnemy);
	}
	
	int boss = MaxClients + 1;
	while ((boss = FindEntityByClassname(boss, "eyeball_boss")) > MaxClients)
	{
		//Dont care if eyeball should attack another eyeball, always be friendly
		FREntity(boss).Team = TF2_GetTeam(boss);
		TF2_ChangeTeam(boss, teamFriendly);
	}
}

public MRESReturn DHook_FindClosestVisibleVictimPost(int eyeball)
{
	int client = GetEntPropEnt(eyeball, Prop_Send, "m_hOwnerEntity");
	if (client <= 0 || client > MaxClients)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && i != client)
			TF2_ChangeTeam(i, FRPlayer(i).Team);
	}
	
	int building = MaxClients + 1;
	while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
		TF2_ChangeTeam(building, FREntity(building).Team);
	
	int boss = MaxClients + 1;
	while ((boss = FindEntityByClassname(boss, "eyeball_boss")) > MaxClients)
		TF2_ChangeTeam(boss, FREntity(boss).Team);
}

public MRESReturn DHook_StartLagCompensationPre(Address manager, DHookParam param)
{
	//Lag compensate teammates
	//CTFPlayer::WantsLagCompensationOnEntity virtual hook could've been done instead,
	//but expensive as it called to each clients while this detour only calls once
	int client = param.Get(1);
	FRPlayer(client).ChangeToSpectator();
}

public MRESReturn DHook_StartLagCompensationPost(Address manager, DHookParam param)
{
	int client = param.Get(1);
	FRPlayer(client).ChangeToTeam();
}

public MRESReturn DHook_SetupMovePre(DHookParam param)
{
	int client = param.Get(1);
	
	int vehicle = GetEntPropEnt(client, Prop_Send, "m_hVehicle");
	if (vehicle != INVALID_ENT_REFERENCE)
	{
		Address ucmd = param.Get(2);
		Address helper = param.Get(3);
		Address move = param.Get(4);
		
		SDKCall_VehicleSetupMove(vehicle, client, ucmd, helper, move);
	}
}

public MRESReturn DHook_GetMaxHealthPre(int client)
{
	//Hooks may be changing client class, change class back to what it was
	FRPlayer(client).ChangeToClass();
}

public MRESReturn DHook_GetMaxHealthPost(int client)
{
	FRPlayer(client).ChangeToUnknown();
}

public MRESReturn DHook_ForceRespawnPre(int client)
{
	//Enable Mannpower uber during waiting for players and allow RuneRegenThink to start
	GameRules_SetProp("m_bPowerupMode", true);
	
	//Don't do all of our custom stuff during waiting for players
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return MRES_Ignored;
	
	//Only allow respawn if player is in parachute mode
	if (FRPlayer(client).PlayerState != PlayerState_Parachute)
		return MRES_Supercede;
	
	//If player havent selected a class, pick random class for em
	//this is so that player can actually spawn into map, otherwise nothing happens
	if (fr_randomclass.BoolValue || view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass")) == TFClass_Unknown)
		SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
	
	return MRES_Ignored;
}

public MRESReturn DHook_ForceRespawnPost(int client)
{
	GameRules_SetProp("m_bPowerupMode", false);
}

public MRESReturn DHook_GiveNamedItemPre(int client, DHookReturn ret, DHookParam param)
{
	if (param.IsNull(1) || param.IsNull(3))
	{
		ret.Value = 0;
		return MRES_Supercede;
	}
	
	char classname[256];
	param.GetString(1, classname, sizeof(classname));
	int index = param.GetObjectVar(3, g_OffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	if (TF2_OnGiveNamedItem(client, classname, index) >= Plugin_Handled)
	{
		ret.Value = 0;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public void DHook_GiveNamedItemRemoved(int hookid)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_HookIdGiveNamedItem[iClient] == hookid)
		{
			g_HookIdGiveNamedItem[iClient] = 0;
			return;
		}
	}
}

public MRESReturn DHook_GrenadeExplodePre(int entity)
{
	//Change both projectile and owner to spectator, so effect applies to both red and blu, but not owner itself
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(entity, TFTeam_Spectator);
	}
}

public MRESReturn DHook_GrenadeExplodePost(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(entity, FRPlayer(owner).Team);
	}
}

public MRESReturn DHook_FireballExplodePre(int entity)
{
	//Change both projectile and owner to spectator, so effect applies to both red and blu, but not owner itself
	int owner = GetOwnerLoop(entity);
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(entity, TFTeam_Spectator);
	}
}

public MRESReturn DHook_FireballExplodePost(int entity)
{
	int owner = GetOwnerLoop(entity);
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(entity, FRPlayer(owner).Team);
	}
}

public MRESReturn DHook_GetLiveTimePre(int entity)
{
	//Haste and King powerup allows sticky to detonate sooner
	GameRules_SetProp("m_bPowerupMode", true);
}

public MRESReturn DHook_GetLiveTimePost(int entity)
{
	GameRules_SetProp("m_bPowerupMode", false);
}

public MRESReturn DHook_StartBuildingPre(int entity)
{
	//Mannpower allows for quick building deployment
	GameRules_SetProp("m_bPowerupMode", true);
}

public MRESReturn DHook_StartBuildingPost(int entity)
{
	GameRules_SetProp("m_bPowerupMode", false);
}

public MRESReturn DHook_GetBaseHealthPost(int entity, DHookReturn ret)
{
	ret.Value = fr_obj_health[TF2_GetObjectType(entity)].IntValue;
	return MRES_Supercede;
}

public MRESReturn DHook_SetPassenger(Address vehicle, DHookParam params)
{
	if (!params.IsNull(2))
	{
		SetEntProp(params.Get(2), Prop_Data, "m_bDrawViewmodel", false);
	}
	else
	{
		int client = SDKCall_GetDriver(vehicle);
		if (client != -1)
			SetEntProp(client, Prop_Data, "m_bDrawViewmodel", true);
	}
}
