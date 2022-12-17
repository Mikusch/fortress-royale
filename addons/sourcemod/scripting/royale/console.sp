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

void Console_Init()
{
	AddCommandListener(CommandListener_DropItem, "dropitem");
}

static Action CommandListener_DropItem(int client, const char[] command, int argc)
{
	// If the player has an item, drop it first
	if (GetEntPropEnt(client, Prop_Send, "m_hItem") != -1)
		return Plugin_Continue;
	
	// The following will be dropped (in that order):
	// - current active weapon
	// - wearables (can't be used as active weapon)
	// - weapons that can't be switched to (as determined by TF2)
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	bool found = (weapon != -1) && TF2_ShouldDropWeapon(client, weapon);
	
	if (!found)
	{
		// TODO: Only iterate normal loadout slots e.g. primary to builder weapons (NO WEARABLES)
		for (int loadoutSlot = 0; loadoutSlot < CLASS_LOADOUT_POSITION_COUNT; loadoutSlot++)
		{
			weapon = TF2Util_GetPlayerLoadoutEntity(client, loadoutSlot);
			if (weapon != -1 && TF2_ShouldDropWeapon(client, weapon))
			{
				PrintToServer("weapon %d", weapon);
				found = true;
				break;
			}
		}
	}
	
	if (!found)
		return Plugin_Continue;
	
	float vecOrigin[3], vecAngles[3];
	if (!SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(client, weapon, vecOrigin, vecAngles))
		return Plugin_Continue;
	
	char model[PLATFORM_MAX_PATH];
	GetItemWorldModel(weapon, model, sizeof(model));
	
	int droppedWeapon = SDKCall_CTFDroppedWeapon_Create(client, vecOrigin, vecAngles, model, GetEntityAddress(weapon) + FindItemOffset(weapon));
	if (IsValidEntity(droppedWeapon))
	{
		if (IsCTFWeaponBase(weapon))
		{
			SDKCall_CTFDroppedWeapon_InitDroppedWeapon(droppedWeapon, client, weapon, true);
		}
		
		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}
	
	return Plugin_Continue;
}

bool TF2_ShouldDropWeapon(int client, int weapon)
{
	// TODO
	return true;
}
