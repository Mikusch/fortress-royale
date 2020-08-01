enum ThinkFunction
{
	ThinkFunction_None,
	ThinkFunction_SapperThink,
	ThinkFunction_DispenseThink,
	ThinkFunction_SentryThink,
	ThinkFunction_RegenThink,
	ThinkFunction_TossJarThink,
}

static Handle g_DHookGetMaxHealth;
static Handle g_DHookForceRespawn;
static Handle g_DHookGiveNamedItem;
static Handle g_DHookGrenadeExplode;
static Handle g_DHookFireballExplode;
static Handle g_DHookGetLiveTime;
static Handle g_DHookIsEnemy;
static Handle g_DHookIsFriend;

static ThinkFunction g_ThinkFunction;
static int g_HookIdGiveNamedItem[TF_MAXPLAYERS + 1];
static int g_StartLagCompensationClient;

void DHook_Init(GameData gamedata)
{
	DHook_CreateDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHook_PhysicsDispatchThinkPre, DHook_PhysicsDispatchThinkPost);
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeamPre, _);
	DHook_CreateDetour(gamedata, "CTFDroppedWeapon::Create", DHook_CreatePre, _);
	DHook_CreateDetour(gamedata, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, DHook_GetChargeEffectBeingProvidedPost);
	DHook_CreateDetour(gamedata, "CTFPlayerShared::PulseRageBuff", DHook_PulseRageBuffPre, DHook_PulseRageBuffPost);
	DHook_CreateDetour(gamedata, "CEyeballBoss::FindClosestVisibleVictim", DHook_FindClosestVisibleVictimPre, DHook_FindClosestVisibleVictimPost);
	DHook_CreateDetour(gamedata, "CLagCompensationManager::StartLagCompensation", DHook_StartLagCompensationPre, DHook_StartLagCompensationPost);
	
	g_DHookGetMaxHealth = DHook_CreateVirtual(gamedata, "CBaseEntity::GetMaxHealth");
	g_DHookForceRespawn = DHook_CreateVirtual(gamedata, "CTFPlayer::ForceRespawn");
	g_DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	g_DHookGrenadeExplode = DHook_CreateVirtual(gamedata, "CBaseGrenade::Explode");
	g_DHookFireballExplode = DHook_CreateVirtual(gamedata, "CTFProjectile_SpellFireball::Explode");
	g_DHookGetLiveTime = DHook_CreateVirtual(gamedata, "CTFGrenadePipebombProjectile::GetLiveTime");
	g_DHookIsEnemy = DHook_CreateVirtual(gamedata, "INextBot::IsEnemy");
	g_DHookIsFriend = DHook_CreateVirtual(gamedata, "INextBot::IsFriend");
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
	Handle detour = DHookCreateFromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (preCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, false, preCallback))
				LogError("Failed to enable pre detour: %s", name);
		
		if (postCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, true, postCallback))
				LogError("Failed to enable post detour: %s", name);
		
		delete detour;
	}
}

static Handle DHook_CreateVirtual(GameData gamedata, const char[] name)
{
	Handle hook = DHookCreateFromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create virtual: %s", name);
	
	return hook;
}

void DHook_HookGiveNamedItem(int client)
{
	if (g_DHookGiveNamedItem && !g_TF2Items)
		g_HookIdGiveNamedItem[client] = DHookEntity(g_DHookGiveNamedItem, false, client, DHook_GiveNamedItemRemoved, DHook_GiveNamedItemPre);
}

void DHook_UnhookGiveNamedItem(int client)
{
	if (g_HookIdGiveNamedItem[client])
	{
		DHookRemoveHookID(g_HookIdGiveNamedItem[client]);
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
	DHookEntity(g_DHookGetMaxHealth, false, client, _, DHook_GetMaxHealthPre);
	DHookEntity(g_DHookGetMaxHealth, true, client, _, DHook_GetMaxHealthPost);
	DHookEntity(g_DHookForceRespawn, false, client, _, DHook_ForceRespawnPre);
	DHookEntity(g_DHookForceRespawn, true, client, _, DHook_ForceRespawnPost);
}

void DHook_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "tf_projectile_jar") == 0 || StrEqual(classname, "tf_projectile_spellbats"))
	{
		DHookEntity(g_DHookGrenadeExplode, false, entity, _, DHook_GrenadeExplodePre);
		DHookEntity(g_DHookGrenadeExplode, true, entity, _, DHook_GrenadeExplodePost);
	}
	else if (StrEqual(classname, "tf_projectile_spellfireball"))
	{
		DHookEntity(g_DHookFireballExplode, false, entity, _, DHook_FireballExplodePre);
		DHookEntity(g_DHookFireballExplode, true, entity, _, DHook_FireballExplodePost);
	}
	else if (StrContains(classname, "tf_projectile_pipe") == 0)
	{
		DHookEntity(g_DHookGetLiveTime, false, entity, _, DHook_GetLiveTimePre);
		DHookEntity(g_DHookGetLiveTime, true, entity, _, DHook_GetLiveTimePost);
	}
	else if (StrEqual(classname, "tf_zombie"))
	{
		DHookEntity(g_DHookIsEnemy, true, entity, _, DHook_IsEnemyPost);
		DHookEntity(g_DHookIsFriend, true, entity, _, DHook_IsFriendPost);
	}
}

public MRESReturn DHook_PhysicsDispatchThinkPre(int entity, Handle params)
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
	else if (StrEqual(classname, "obj_dispenser"))
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

public MRESReturn DHook_PhysicsDispatchThinkPost(int entity, Handle params)
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

public MRESReturn DHook_InSameTeamPre(int entity, Handle returnVal, Handle params)
{
	//In friendly fire we only want to return true if both entity owner is the same
	
	if (DHookIsNullParam(params, 1))
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	int other = DHookGetParam(params, 1);
	
	entity = GetOwnerLoop(entity);
	other = GetOwnerLoop(other);
	
	DHookSetReturn(returnVal, entity == other);
	return MRES_Supercede;
}

public MRESReturn DHook_CreatePre(Handle returnVal, Handle params)
{
	//Dont create any dropped weapon created by tf2 (TF2_CreateDroppedWeapon pass client param as NULL)
	if (!DHookIsNullParam(params, 1))
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPre(int client, Handle returnVal)
{
	if (!IsClientInGame(client))
		return;
	
	//Allow return medigun effects while client switched away from active weapon
	int medigun = TF2_GetItemByClassname(client, "tf_weapon_medigun");
	if (medigun != -1)
	{
		FRPlayer(client).ActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		SetEntProp(medigun, Prop_Send, "m_bHolstered", false);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", medigun);
	}
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPost(int client, Handle returnVal)
{
	if (!IsClientInGame(client))
		return;
	
	int medigun = TF2_GetItemByClassname(client, "tf_weapon_medigun");
	if (medigun != -1)
	{
		SetEntProp(medigun, Prop_Send, "m_bHolstered", GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != FRPlayer(client).ActiveWeapon);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", FRPlayer(client).ActiveWeapon);
	}
}

public MRESReturn DHook_PulseRageBuffPre(Address playershared, Handle params)
{
	int client = GetClientFromPlayerShared(playershared);
	if (!client)
		return;
	
	//Change team so client can't give boosts to teammate
	FRPlayer(client).ChangeToSpectator();
}

public MRESReturn DHook_PulseRageBuffPost(Address playershared, Handle params)
{
	int client = GetClientFromPlayerShared(playershared);
	if (!client)
		return;
	
	FRPlayer(client).ChangeToTeam();
}

public MRESReturn DHook_FindClosestVisibleVictimPre(int eyeball, Handle params)
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

public MRESReturn DHook_FindClosestVisibleVictimPost(int eyeball, Handle params)
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

public MRESReturn DHook_StartLagCompensationPre(Address manager, Handle params)
{
	g_StartLagCompensationClient = DHookGetParam(params, 1);
	
	//Lag compensate teammates
	// CTFPlayer::WantsLagCompensationOnEntity virtual hook could've been done instead,
	// but expensive as it called to each clients while this detour only calls once
	FRPlayer(g_StartLagCompensationClient).ChangeToSpectator();
}

public MRESReturn DHook_StartLagCompensationPost(Address manager, Handle params)
{
	//DHook bug with post hook returning incorrect client address
	FRPlayer(g_StartLagCompensationClient).ChangeToTeam();
}

public MRESReturn DHook_GetMaxHealthPre(int client, Handle returnVal)
{
	//Hooks may be changing client class, change class back to what it was
	FRPlayer(client).ChangeToClass();
}

public MRESReturn DHook_GetMaxHealthPost(int client, Handle returnVal)
{
	TFClassType class = TF2_GetPlayerClass(client);
	FRPlayer(client).ChangeToUnknown();
	
	if (class == TFClass_Unknown)
		return MRES_Ignored;
	
	float multiplier = fr_healthmultiplier[class].FloatValue;
	if (multiplier == 1.0)
		return MRES_Ignored;
	
	//Multiply health by convar value
	DHookSetReturn(returnVal, RoundToNearest(float(DHookGetReturn(returnVal)) * multiplier));
	return MRES_Supercede;
}

public MRESReturn DHook_ForceRespawnPre(int client)
{
	//Only allow respawn if player is in parachute mode
	if (FRPlayer(client).PlayerState != PlayerState_Parachute)
		return MRES_Supercede;
	
	//Allow RuneRegenThink to start
	GameRules_SetProp("m_bPowerupMode", true);
	
	//If player havent selected a class, pick random class for em
	//this is so that player can actually spawn into map, otherwise nothing happens
	if (view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass")) == TFClass_Unknown)
		SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
	
	return MRES_Ignored;
}

public MRESReturn DHook_ForceRespawnPost(int client)
{
	GameRules_SetProp("m_bPowerupMode", false);
}

public MRESReturn DHook_GiveNamedItemPre(int client, Handle returnVal, Handle params)
{
	if (DHookIsNullParam(params, 1) || DHookIsNullParam(params, 3))
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	char classname[256];
	DHookGetParamString(params, 1, classname, sizeof(classname));
	int index = DHookGetParamObjectPtrVar(params, 3, g_OffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	if (TF2_OnGiveNamedItem(client, classname, index) >= Plugin_Handled)
	{
		DHookSetReturn(returnVal, 0);
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

public MRESReturn DHook_GrenadeExplodePre(int entity, Handle params)
{
	//Change both projectile and owner to spectator, so effect applies to both red and blu, but not owner itself
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(entity, TFTeam_Spectator);
	}
}

public MRESReturn DHook_GrenadeExplodePost(int entity, Handle params)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(entity, FRPlayer(owner).Team);
	}
}

public MRESReturn DHook_FireballExplodePre(int entity, Handle params)
{
	//Change both projectile and owner to spectator, so effect applies to both red and blu, but not owner itself
	int owner = GetOwnerLoop(entity);
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(entity, TFTeam_Spectator);
	}
}

public MRESReturn DHook_FireballExplodePost(int entity, Handle params)
{
	int owner = GetOwnerLoop(entity);
	if (0 < owner <= MaxClients)
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(entity, FRPlayer(owner).Team);
	}
}

public MRESReturn DHook_GetLiveTimePre(int entity, Handle returnVal)
{
	//Haste and King powerup allows sticky to detonate sooner
	GameRules_SetProp("m_bPowerupMode", true);
}

public MRESReturn DHook_GetLiveTimePost(int entity, Handle returnVal)
{
	GameRules_SetProp("m_bPowerupMode", false);
}

public MRESReturn DHook_IsEnemyPost(int nextbot, Handle returnVal, Handle params)
{
	int them = DHookGetParam(params, 1);
	int owner = GetEntProp(nextbot, Prop_Send, "m_hOwnerEntity");
	
	if (owner == them)
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	DHookSetReturn(returnVal, true);
	return MRES_Ignored;
}

public MRESReturn DHook_IsFriendPost(int nextbot, Handle returnVal, Handle params)
{
	int them = DHookGetParam(params, 1);
	int owner = GetEntProp(nextbot, Prop_Send, "m_hOwnerEntity");
	
	if (owner == them)
	{
		DHookSetReturn(returnVal, true);
		return MRES_Supercede;
	}
	
	DHookSetReturn(returnVal, false);
	return MRES_Ignored;
}
