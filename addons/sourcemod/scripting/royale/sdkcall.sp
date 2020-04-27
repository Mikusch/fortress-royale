static Handle g_SDKGetMaxAmmo;
static Handle g_SDKCallInitDroppedWeapon;
static Handle g_SDKCallInitPickedUpWeapon;
static Handle g_SDKCallTryToPickupDroppedWeapon;
static Handle g_SDKCallGetEquippedWearableForLoadoutSlot;
static Handle g_SDKCallEquipWearable;

void SDKCall_Init(GameData gamedata)
{
	g_SDKGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
	g_SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	g_SDKCallInitPickedUpWeapon = PrepSDKCall_InitPickedUpWeapon(gamedata);
	g_SDKCallTryToPickupDroppedWeapon = PrepSDKCall_TryToPickupDroppedWeapon(gamedata);
	g_SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	g_SDKCallEquipWearable = PrepSDKCall_EquipWearable(gamedata);
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

int SDKCall_GetMaxAmmo(int client, int ammotype, TFClassType class = view_as<TFClassType>(-1))
{
	return SDKCall(g_SDKGetMaxAmmo, client, ammotype, class);
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

void SDKCall_EquipWearable(int client, int wearable)
{
	SDKCall(g_SDKCallEquipWearable, client, wearable);
}

int SDKCall_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(g_SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}
