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

void SDKHooks_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, SDKHookCB_Client_WeaponEquipPost);
	SDKHook(client, SDKHook_WeaponSwitchPost, SDKHookCB_Client_WeaponSwitchPost);
	SDKHook(client, SDKHook_ShouldCollide, SDKHookCB_Client_ShouldCollide);
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
}

void SDKHooks_UnhookClient(int client)
{
	SDKUnhook(client, SDKHook_WeaponEquipPost, SDKHookCB_Client_WeaponEquipPost);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, SDKHookCB_Client_WeaponSwitchPost);
	SDKUnhook(client, SDKHook_ShouldCollide, SDKHookCB_Client_ShouldCollide);
	SDKUnhook(client, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (!strncmp(classname, "prop_", 5))
	{
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_PropDynamic_SpawnPost);
	}
	else if (!strncmp(classname, "item_healthkit_", 15))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_ItemHealthKit_Touch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_ItemHealthKit_TouchPost);
	}
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

static bool SDKHookCB_Client_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	// Avoid getting stuck in players while parachuting
	if (collisiongroup == COLLISION_GROUP_PLAYER_MOVEMENT && FRPlayer(entity).m_bIsParachuting)
		return false;
	
	return originalResult;
}

static Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (victim != attacker && IsValidClient(attacker))
	{
		// Starting fists should be weaker than other melees
		int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		if (IsWeaponFists(weapon))
		{
			damage *= sm_fr_fists_damage_multiplier.FloatValue;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

static void SDKHookCB_PropDynamic_SpawnPost(int entity)
{
	if (!g_bIsMapRunning || !IsInWaitingForPlayers())
		return;
	
	// Remove all valid crates during waiting for players
	if (FRCrate(entity).IsValidCrate())
	{
		RemoveEntity(entity);
	}
}

static Action SDKHookCB_ItemHealthKit_Touch(int entity, int other)
{
	g_bInHealthKitTouch = true;
	
	return Plugin_Continue;
}

static void SDKHookCB_ItemHealthKit_TouchPost(int entity, int other)
{
	g_bInHealthKitTouch = false;
}
