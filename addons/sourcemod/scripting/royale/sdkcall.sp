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

static Handle g_SDKCallGetNextThink;
static Handle g_SDKCallCreateDroppedWeapon;
static Handle g_SDKCallInitDroppedWeapon;
static Handle g_SDKCallInitPickedUpWeapon;
static Handle g_SDKCallGetLoadoutItem;
static Handle g_SDKCallGetEquippedWearableForLoadoutSlot;
static Handle g_SDKCallGetMaxAmmo;
static Handle g_SDKCallCalculateAmmoPackPositionAndAngles;
static Handle g_SDKCallFindAndHealTargets;
static Handle g_SDKCallGetGlobalTeam;
static Handle g_SDKCallGetPlayerClassData;
static Handle g_SDKCallChangeTeam;
static Handle g_SDKCallGetDefaultItemChargeMeterValue;
static Handle g_SDKCallWeaponCanSwitchTo;
static Handle g_SDKCallGiveNamedItem;
static Handle g_SDKCallGetSlot;
static Handle g_SDKCallEquipWearable;
static Handle g_SDKCallStudioFrameAdvance;
static Handle g_SDKCallAddPlayer;
static Handle g_SDKCallRemovePlayer;
static Handle g_SDKCallVehicleSetupMove;
static Handle g_SDKCallHandleEntryExitFinish;
static Handle g_SDKCallGetDriver;
static Handle g_SDKCallGetHealRate;

void SDKCall_Init(GameData gamedata)
{
	g_SDKCallGetNextThink = PrepSDKCall_GetNextThink(gamedata);
	g_SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	g_SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	g_SDKCallInitPickedUpWeapon = PrepSDKCall_InitPickedUpWeapon(gamedata);
	g_SDKCallGetLoadoutItem = PrepSDKCall_GetLoadoutItem(gamedata);
	g_SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	g_SDKCallGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
	g_SDKCallCalculateAmmoPackPositionAndAngles = PrepSDKCall_CalculateAmmoPackPositionAndAngles(gamedata);
	g_SDKCallFindAndHealTargets = PrepSDKCall_FindAndHealTargets(gamedata);
	g_SDKCallGetGlobalTeam = PrepSDKCall_GetGlobalTeam(gamedata);
	g_SDKCallGetPlayerClassData = PrepSDKCall_GetPlayerClassData(gamedata);
	g_SDKCallChangeTeam = PrepSDKCall_ChangeTeam(gamedata);
	g_SDKCallGetDefaultItemChargeMeterValue = PrepSDKCall_GetDefaultItemChargeMeterValue(gamedata);
	g_SDKCallWeaponCanSwitchTo = PrepSDKCall_WeaponCanSwitchTo(gamedata);
	g_SDKCallGiveNamedItem = PrepSDKCall_GiveNamedItem(gamedata);
	g_SDKCallGetSlot = PrepSDKCall_GetSlot(gamedata);
	g_SDKCallEquipWearable = PrepSDKCall_EquipWearable(gamedata);
	g_SDKCallStudioFrameAdvance = PrepSDKCall_StudioFrameAdvance(gamedata);
	g_SDKCallAddPlayer = PrepSDKCall_AddPlayer(gamedata);
	g_SDKCallRemovePlayer = PrepSDKCall_RemovePlayer(gamedata);
	g_SDKCallVehicleSetupMove = PrepSDKCall_VehicleSetupMove(gamedata);
	g_SDKCallHandleEntryExitFinish = PrepSDKCall_HandleEntryExitFinish(gamedata);
	g_SDKCallGetDriver = PrepSDKCall_GetDriver(gamedata);
	g_SDKCallGetHealRate = PrepSDKCall_GetHealRate(gamedata);
}

static Handle PrepSDKCall_GetNextThink(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::GetNextThink");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::GetNextThink");
	
	return call;
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

static Handle PrepSDKCall_CalculateAmmoPackPositionAndAngles(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::CalculateAmmoPackPositionAndAngles");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::CalculateAmmoPackPositionAndAngles");
	
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

static Handle PrepSDKCall_GetGlobalTeam(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "GetGlobalTeam");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: GetGlobalTeam");
	
	return call;
}

static Handle PrepSDKCall_GetPlayerClassData(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "GetPlayerClassData");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: GetPlayerClassData");
	
	return call;
}

static Handle PrepSDKCall_ChangeTeam(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::ChangeTeam");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::ChangeTeam");
	
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

static Handle PrepSDKCall_WeaponCanSwitchTo(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseCombatCharacter::Weapon_CanSwitchTo");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseCombatCharacter::Weapon_CanSwitchTo");
	
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

static Handle PrepSDKCall_GetSlot(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseCombatWeapon::GetSlot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create call: CBaseCombatWeapon::GetSlot");
	
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

static Handle PrepSDKCall_StudioFrameAdvance(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseAnimating::StudioFrameAdvance");
	
	return call;
}

static Handle PrepSDKCall_AddPlayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeam::AddPlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTeam::AddPlayer");
	
	return call;
}

static Handle PrepSDKCall_RemovePlayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeam::RemovePlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTeam::RemovePlayer");
	
	return call;
}

static Handle PrepSDKCall_VehicleSetupMove(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseServerVehicle::SetupMove");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CBaseServerVehicle::SetupMove");
	
	return call;
}

static Handle PrepSDKCall_HandleEntryExitFinish(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseServerVehicle::HandleEntryExitFinish");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CBaseServerVehicle::HandleEntryExitFinish");
	
	return call;
}

static Handle PrepSDKCall_GetDriver(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseServerVehicle::GetDriver");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CBaseServerVehicle::GetDriver");
	
	return call;
}

static Handle PrepSDKCall_GetHealRate(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CWeaponMedigun::GetHealRate");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CWeaponMedigun::GetHealRate");
	
	return call;
}

float SDKCall_GetNextThink(int entity, const char[] context = "")
{
	if (context[0])
		return SDKCall(g_SDKCallGetNextThink, entity, context);
	else
		return SDKCall(g_SDKCallGetNextThink, entity, NULL_STRING);
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

Address SDKCall_GetLoadoutItem(int client, TFClassType class, int slot)
{
	return SDKCall(g_SDKCallGetLoadoutItem, client, class, slot, false);
}

int SDKCall_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(g_SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}

int SDKCall_GetMaxAmmo(int client, int ammoType)
{
	return SDKCall(g_SDKCallGetMaxAmmo, client, ammoType, -1);
}

bool SDKCall_CalculateAmmoPackPositionAndAngles(int client, int weapon, float[3] origin, float[3] angles)
{
	return SDKCall(g_SDKCallCalculateAmmoPackPositionAndAngles, client, weapon, origin, angles);
}

bool SDKCall_FindAndHealTargets(int medigun)
{
	return SDKCall(g_SDKCallFindAndHealTargets, medigun);
}

Address SDKCall_GetGlobalTeam(TFTeam team)
{
	return SDKCall(g_SDKCallGetGlobalTeam, team);
}

Address SDKCall_GetPlayerClassData(TFClassType class)
{
	return SDKCall(g_SDKCallGetPlayerClassData, class);
}

void SDKCall_ChangeTeam(int entity, TFTeam team)
{
	SDKCall(g_SDKCallChangeTeam, entity, team);
}

float SDKCall_GetDefaultItemChargeMeterValue(int weapon)
{
	return SDKCall(g_SDKCallGetDefaultItemChargeMeterValue, weapon);
}

bool SDKCall_WeaponCanSwitchTo(int client, int weapon)
{
	return SDKCall(g_SDKCallWeaponCanSwitchTo, client, weapon);
}

int SDKCall_GiveNamedItem(int client, const char[] classname, int subtype, Address item, bool force)
{
	return SDKCall(g_SDKCallGiveNamedItem, client, classname, subtype, item, force);
}

int SDKCall_GetSlot(int weapon)
{
	return SDKCall(g_SDKCallGetSlot, weapon);
}

void SDKCall_EquipWearable(int client, int wearable)
{
	SDKCall(g_SDKCallEquipWearable, client, wearable);
}

void SDKCall_StudioFrameAdvance(int entity)
{
	SDKCall(g_SDKCallStudioFrameAdvance, entity);
}

void SDKCall_AddPlayer(Address team, int client)
{
	SDKCall(g_SDKCallAddPlayer, team, client);
}

void SDKCall_RemovePlayer(Address team, int client)
{
	SDKCall(g_SDKCallRemovePlayer, team, client);
}

void SDKCall_VehicleSetupMove(int vehicle, int client, Address ucmd, Address helper, Address move)
{
	Address serverVehicle = GetServerVehicle(vehicle);
	if (serverVehicle != Address_Null)
		SDKCall(g_SDKCallVehicleSetupMove, serverVehicle, client, ucmd, helper, move);
}

void SDKCall_HandleEntryExitFinish(int vehicle, bool exitAnimOn, bool resetAnim)
{
	Address serverVehicle = GetServerVehicle(vehicle);
	if (serverVehicle != Address_Null)
		SDKCall(g_SDKCallHandleEntryExitFinish, serverVehicle, exitAnimOn, resetAnim);
}

int SDKCall_GetDriver(Address serverVehicle)
{
	if (g_SDKCallGetDriver != null)
		return SDKCall(g_SDKCallGetDriver, serverVehicle);
	
	return -1;
}

float SDKCall_GetHealRate(int medigun)
{
	if (g_SDKCallGetHealRate != null)
		return SDKCall(g_SDKCallGetHealRate, medigun);
	
	return 0.0;
}
