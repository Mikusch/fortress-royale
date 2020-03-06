static Handle g_DHookForceRespawn;
static Handle g_DHookSetWinningTeam;
static Handle g_DHookPrimaryAttack;
static Handle g_DHookDeflectPlayer;
static Handle g_DHookDeflectEntity;
static Handle g_DHookExplode;
static Handle g_DHookShouldCollide;

static Handle g_SDKCallCreateDroppedWeapon;
static Handle g_SDKCallInitDroppedWeapon;

static int g_PrimaryAttackClient;
static TFTeam g_PrimaryAttackTeam;

static int g_CreateRuneOffset;

void SDK_Init()
{
	GameData gamedata = new GameData("royale");
	if (gamedata == null)
		SetFailState("Could not find royale gamedata");
	
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeam, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetPlayer", DHook_ValidTargetPlayer, _);
	DHook_CreateDetour(gamedata, "CObjectDispenser::CouldHealTarget", DHook_CouldHealTarget, _);
	
	g_DHookSetWinningTeam = DHook_CreateVirtual(gamedata, "CTFGameRules::SetWinningTeam");
	g_DHookForceRespawn = DHook_CreateVirtual(gamedata, "CTFPlayer::ForceRespawn");
	g_DHookPrimaryAttack = DHook_CreateVirtual(gamedata, "CBaseCombatWeapon::PrimaryAttack");
	g_DHookDeflectPlayer = DHook_CreateVirtual(gamedata, "CTFWeaponBase::DeflectPlayer");
	g_DHookDeflectEntity = DHook_CreateVirtual(gamedata, "CTFWeaponBase::DeflectEntity");
	g_DHookExplode = DHook_CreateVirtual(gamedata, "CBaseGrenade::Explode");
	g_DHookShouldCollide = DHook_CreateVirtual(gamedata, "CTFPointManager::ShouldCollide");
	
	g_SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	g_SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	
	g_CreateRuneOffset = gamedata.GetOffset("TF2_CreateRune");
	
	delete gamedata;
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

static Handle PrepSDKCall_CreateDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFDroppedWeapon::Create");
	
	return call;
}

static Handle PrepSDKCall_InitDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFDroppedWeapon::InitDroppedWeapon");
	
	return call;
}

void SDK_HookGamerules()
{
	DHookGamerules(g_DHookSetWinningTeam, false, _, DHook_SetWinningTeam);
}

void SDK_HookClient(int client)
{
	DHookEntity(g_DHookForceRespawn, false, client, _, DHook_ForceRespawnPre);
}

void SDK_HookPrimaryAttack(int weapon)
{
	DHookEntity(g_DHookPrimaryAttack, false, weapon, _, DHook_PrimaryAttackPre);
	DHookEntity(g_DHookPrimaryAttack, true, weapon, _, DHook_PrimaryAttackPost);
}

void SDK_HookFlamethrower(int weapon)
{
	DHookEntity(g_DHookDeflectPlayer, false, weapon, _, DHook_DeflectPre);
	DHookEntity(g_DHookDeflectPlayer, true, weapon, _, DHook_DeflectPost);
	DHookEntity(g_DHookDeflectEntity, false, weapon, _, DHook_DeflectPre);
	DHookEntity(g_DHookDeflectEntity, true, weapon, _, DHook_DeflectPost);
}

void SDK_HookProjectile(int projectile)
{
	DHookEntity(g_DHookExplode, false, projectile, _, DHook_ExplodePre);
	DHookEntity(g_DHookExplode, true, projectile, _, DHook_ExplodePost);
}

void SDK_HookGasManager(int gasManager)
{
	DHookEntity(g_DHookShouldCollide, false, gasManager, _, DHook_ShouldCollidePre);
}

public MRESReturn DHook_InSameTeam(int entity, Handle returnVal, Handle params)
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

public MRESReturn DHook_ValidTargetPlayer(int sentry, Handle hReturn, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (0 < target <= MaxClients && TF2_IsObjectFriendly(sentry, target))
	{
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CouldHealTarget(int dispenser, Handle hReturn, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (0 < target <= MaxClients)
	{
		DHookSetReturn(hReturn, TF2_IsObjectFriendly(dispenser, target));
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SetWinningTeam(Handle params)
{
	//Prevent round win if atleast 2 players alive
	if (GetAlivePlayersCount() >= 2)
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_ForceRespawnPre(int client)
{
	if (FRPlayer(client).PlayerState == PlayerState_Alive)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

public MRESReturn DHook_PrimaryAttackPre(int weapon)
{
	//This weapon may not work for teammate, set team to spectator so he can deal damage to both red and blue
	
	g_PrimaryAttackClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	g_PrimaryAttackTeam = TF2_GetClientTeam(g_PrimaryAttackClient);
	TF2_ChangeTeam(g_PrimaryAttackClient, TFTeam_Spectator);
}

public MRESReturn DHook_PrimaryAttackPost(int weapon)
{
	//DHook bug with Pre and Post giving incorrect 'weapon' entity for post,
	//Set team back to what it was
	
	TF2_ChangeTeam(g_PrimaryAttackClient, g_PrimaryAttackTeam);
}

public MRESReturn DHook_DeflectPre(int weapon, Handle params)
{
	//Allow airblast teamates, change attacker team to victim/entity's enemy team
	TF2_ChangeTeam(DHookGetParam(params, 2), TF2_GetEnemyTeam(DHookGetParam(params, 1)));
}

public MRESReturn DHook_DeflectPost(int weapon, Handle params)
{
	//Change attacker team back to what it was, using flamethrower weapon team
	TF2_ChangeTeam(DHookGetParam(params, 2), TF2_GetTeam(weapon));
}

public MRESReturn DHook_ExplodePre(int entity, Handle params)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner <= 0 || owner > MaxClients || !IsClientInGame(owner))
		return;
	
	//Change both projectile and owner to spectator, so effect applies to both red and blu, but not owner itself
	TF2_ChangeTeam(entity, TFTeam_Spectator);
	TF2_ChangeTeam(owner, TFTeam_Spectator);
}

public MRESReturn DHook_ExplodePost(int entity, Handle params)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner <= 0 || owner > MaxClients || !IsClientInGame(owner))
		return;
	
	//Get original team by using it's weapon
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	if (weapon <= MaxClients)
		return;
	
	TF2_ChangeTeam(owner, TF2_GetTeam(weapon));
}

public MRESReturn DHook_ShouldCollidePre(int gasManager, Handle returnVal, Handle params)
{
	int toucher = DHookGetParam(params, 1);
	
	gasManager = GetOwnerLoop(gasManager);
	toucher = GetOwnerLoop(toucher);
	
	DHookSetReturn(returnVal, gasManager != toucher);
	return MRES_Supercede;
}

public Address GameData_GetCreateRuneOffset()
{
	return view_as<Address>(g_CreateRuneOffset);
}

stock int SDK_CreateDroppedWeapon(int fromWeapon, int client, const float origin[3], const float angles[3])
{
	char classname[32];
	if (GetEntityNetClass(fromWeapon, classname, sizeof(classname)))
	{
		int itemOffset = FindSendPropInfo(classname, "m_Item");
		if (itemOffset <= -1)
			ThrowError("Failed to find m_Item on: %s", classname);
		
		char model[PLATFORM_MAX_PATH];
		int worldModelIndex = GetEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex");
		ModelIndexToString(worldModelIndex, model, sizeof(model));
		
		int droppedWeapon = SDKCall(g_SDKCallCreateDroppedWeapon, client, origin, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
		if (droppedWeapon != INVALID_ENT_REFERENCE)
			SDKCall(g_SDKCallInitDroppedWeapon, droppedWeapon, client, fromWeapon, false, false);
		return droppedWeapon;
	}
	
	return -1;
}
