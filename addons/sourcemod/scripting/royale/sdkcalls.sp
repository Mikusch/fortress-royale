/**
 * Copyright (C) 2023  Mikusch
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

#pragma newdecls required
#pragma semicolon 1

static Handle g_SDKCall_CBaseEntity_SetMoveType;
static Handle g_SDKCall_CTFDroppedWeapon_Create;
static Handle g_SDKCall_CTFDroppedWeapon_InitDroppedWeapon;
static Handle g_SDKCall_CTFDroppedWeapon_InitPickedUpWeapon;
static Handle g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles;
static Handle g_SDKCall_CTFPlayer_GiveNamedItem;
static Handle g_SDKCall_CTFPlayer_GetLoadoutItem;
static Handle g_SDKCall_CTFPlayer_TryToPickupDroppedWeapon;
static Handle g_SDKCall_CTFPlayer_PostInventoryApplication;
static Handle g_SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo;
static Handle g_SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon;
static Handle g_SDKCall_CBaseCombatWeapon_SetSubType;
static Handle g_SDKCall_CBaseCombatWeapon_GetWorldModel;
static Handle g_SDKCall_CTFPowerup_DropSingleInstance;

void SDKCalls_Init(GameData gamedata)
{
	g_SDKCall_CBaseEntity_SetMoveType = PrepSDKCall_CBaseEntity_SetMoveType(gamedata);
	g_SDKCall_CTFDroppedWeapon_Create = PrepSDKCall_CTFDroppedWeapon_Create(gamedata);
	g_SDKCall_CTFDroppedWeapon_InitDroppedWeapon = PrepSDKCall_CTFDroppedWeapon_InitDroppedWeapon(gamedata);
	g_SDKCall_CTFDroppedWeapon_InitPickedUpWeapon = PrepSDKCall_CTFDroppedWeapon_InitPickedUpWeapon(gamedata);
	g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles = PrepSDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(gamedata);
	g_SDKCall_CTFPlayer_GiveNamedItem = PrepSDKCall_CTFPlayer_GiveNamedItem(gamedata);
	g_SDKCall_CTFPlayer_GetLoadoutItem = PrepSDKCall_CTFPlayer_GetLoadoutItem(gamedata);
	g_SDKCall_CTFPlayer_TryToPickupDroppedWeapon = PrepSDKCall_CTFPlayer_TryToPickupDroppedWeapon(gamedata);
	g_SDKCall_CTFPlayer_PostInventoryApplication = PrepSDKCall_CTFPlayer_PostInventoryApplication(gamedata);
	g_SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo = PrepSDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(gamedata);
	g_SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon = PrepSDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(gamedata);
	g_SDKCall_CBaseCombatWeapon_SetSubType = PrepSDKCall_CBaseCombatWeapon_SetSubType(gamedata);
	g_SDKCall_CBaseCombatWeapon_GetWorldModel = PrepSDKCall_CBaseCombatWeapon_GetWorldModel(gamedata);
	g_SDKCall_CTFPowerup_DropSingleInstance = PrepSDKCall_CTFPowerup_DropSingleInstance(gamedata);
}

static Handle PrepSDKCall_CBaseEntity_SetMoveType(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::SetMoveType");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::SetMoveType");
	
	return call;
}

static Handle PrepSDKCall_CTFDroppedWeapon_Create(GameData gamedata)
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

static Handle PrepSDKCall_CTFDroppedWeapon_InitDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFDroppedWeapon::InitDroppedWeapon");
	
	return call;
}

static Handle PrepSDKCall_CTFDroppedWeapon_InitPickedUpWeapon(GameData gamedata)
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

static Handle PrepSDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::CalculateAmmoPackPositionAndAngles");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::CalculateAmmoPackPositionAndAngles");
	
	return call;
}

static Handle PrepSDKCall_CTFPlayer_GiveNamedItem(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GiveNamedItem");
	
	return call;
}

static Handle PrepSDKCall_CTFPlayer_GetLoadoutItem(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetLoadoutItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GetLoadoutItem");
	
	return call;
}

static Handle PrepSDKCall_CTFPlayer_TryToPickupDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::TryToPickupDroppedWeapon");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::TryToPickupDroppedWeapon");
	
	return call;
}

static Handle PrepSDKCall_CTFPlayer_PostInventoryApplication(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::PostInventoryApplication");
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::PostInventoryApplication");
	
	return call;
}

static Handle PrepSDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseCombatCharacter::Weapon_CanSwitchTo");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseCombatCharacter::Weapon_CanSwitchTo");
	
	return call;
}

static Handle PrepSDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseCombatCharacter::SwitchToNextBestWeapon");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseCombatCharacter::SwitchToNextBestWeapon");
	
	return call;
}

static Handle PrepSDKCall_CBaseCombatWeapon_SetSubType(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseCombatWeapon::SetSubType");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseCombatWeapon::SetSubType");
	
	return call;
}

static Handle PrepSDKCall_CBaseCombatWeapon_GetWorldModel(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseCombatWeapon::GetWorldModel");
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseCombatWeapon::GetWorldModel");
	
	return call;
}

static Handle PrepSDKCall_CTFPowerup_DropSingleInstance(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPowerup::DropSingleInstance");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPowerup::DropSingleInstance");
	
	return call;
}

void SDKCall_CBaseEntity_SetMoveType(int entity, MoveType val, MoveCollide moveCollide)
{
	if (g_SDKCall_CBaseEntity_SetMoveType)
	{
		SDKCall(g_SDKCall_CBaseEntity_SetMoveType, entity, val, moveCollide);
	}
}

int SDKCall_CTFDroppedWeapon_Create(int lastOwner, const float vecOrigin[3], const float vecAngles[3], char[] szModelName, Address pItem)
{
	if (g_SDKCall_CTFDroppedWeapon_Create)
	{
		return SDKCall(g_SDKCall_CTFDroppedWeapon_Create, lastOwner, vecOrigin, vecAngles, szModelName, pItem);
	}
	
	return -1;
}

void SDKCall_CTFDroppedWeapon_InitDroppedWeapon(int droppedWeapon, int player, int weapon, bool bSwap, bool bIsSuicide = false)
{
	if (g_SDKCall_CTFDroppedWeapon_InitDroppedWeapon)
	{
		SDKCall(g_SDKCall_CTFDroppedWeapon_InitDroppedWeapon, droppedWeapon, player, weapon, bSwap, bIsSuicide);
	}
}

void SDKCall_CTFDroppedWeapon_InitPickedUpWeapon(int droppedWeapon, int player, int weapon)
{
	if (g_SDKCall_CTFDroppedWeapon_InitPickedUpWeapon)
	{
		SDKCall(g_SDKCall_CTFDroppedWeapon_InitPickedUpWeapon, droppedWeapon, player, weapon);
	}
}

bool SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(int player, int weapon, float vecOrigin[3], float vecAngles[3])
{
	if (g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles)
	{
		return SDKCall(g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles, player, weapon, vecOrigin, vecAngles);
	}
	
	return false;
}

int SDKCall_CTFPlayer_GiveNamedItem(int player, const char[] szName, int iSubType = 0, Address pScriptItem = Address_Null, bool bForce = false)
{
	if (g_SDKCall_CTFPlayer_GiveNamedItem)
	{
		g_bBypassGiveNamedItemHook = true;
		int entity = SDKCall(g_SDKCall_CTFPlayer_GiveNamedItem, player, szName, iSubType, pScriptItem, bForce);
		g_bBypassGiveNamedItemHook = false;
		
		return entity;
	}
	
	return -1;
}

Address SDKCall_CTFPlayer_GetLoadoutItem(int player, TFClassType nClass, int iSlot, bool bReportWhitelistFails = false)
{
	if (g_SDKCall_CTFPlayer_GetLoadoutItem)
	{
		return SDKCall(g_SDKCall_CTFPlayer_GetLoadoutItem, player, nClass, iSlot, bReportWhitelistFails);
	}
	
	return Address_Null;
}

bool SDKCall_CTFPlayer_TryToPickupDroppedWeapon(int player)
{
	if (g_SDKCall_CTFPlayer_TryToPickupDroppedWeapon)
	{
		return SDKCall(g_SDKCall_CTFPlayer_TryToPickupDroppedWeapon, player);
	}
	
	return false;
}

void SDKCall_CTFPlayer_PostInventoryApplication(int player)
{
	if (g_SDKCall_CTFPlayer_PostInventoryApplication)
	{
		SDKCall(g_SDKCall_CTFPlayer_PostInventoryApplication, player);
	}
}

bool SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(int player, int weapon)
{
	if (g_SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo)
	{
		return SDKCall(g_SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo, player, weapon);
	}
	
	return false;
}

bool SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(int player, int current)
{
	if (g_SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon)
	{
		return SDKCall(g_SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon, player, current);
	}
	
	return false;
}

void SDKCall_CBaseCombatWeapon_SetSubType(int weapon, TFObjectType iSubType)
{
	if (g_SDKCall_CBaseCombatWeapon_SetSubType)
	{
		SDKCall(g_SDKCall_CBaseCombatWeapon_SetSubType, weapon, iSubType);
	}
}

void SDKCall_CBaseCombatWeapon_GetWorldModel(int weapon, char[] szWorldModel, int iMaxLength)
{
	if (g_SDKCall_CBaseCombatWeapon_GetWorldModel)
	{
		SDKCall(g_SDKCall_CBaseCombatWeapon_GetWorldModel, weapon, szWorldModel, iMaxLength);
	}
}

void SDKCall_CTFPowerup_DropSingleInstance(int entity, const float vecLaunchVel[3], int thrower, float flThrowerTouchDelay, float flResetTime = 0.0)
{
	if (g_SDKCall_CTFPowerup_DropSingleInstance)
	{
		SDKCall(g_SDKCall_CTFPowerup_DropSingleInstance, entity, vecLaunchVel, thrower, flThrowerTouchDelay, flResetTime);
	}
}
