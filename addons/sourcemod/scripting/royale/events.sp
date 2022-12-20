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

void Events_Init()
{
	
}

int CreateFists(int client)
{
	Handle item = TF2Items_CreateItem(FORCE_GENERATION);
	TF2Items_SetClassname(item, "tf_weapon_fists");
	TF2Items_SetItemIndex(item, 5);
	
	int weapon = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	EquipPlayerWeapon(client, weapon);
	TF2Util_SetPlayerActiveWeapon(client, weapon);
	
	return weapon;
}
