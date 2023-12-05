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
	
	// Set the skin up properly for the dropped weapon
	if (HasEntProp(weapon, Prop_Send, "m_hOwner"))
		SetEntPropEnt(weapon, Prop_Send, "m_hOwner", client);
	
	char szWorldModel[PLATFORM_MAX_PATH];
	if (GetItemWorldModel(weapon, szWorldModel, sizeof(szWorldModel)))
	{
		int newDroppedWeapon = CreateDroppedWeapon(vecOrigin, vecAngles, szWorldModel, GetEntityAddress(weapon) + FindItemOffset(weapon));
		if (IsValidEntity(newDroppedWeapon))
		{
			if (TF2Util_IsEntityWeapon(weapon))
			{
				SDKCall_CTFDroppedWeapon_InitDroppedWeapon(newDroppedWeapon, client, weapon, false);
				
				// Override ammo count to make players scavenge for ammo
				int iMaxAmmo = TF2Util_GetPlayerMaxAmmo(client, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
				SetEntData(newDroppedWeapon, g_iOffset_CTFDroppedWeapon_m_nAmmo, RoundFloat(iMaxAmmo * sm_fr_dropped_weapon_ammo_percentage.FloatValue));
			}
			else if (TF2Util_IsEntityWearable(weapon))
			{
				InitDroppedWearable(newDroppedWeapon, client, weapon, true);
			}
		}
	}
	
	RemoveEntity(weapon);
	
	return true;
}

public bool ItemCallback_CreateSingleInstancePowerup(int client, KeyValues data, const float vecOrigin[3], const float vecAngles[3])
{
	char szClassname[64];
	if (!data.GetString("classname", szClassname, sizeof(szClassname)))
	{
		LogError("Failed to find required callback parameter 'classname'");
		return false;
	}
	
	int entity = CreateEntityByName(szClassname);
	if (!IsValidEntity(entity))
	{
		LogError("Failed to create entity with classname '%s'", szClassname);
		return false;
	}
	
	DispatchSpawn(entity);
	TeleportEntity(entity, vecOrigin);
	
	float vecLaunchVel[3];
	vecLaunchVel[0] = GetRandomFloat(-50.0, 50.0);
	vecLaunchVel[1] = GetRandomFloat(-50.0, 50.0);
	vecLaunchVel[2] = GetRandomFloat(100.0, 150.0);
	
	SDKCall_CTFPowerup_DropSingleInstance(entity, vecLaunchVel, client, 0.3);
	
	return true;
}

public bool ItemCallback_ShouldDropItem(int client, KeyValues data)
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
