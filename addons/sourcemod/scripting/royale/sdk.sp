static Handle g_DHookForceRespawn;
static Handle g_DHookGiveNamedItem;
static Handle g_DHookSetWinningTeam;
static Handle g_DHookPrimaryAttack;
static Handle g_DHookDeflectPlayer;
static Handle g_DHookDeflectEntity;
static Handle g_DHookExplode;
static Handle g_DHookShouldCollide;

static Handle g_SDKGetMaxAmmo;
static Handle g_SDKCallCreateDroppedWeapon;
static Handle g_SDKCallInitDroppedWeapon;
static Handle g_SDKCallInitPickedUpWeapon;
static Handle g_SDKCallGetEquippedWearableForLoadoutSlot;
static Handle g_SDKCallEquipWearable;

static int g_PrimaryAttackClient;
static TFTeam g_PrimaryAttackTeam;

static int g_HookIdGiveNamedItem[TF_MAXPLAYERS+1];

static int g_OffsetItemDefinitionIndex;
static int g_OffsetCreateRune;

void SDK_Init()
{
	GameData gamedata = new GameData("royale");
	if (gamedata == null)
		SetFailState("Could not find royale gamedata");
	
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeam, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::FindTarget", DHook_FindTargetPre, DHook_FindTargetPost);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetPlayer", DHook_ValidTarget, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetObject", DHook_ValidTarget, _);
	DHook_CreateDetour(gamedata, "CObjectDispenser::CouldHealTarget", DHook_CouldHealTarget, _);
	DHook_CreateDetour(gamedata, "CTFPlayer::CanPickupDroppedWeapon", DHook_CanPickupDroppedWeapon, _);
	
	g_DHookSetWinningTeam = DHook_CreateVirtual(gamedata, "CTFGameRules::SetWinningTeam");
	g_DHookForceRespawn = DHook_CreateVirtual(gamedata, "CTFPlayer::ForceRespawn");
	g_DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	g_DHookPrimaryAttack = DHook_CreateVirtual(gamedata, "CBaseCombatWeapon::PrimaryAttack");
	g_DHookDeflectPlayer = DHook_CreateVirtual(gamedata, "CTFWeaponBase::DeflectPlayer");
	g_DHookDeflectEntity = DHook_CreateVirtual(gamedata, "CTFWeaponBase::DeflectEntity");
	g_DHookExplode = DHook_CreateVirtual(gamedata, "CBaseGrenade::Explode");
	g_DHookShouldCollide = DHook_CreateVirtual(gamedata, "CTFPointManager::ShouldCollide");
	
	g_SDKGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
	g_SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	g_SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	g_SDKCallInitPickedUpWeapon = PrepSDKCall_InitPickedUpWeapon(gamedata);
	g_SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	g_SDKCallEquipWearable = PrepSDKCall_EquipWearable(gamedata);
	
	g_OffsetItemDefinitionIndex = gamedata.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	g_OffsetCreateRune = gamedata.GetOffset("TF2_CreateRune");
	
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

static Handle PrepSDKCall_GetMaxAmmo(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GetMaxAmmo");
	
	return call;
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

static Handle PrepSDKCall_InitPickedUpWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::InitPickedUpWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFDroppedWeapon::InitPickedUpWeapon");
	
	return call;
}

static Handle PrepSDKCall_GetEquippedWearableForLoadoutSlot(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GetEquippedWearableForLoadoutSlot");
	
	return call;
}

static Handle PrepSDKCall_EquipWearable(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBasePlayer::EquipWearable");
	
	return call;
}

void SDK_HookGiveNamedItem(int client)
{
	if (g_DHookGiveNamedItem && !g_TF2Items)
		g_HookIdGiveNamedItem[client] = DHookEntity(g_DHookGiveNamedItem, false, client, DHook_GiveNamedItemRemoved, DHook_GiveNamedItemPre);
}

void SDK_UnhookGiveNamedItem(int client)
{
	if (g_HookIdGiveNamedItem[client])
	{
		DHookRemoveHookID(g_HookIdGiveNamedItem[client]);
		g_HookIdGiveNamedItem[client] = 0;	
	}
}

bool SDK_IsGiveNamedItemActive()
{
	for (int client = 1; client <= MaxClients; client++)
		if (g_HookIdGiveNamedItem[client])
			return true;
	
	return false;
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

public MRESReturn DHook_FindTargetPre(int sentry, Handle returnVal)
{
	//Sentry can only target one team, target enemy team
	int client = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
	if (client <= 0)
		return;
	
	TF2_ChangeTeam(sentry, TF2_GetEnemyTeam(client));
}

public MRESReturn DHook_FindTargetPost(int sentry, Handle returnVal)
{
	int client = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
	if (client <= 0)
		return;
	
	TF2_ChangeTeam(sentry, TF2_GetTeam(client));
}

public MRESReturn DHook_ValidTarget(int sentry, Handle returnVal, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (TF2_IsObjectFriendly(sentry, target))
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CouldHealTarget(int dispenser, Handle returnVal, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (0 < target <= MaxClients)
	{
		DHookSetReturn(returnVal, TF2_IsObjectFriendly(dispenser, target));
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CanPickupDroppedWeapon(int client, Handle returnVal, Handle params)
{
	if (TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	int droppedWeapon = DHookGetParam(params, 1);
	int defindex = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType class = TF2_GetPlayerClass(client);
	int slot = TF2_GetItemSlot(defindex, class);
	
	if (slot < 0)
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	//Check if client already has weapon in given slot, remove and create dropped weapon if so
	int weapon = TF2_GetItemInSlot(client, slot);
	if (weapon > MaxClients)
	{
		if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != INDEX_FISTS)
		{
			float origin[3], angles[3];
			GetClientEyePosition(client, origin);
			GetClientEyeAngles(client, angles);
			
			int newDroppedWeapon = SDK_CreateDroppedWeapon(client, weapon, origin, angles);
			if (newDroppedWeapon != INVALID_ENT_REFERENCE)
				SDK_InitDroppedWeapon(newDroppedWeapon, client, weapon, true);
		}
		
		TF2_RemoveItemInSlot(client, slot);
	}
	
	//Create new weapon
	weapon = TF2_CreateWeapon(defindex, class);
	if (weapon > MaxClients)
		TF2_EquipWeapon(client, weapon);
	
	//Remove dropped weapon
	RemoveEntity(droppedWeapon);
	
	//Prevent TF2 doing any extra work, we done that
	DHookSetReturn(returnVal, false);
	return MRES_Supercede;
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

public MRESReturn DHook_GiveNamedItemPre(int client, Handle returnVal, Handle params)
{
	if (DHookIsNullParam(params, 1) || DHookIsNullParam(params, 3))
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Override;
	}
	
	char classname[256];
	DHookGetParamString(params, 1, classname, sizeof(classname));
	int index = DHookGetParamObjectPtrVar(params, 3, g_OffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	if (CanKeepWeapon(classname, index))
		return MRES_Ignored;
	
	DHookSetReturn(returnVal, 0);
	return MRES_Override;
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
	return view_as<Address>(g_OffsetCreateRune);
}

int SDK_GetMaxAmmo(int client, int ammotype, TFClassType class = view_as<TFClassType>(-1))
{
	return SDKCall(g_SDKGetMaxAmmo, client, ammotype, class);
}

void SDK_InitDroppedWeapon(int droppedWeapon, int client, int fromWeapon, bool swap, bool isSuicide = false)
{
	SDKCall(g_SDKCallInitDroppedWeapon, droppedWeapon, client, fromWeapon, swap, isSuicide);
}

int SDK_CreateDroppedWeapon(client, int fromWeapon, const float origin[3] = { 0.0, 0.0, 0.0 }, const float angles[3] = { 0.0, 0.0, 0.0 })
{
	char classname[32];
	if (GetEntityNetClass(fromWeapon, classname, sizeof(classname)))
	{
		int itemOffset = FindSendPropInfo(classname, "m_Item");
		if (itemOffset <= -1)
			ThrowError("Failed to find m_Item on: %s", classname);
		
		char defindex[12];
		IntToString(GetEntProp(fromWeapon, Prop_Send, "m_iItemDefinitionIndex"), defindex, sizeof(defindex));
		
		//Attempt get custom model, otherwise use default model
		char model[PLATFORM_MAX_PATH];
		if (!g_PrecacheWeapon.GetString(defindex, model, sizeof(model)))
		{
			int modelIndex = GetEntProp(fromWeapon, Prop_Send, "m_nModelIndex");
			ModelIndexToString(modelIndex, model, sizeof(model));
		}
		
		return SDKCall(g_SDKCallCreateDroppedWeapon, client, origin, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
	}
	
	return INVALID_ENT_REFERENCE;
}

void SDK_EquipWearable(int client, int wearable)
{
	SDKCall(g_SDKCallEquipWearable, client, wearable);
}

int SDK_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(g_SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}
