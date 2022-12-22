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

void DHooks_Init(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", _, DHookCallback_CTFPlayer_PickupWeaponFromOther_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::CanPickupDroppedWeapon", DHookCallback_CTFPlayer_CanPickupDroppedWeapon_Pre, _);
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

static MRESReturn DHookCallback_CTFPlayer_PickupWeaponFromOther_Post(int player, DHookReturn ret, DHookParam params)
{
	// If it's already working - great! Don't do anything.
	if (ret.Value == true)
		return MRES_Ignored;
	
	int droppedWeapon = params.Get(1);
	
	Address pItem = GetEntityAddress(droppedWeapon) + FindItemOffset(droppedWeapon);
	if (!LoadFromAddress(pItem, NumberType_Int32))
		return MRES_Ignored;
	
	if (GetEntProp(droppedWeapon, Prop_Send, "m_bInitialized"))
	{
		int itemdef = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		TFClassType class = TF2_GetPlayerClass(player);
		int itemSlot = TF2Econ_GetItemLoadoutSlot(itemdef, class);
		int weapon = GetEntityForLoadoutSlot(player, itemSlot);
		
		// we need to force translating the name here.
		// GiveNamedItem will not translate if we force creating the item
		char weaponName[64];
		TF2Econ_GetItemClassName(itemdef, weaponName, sizeof(weaponName));
		TF2Econ_TranslateWeaponEntForClass(weaponName, sizeof(weaponName), class);
		
		int newItem = SDKCall_CTFPlayer_GiveNamedItem(player, weaponName, 0, pItem, true);
		if (IsValidEntity(newItem))
		{
			// make sure we removed our current weapon
			if (IsValidEntity(weapon))
			{
				// drop current weapon
				float vecPackOrigin[3], vecPackAngles[3];
				SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(player, weapon, vecPackOrigin, vecPackAngles);
				
				char model[PLATFORM_MAX_PATH];
				GetItemWorldModel(weapon, model, sizeof(model));
				
				int newDroppedWeapon = SDKCall_CTFDroppedWeapon_Create(player, vecPackOrigin, vecPackAngles, model, GetEntityAddress(weapon) + FindItemOffset(weapon));
				if (IsValidEntity(newDroppedWeapon))
				{
					if (TF2Util_IsEntityWeapon(weapon))
					{
						SDKCall_CTFDroppedWeapon_InitDroppedWeapon(newDroppedWeapon, player, weapon, true);
					}
					else if (TF2Util_IsEntityWearable(weapon))
					{
						InitDroppedWearable(newDroppedWeapon, player, weapon, true);
					}
				}
				
				TF2_RemovePlayerItem(player, weapon);
			}
			
			int lastWeapon = GetEntPropEnt(player, Prop_Send, "m_hLastWeapon");
			SetEntProp(newItem, Prop_Send, "m_bValidatedAttachedEntity", true);
			ItemGiveTo(player, newItem);
			SetEntPropEnt(player, Prop_Send, "m_hLastWeapon", lastWeapon);
			
			if (TF2Util_IsEntityWeapon(newItem))
			{
				SDKCall_CTFDroppedWeapon_InitPickedUpWeapon(droppedWeapon, player, newItem);
				
				// can't use the weapon we just picked up?
				if (!SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(player, newItem))
				{
					// try next best thing we can use
					SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(player, newItem);
				}
			}
			
			// delay pickup weapon message
			FRPlayer(player).m_flSendPickupWeaponMessageTime = GetGameTime() + 0.1;
			
			ret.Value = true;
			return MRES_Supercede;
		}
	}
	
	ret.Value = false;
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CTFPlayer_CanPickupDroppedWeapon_Pre(int player, DHookReturn ret, DHookParam params)
{
	int weapon = params.Get(1);
	
	if (!GetEntProp(weapon, Prop_Send, "m_bInitialized"))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	TFClassType class = TF2_GetPlayerClass(player);
	if (class == TFClass_Spy && (TF2_IsPlayerInCondition(player, TFCond_Disguised) || TF2_GetPercentInvisible(player) > 0.0))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (TF2_IsPlayerInCondition(player, TFCond_Taunting))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (!IsPlayerAlive(player))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (GetEntPropEnt(player, Prop_Send, "m_hActiveWeapon") == -1)
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	ret.Value = CanWeaponBeUsedByClass(weapon, class);
	return MRES_Supercede;
}