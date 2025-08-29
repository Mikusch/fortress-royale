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

void SDKHooks_HookEntity(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		PSM_SDKHook(entity, SDKHook_WeaponEquipPost, CTFPlayer_WeaponEquipPost);
		PSM_SDKHook(entity, SDKHook_WeaponSwitchPost, CTFPlayer_WeaponSwitchPost);
		PSM_SDKHook(entity, SDKHook_ShouldCollide, CTFPlayer_ShouldCollide);
		PSM_SDKHook(entity, SDKHook_OnTakeDamage, CTFPlayer_OnTakeDamage);
	}
	else if (StrEqual(classname, "tf_player_manager"))
	{
		PSM_SDKHook(entity, SDKHook_ThinkPost, CTFPlayerResource_ThinkPost);
	}
	else if (!strncmp(classname, "prop_", 5))
	{
		PSM_SDKHook(entity, SDKHook_SpawnPost, CDynamicProp_SpawnPost);
	}
	else if (!strncmp(classname, "item_healthkit_", 15))
	{
		PSM_SDKHook(entity, SDKHook_Touch, CHealthKit_Touch);
		PSM_SDKHook(entity, SDKHook_TouchPost, CHealthKit_TouchPost);
	}
}

static void CTFPlayer_WeaponEquipPost(int client, int weapon)
{
	if (ShouldUseCustomViewModel(client, weapon))
	{
		SetEntityModel(weapon, g_viewModelArms[TFClass_Heavy]);
		SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
		SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
	}
}

static void CTFPlayer_WeaponSwitchPost(int client, int weapon)
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

static bool CTFPlayer_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	// Avoid getting stuck in players while parachuting
	if (collisiongroup == COLLISION_GROUP_PLAYER_MOVEMENT && FRPlayer(entity).m_bIsParachuting)
		return false;
	
	return originalResult;
}

static Action CTFPlayer_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (victim != attacker && IsValidClient(attacker))
	{
		// Starting fists should be weaker than other melees
		int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		if (IsWeaponFists(weapon))
		{
			damage *= fr_fists_damage_multiplier.FloatValue;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

static void CTFPlayerResource_ThinkPost(int entity)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		SetEntProp(entity, Prop_Send, "m_iPlayerClass", TFClass_Unknown, _, client);
	}
}

static void CDynamicProp_SpawnPost(int entity)
{
	if (!g_bIsMapRunning || !IsInWaitingForPlayers())
		return;
	
	// Remove all valid crates during waiting for players
	if (FRCrate(entity).IsValidCrate())
	{
		RemoveEntity(entity);
	}
}

static Action CHealthKit_Touch(int entity, int other)
{
	g_bInHealthKitTouch = true;
	
	return Plugin_Continue;
}

static void CHealthKit_TouchPost(int entity, int other)
{
	g_bInHealthKitTouch = false;
}
