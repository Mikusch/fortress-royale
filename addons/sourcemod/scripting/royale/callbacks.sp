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

public void ItemCallback_PrecacheModel(CallbackParams params)
{
	int iItemDefIndex;
	if (!params.GetIntEx("item_def_index", iItemDefIndex))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return;
	}
	
	char szModel[PLATFORM_MAX_PATH];
	if (!params.GetString("model", szModel, sizeof(szModel)))
	{
		LogError("Failed to find required callback parameter 'model'");
		return;
	}
	
	any aValues[2];
	aValues[0] = iItemDefIndex;
	aValues[1] = PrecacheModel(szModel);
	g_itemModelIndexes.PushArray(aValues);
}

public bool ItemCallback_CreateDroppedWeapon(int client, CallbackParams params, const float vecOrigin[3], const float vecAngles[3])
{
	int iItemDefIndex;
	if (!params.GetIntEx("item_def_index", iItemDefIndex))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return false;
	}
	
	TFClassType nClass = TF2_GetPlayerClass(client);
	
	int iSlot = TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass);
	if (iSlot == -1)
		return false;
	
	Address pScriptItem = SDKCall_CTFPlayer_GetLoadoutItem(client, nClass, iSlot);
	if (!pScriptItem)
		return false;
	
	char szWeaponName[64];
	if (!TF2Econ_GetItemClassName(iItemDefIndex, szWeaponName, sizeof(szWeaponName)))
		return false;
	
	TF2Econ_TranslateWeaponEntForClass(szWeaponName, sizeof(szWeaponName), nClass);
	
	int weapon = -1;
	
	// Check if the player has this weapon equipped
	int iLoadoutItemDefIndex = LoadFromAddress(pScriptItem + view_as<Address>(0x4), NumberType_Int16);	// CEconItemView::m_iItemDefinitionIndex
	if (iLoadoutItemDefIndex == iItemDefIndex)
	{
		weapon = SDKCall_CTFPlayer_GiveNamedItem(client, szWeaponName, 0, pScriptItem, true);
	}
	
	// Check if the player has a suitable reskin equipped
	if (!IsValidEntity(weapon))
	{
		char szReskins[256];
		if (params.GetString("reskins", szReskins, sizeof(szReskins)))
		{
			char aBuffers[32][8];
			int count = ExplodeString(szReskins, ",", aBuffers, sizeof(aBuffers), sizeof(aBuffers[]));
			for (int i = 0; i < count; i++)
			{
				int iValue;
				if (StringToIntEx(aBuffers[i], iValue) && iLoadoutItemDefIndex == iValue)
				{
					weapon = SDKCall_CTFPlayer_GiveNamedItem(client, szWeaponName, 0, pScriptItem, true);
					break;
				}
			}
		}
	}
	
	// If we did not find a weapon, generate a default one
	if (!IsValidEntity(weapon))
	{
		weapon = GenerateDefaultItem(client, iItemDefIndex);
	}
	
	SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	ItemGiveTo(client, weapon);
	
	char szModel[PLATFORM_MAX_PATH];
	GetItemWorldModel(weapon, szModel, sizeof(szModel));
	
	int newDroppedWeapon = CreateDroppedWeapon(client, vecOrigin, vecAngles, szModel, GetEntityAddress(weapon) + FindItemOffset(weapon));
	if (IsValidEntity(newDroppedWeapon))
	{
		if (TF2Util_IsEntityWeapon(weapon))
		{
			SDKCall_CTFDroppedWeapon_InitDroppedWeapon(newDroppedWeapon, client, weapon, false);
		}
		else if (TF2Util_IsEntityWearable(weapon))
		{
			InitDroppedWearable(newDroppedWeapon, client, weapon, true);
		}
	}
	
	TF2_RemovePlayerItem(client, weapon);
	
	return true;
}

public bool ItemCallback_CanBeUsedByPlayer(int client, CallbackParams params)
{
	int iItemDefIndex;
	if (!params.GetIntEx("item_def_index", iItemDefIndex))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return false;
	}
	
	TFClassType nClass = TF2_GetPlayerClass(client);
	return TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass) != -1;
}
