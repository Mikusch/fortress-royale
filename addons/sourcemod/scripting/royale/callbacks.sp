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

public bool ItemCallback_CreateDroppedWeapon(int client, KeyValues data, const float vecOrigin[3], const float vecAngles[3])
{
	int iItemDefIndex = data.GetNum("item_def_index", INVALID_ITEM_DEF_INDEX);
	if (iItemDefIndex == INVALID_ITEM_DEF_INDEX)
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
		WeaponData wpnData;
		if (Config_GetWeaponDataByDefIndex(iItemDefIndex, wpnData) && wpnData.reskins)
		{
			for (int i = 0; i < wpnData.reskins.Length; i++)
			{
				if (wpnData.reskins.Get(i) == iLoadoutItemDefIndex)
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
	
	if (!IsValidEntity(weapon))
	{
		LogError("Failed to generate item with definition index '%d'", iItemDefIndex);
		return false;
	}
	
	if (nClass == TFClass_Spy && IsWeaponOfID(weapon, TF_WEAPON_BUILDER))
	{
		SDKCall_CBaseCombatWeapon_SetSubType(weapon, TFObject_Sapper);
	}
	
	// Apply attributes
	if (data.JumpToKey("attributes", false))
	{
		if (data.GotoFirstSubKey(false))
		{
			do
			{
				char name[64];
				if (data.GetSectionName(name, sizeof(name)))
				{
					float flValue = data.GetFloat(NULL_STRING);
					TF2Attrib_SetByName(weapon, name, flValue);
				}
			}
			while (data.GotoNextKey(false));
			data.GoBack();
		}
		data.GoBack();
	}
	
	// Weapon_Equip can cause weapon switches, just temporarily prevent it
	TF2Attrib_SetByName(weapon, "disable weapon switch", 1.0);
	ItemGiveTo(client, weapon);
	TF2Attrib_RemoveByName(weapon, "disable weapon switch");
	
	char szWorldModel[PLATFORM_MAX_PATH];
	if (GetItemWorldModel(weapon, szWorldModel, sizeof(szWorldModel)))
	{
		int newDroppedWeapon = CreateDroppedWeapon(vecOrigin, vecAngles, szWorldModel, GetEntityAddress(weapon) + FindItemOffset(weapon));
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
	}
	
	FRPlayer(client).RemoveItem(weapon);
	
	return true;
}

public bool ItemCallback_CanBeUsedByPlayer(int client, KeyValues data)
{
	int iItemDefIndex = data.GetNum("item_def_index", INVALID_ITEM_DEF_INDEX);
	if (iItemDefIndex == INVALID_ITEM_DEF_INDEX)
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return false;
	}
	
	TFClassType nClass = TF2_GetPlayerClass(client);
	return TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass) != -1;
}
