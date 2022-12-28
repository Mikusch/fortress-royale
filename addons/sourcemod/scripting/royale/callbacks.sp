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
	int item_def_index;
	if (!params.GetIntEx("item_def_index", item_def_index))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return;
	}
	
	char model[PLATFORM_MAX_PATH];
	if (!params.GetString("model", model, sizeof(model)))
	{
		LogError("Failed to find required callback parameter 'model'");
		return;
	}
	
	any values[2];
	values[0] = item_def_index;
	values[1] = PrecacheModel(model);
	g_itemModelIndexes.PushArray(values);
}

public bool ItemCallback_CreateDroppedWeapon(int client, CallbackParams params, const float origin[3], const float angles[3])
{
	int item_def_index;
	if (!params.GetIntEx("item_def_index", item_def_index))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return false;
	}
	
	TFClassType class = TF2_GetPlayerClass(client);
	
	int slot = TF2Econ_GetItemLoadoutSlot(item_def_index, class);
	if (slot == -1)
		return false;
	
	Address pScriptItem = SDKCall_CTFPlayer_GetLoadoutItem(client, class, slot);
	if (!pScriptItem)
		return false;
	
	char weaponName[64];
	TF2Econ_GetItemClassName(item_def_index, weaponName, sizeof(weaponName));
	TF2Econ_TranslateWeaponEntForClass(weaponName, sizeof(weaponName), class);
	
	int weapon = -1;
	
	// CEconItemView::m_iItemDefinitionIndex
	int actualDefIndex = LoadFromAddress(pScriptItem + view_as<Address>(0x4), NumberType_Int16);
	if (actualDefIndex == item_def_index)
	{
		weapon = SDKCall_CTFPlayer_GiveNamedItem(client, weaponName, 0, pScriptItem, true);
	}
	
	char buffer[256];
	if (params.GetString("reskins", buffer, sizeof(buffer)))
	{
		char buffers[32][8];
		int count = ExplodeString(buffer, ",", buffers, sizeof(buffers), sizeof(buffers[]));
		for (int i = 0; i < count; i++)
		{
			int value;
			if (StringToIntEx(buffers[i], value) && actualDefIndex == value)
			{
				weapon = SDKCall_CTFPlayer_GiveNamedItem(client, weaponName, 0, pScriptItem, true);
				break;
			}
		}
	}
	
	if (!IsValidEntity(weapon))
	{
		weapon = GenerateDefaultItem(client, item_def_index);
	}
	
	if (!IsValidEntity(weapon))
	{
		return false;
	}
	
	char model[PLATFORM_MAX_PATH];
	GetItemWorldModel(weapon, model, sizeof(model));
	
	int newDroppedWeapon = CreateDroppedWeapon(client, origin, angles, model, GetEntityAddress(weapon) + FindItemOffset(weapon));
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
	int item_def_index;
	if (!params.GetIntEx("item_def_index", item_def_index))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return false;
	}
	
	TFClassType class = TF2_GetPlayerClass(client);
	return TF2Econ_GetItemLoadoutSlot(item_def_index, class) != -1;
}
