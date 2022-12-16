/**
 * Copyright (C) 2022  Mikusch
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

static Handle g_SDKCall_CTFDroppedWeapon_Create;
static Handle g_SDKCall_CTFDroppedWeapon_InitDroppedWeapon;
static Handle g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles;

void SDKCalls_Init(GameData gamedata)
{
	g_SDKCall_CTFDroppedWeapon_Create = PrepSDKCall_CTFDroppedWeapon_Create(gamedata);
	g_SDKCall_CTFDroppedWeapon_InitDroppedWeapon = PrepSDKCall_CTFDroppedWeapon_InitDroppedWeapon(gamedata);
	g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles = PrepSDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(gamedata);
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
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFDroppedWeapon::InitDroppedWeapon");
	
	return call;
}

static Handle PrepSDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(GameData gamedata)
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

int SDKCall_CTFDroppedWeapon_Create(int lastOwner, float vecOrigin[3], float vecAngles[3], char[] szModelName, Address pItem)
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

bool SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(int client, int weapon, float vecOrigin[3], float vecAngles[3])
{
	if (g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles)
	{
		return SDKCall(g_SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles, client, weapon, vecOrigin, vecAngles);
	}
	
	return false;
}
