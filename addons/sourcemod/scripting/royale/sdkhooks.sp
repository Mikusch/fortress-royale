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

void SDKHooks_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, SDKHookCB_Client_WeaponEquipPost);
	SDKHook(client, SDKHook_WeaponSwitchPost, SDKHookCB_Client_WeaponSwitchPost);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	
}

static void SDKHookCB_Client_WeaponEquipPost(int client, int weapon)
{
	if (ShouldUseCustomViewModel(client, weapon))
	{
		SetEntityModel(weapon, g_viewModelArms[TFClass_Heavy]);
		SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
		SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
	}
}

static void SDKHookCB_Client_WeaponSwitchPost(int client, int weapon)
{
	if (ShouldUseCustomViewModel(client, weapon))
	{
		int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		SetEntProp(viewModel, Prop_Data, "m_nModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
		SetEntProp(viewModel, Prop_Send, "m_fEffects", GetEntProp(viewModel, Prop_Send, "m_fEffects") | EF_NODRAW);
		
		FRPlayer(client).RemoveWearableVM();
		
		int wearable = EntIndexToEntRef(CreateViewModelWearable(client, weapon));
		SetEntityModel(wearable, g_viewModelArms[TF2_GetPlayerClass(client)]);
		
		FRPlayer(client).SetWearableVM(wearable);
	}
	else
	{
		FRPlayer(client).RemoveWearableVM();
	}
}
