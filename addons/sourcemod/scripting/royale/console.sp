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

void Console_Toggle(bool enable)
{
	if (enable)
	{
		AddCommandListener(CommandListener_DropItem, "dropitem");
	}
	else
	{
		RemoveCommandListener(CommandListener_DropItem, "dropitem");
	}
}

static Action CommandListener_DropItem(int client, const char[] command, int argc)
{
	// If the player has an item, drop it first
	if (GetEntPropEnt(client, Prop_Send, "m_hItem") != -1)
	{
		return Plugin_Continue;
	}
	
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		return Plugin_Continue;
	}
	
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == -1)
	{
		return Plugin_Continue;
	}
	
	// The following will be dropped (in that order):
	// - current active weapon
	// - wearables (can't be used as active weapon)
	// - weapons that can't be switched to (as determined by TF2)
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	bool found = (weapon != -1) && ShouldDropItem(client, weapon);
	
	if (!found)
	{
		for (int slot = 0; slot <= LOADOUT_POSITION_PDA2; slot++)
		{
			weapon = TF2Util_GetPlayerLoadoutEntity(client, slot);
			if (weapon == -1)
				continue;
			
			if (TF2Util_IsEntityWearable(weapon))
			{
				// Always drop wearables
				found = true;
				break;
			}
			else
			{
				if (ShouldDropItem(client, weapon) && !SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(client, weapon))
				{
					found = true;
					break;
				}
			}
		}
	}
	
	if (!found)
	{
		if (IsWeaponFists(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")))
		{
			EmitGameSoundToClient(client, "Player.UseDeny");
			PrintCenterText(client, "%t", "Weapon_CannotDropFists");
		}
		
		return Plugin_Continue;
	}
	
	float vecOrigin[3], vecAngles[3];
	if (!SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(client, weapon, vecOrigin, vecAngles))
		return Plugin_Continue;
	
	char model[PLATFORM_MAX_PATH];
	GetItemWorldModel(weapon, model, sizeof(model));
	
	int droppedWeapon = CreateDroppedWeapon(client, vecOrigin, vecAngles, model, GetEntityAddress(weapon) + FindItemOffset(weapon));
	if (IsValidEntity(droppedWeapon))
	{
		if (TF2Util_IsEntityWeapon(weapon))
		{
			SDKCall_CTFDroppedWeapon_InitDroppedWeapon(droppedWeapon, client, weapon, true);
			
			// If the weapon we just dropped could not be switched to, stay on our current weapon
			if (SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(client, weapon))
			{
				SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(client, weapon);
			}
		}
		else if (TF2Util_IsEntityWearable(weapon))
		{
			InitDroppedWearable(droppedWeapon, client, weapon, true);
		}
		
		bool bDroppedMelee = TF2Util_GetWeaponSlot(weapon) == TFWeaponSlot_Melee;
		TF2_RemovePlayerItem(client, weapon);
		
		// If we dropped our melee weapon, get our fists back
		if (bDroppedMelee)
		{
			weapon = GenerateDefaultItem(client, TF_DEFINDEX_FISTS);
			ItemGiveTo(client, weapon);
			TF2Util_SetPlayerActiveWeapon(client, weapon);
		}
	}
	
	return Plugin_Continue;
}
