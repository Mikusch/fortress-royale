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

public bool ItemCallback_CreateDroppedWeapon(int client, CallbackParams params, const float origin[3])
{
	int item_def_index;
	if (!params.GetIntEx("item_def_index", item_def_index))
	{
		LogError("Failed to find required callback parameter 'item_def_index'");
		return false;
	}
	
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
