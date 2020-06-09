static Handle g_SDKCallCreateDroppedWeapon;
static Handle g_SDKCallInitDroppedWeapon;
static Handle g_SDKCallInitPickedUpWeapon;
static Handle g_SDKCallTryToPickupDroppedWeapon;
static Handle g_SDKCallGetLoadoutItem;
static Handle g_SDKCallGetEquippedWearableForLoadoutSlot;
static Handle g_SDKCallFindAndHealTargets;
static Handle g_SDKCallGetDefaultItemChargeMeterValue;
static Handle g_SDKCallGiveNamedItem;
static Handle g_SDKCallEquipWearable;
static Handle g_SDKCallSetVelocity;
static Handle g_SDKCallGetVelocity;

void SDKCall_Init(GameData gamedata)
{
	g_SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	g_SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	g_SDKCallInitPickedUpWeapon = PrepSDKCall_InitPickedUpWeapon(gamedata);
	g_SDKCallTryToPickupDroppedWeapon = PrepSDKCall_TryToPickupDroppedWeapon(gamedata);
	g_SDKCallGetLoadoutItem = PrepSDKCall_GetLoadoutItem(gamedata);
	g_SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	g_SDKCallFindAndHealTargets = PrepSDKCall_FindAndHealTargets(gamedata);
	g_SDKCallGetDefaultItemChargeMeterValue = PrepSDKCall_GetDefaultItemChargeMeterValue(gamedata);
	g_SDKCallGiveNamedItem = PrepSDKCall_GiveNamedItem(gamedata);
	g_SDKCallEquipWearable = PrepSDKCall_EquipWearable(gamedata);
	g_SDKCallSetVelocity = PrepSDKCall_SetVelocity(gamedata);
	g_SDKCallGetVelocity = PrepSDKCall_GetVelocity(gamedata);
}

static Handle PrepSDKCall_CreateDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
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

static Handle PrepSDKCall_TryToPickupDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::TryToPickupDroppedWeapon");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::TryToPickupDroppedWeapon");
	
	return call;
}

static Handle PrepSDKCall_GetLoadoutItem(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetLoadoutItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GetLoadoutItem");
	
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

static Handle PrepSDKCall_FindAndHealTargets(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CWeaponMedigun::FindAndHealTargets");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CWeaponMedigun::FindAndHealTargets");
	
	return call;
}

static Handle PrepSDKCall_GetDefaultItemChargeMeterValue(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetDefaultItemChargeMeterValue");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::GetDefaultItemChargeMeterValue");
	
	return call;
}

static Handle PrepSDKCall_GiveNamedItem(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GiveNamedItem");
	
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

static Handle PrepSDKCall_SetVelocity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "IPhysicsObject::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: IPhysicsObject::SetVelocity");
	
	return call;
}

static Handle PrepSDKCall_GetVelocity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "IPhysicsObject::GetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL, VENCODE_FLAG_COPYBACK);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: IPhysicsObject::GetVelocity");
	
	return call;
}

int SDKCall_CreateDroppedWeapon(int client, const float origin[3] = { 0.0, 0.0, 0.0 }, const float angles[3] = { 0.0, 0.0, 0.0 }, const char[] model, Address item)
{
	return SDKCall(g_SDKCallCreateDroppedWeapon, client, origin, angles, model, item);
}

void SDKCall_InitDroppedWeapon(int droppedWeapon, int client, int fromWeapon, bool swap, bool isSuicide = false)
{
	SDKCall(g_SDKCallInitDroppedWeapon, droppedWeapon, client, fromWeapon, swap, isSuicide);
}

void SDKCall_InitPickedUpWeapon(int droppedWeapon, int client, int fromWeapon)
{
	SDKCall(g_SDKCallInitPickedUpWeapon, droppedWeapon, client, fromWeapon);
}

bool SDKCall_TryToPickupDroppedWeapon(int client)
{
	return SDKCall(g_SDKCallTryToPickupDroppedWeapon, client);
}

Address SDKCall_GetLoadoutItem(int client, TFClassType class, int slot)
{
	return SDKCall(g_SDKCallGetLoadoutItem, client, class, slot, false);
}

int SDKCall_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(g_SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}

bool SDKCall_FindAndHealTargets(int medigun)
{
	return SDKCall(g_SDKCallFindAndHealTargets, medigun);
}

float SDKCall_GetDefaultItemChargeMeterValue(int weapon)
{
	return SDKCall(g_SDKCallGetDefaultItemChargeMeterValue, weapon);
}

int SDKCall_GiveNamedItem(int client, const char[] classname, int subtype, Address item, bool force)
{
	return SDKCall(g_SDKCallGiveNamedItem, client, classname, subtype, item, force);
}

void SDKCall_EquipWearable(int client, int wearable)
{
	SDKCall(g_SDKCallEquipWearable, client, wearable);
}

void SDKCall_SetVelocity(int entity, const float velocity[3], const float angVelocity[3])
{
	static int offset = -1;
	if (offset == -1)
		FindDataMapInfo(entity, "m_pPhysicsObject", _, _, offset);
	
	if (offset == -1)
	{
		LogError("Unable to find offset 'm_pPhysicsObject'");
		return;
	}
	
	Address phyObj = view_as<Address>(LoadFromAddress(GetEntityAddress(entity) + view_as<Address>(offset), NumberType_Int32));
	if (!phyObj)
	{
		LogError("Unable to find offset 'm_pPhysicsObject'");
		return;
	}
	
	SDKCall(g_SDKCallSetVelocity, phyObj, velocity, angVelocity);
}

void SDKCall_GetVelocity(int entity, float velocity[3], float angVelocity[3])
{
	static int offset = -1;
	if (offset == -1)
		FindDataMapInfo(entity, "m_pPhysicsObject", _, _, offset);
	
	if (offset == -1)
	{
		LogError("Unable to find offset 'm_pPhysicsObject'");
		return;
	}
	
	Address phyObj = view_as<Address>(LoadFromAddress(GetEntityAddress(entity) + view_as<Address>(offset), NumberType_Int32));
	if (!phyObj)
	{
		LogError("Unable to find offset 'm_pPhysicsObject'");
		return;
	}
	
	SDKCall(g_SDKCallGetVelocity, phyObj, velocity, angVelocity);
}