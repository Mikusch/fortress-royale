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

static int m_clientWearableVM[MAXPLAYERS + 1];

methodmap FRPlayer < CBaseCombatCharacter
{
	public FRPlayer(int client)
	{
		return view_as<FRPlayer>(client);
	}
	
	property float m_flSendPickupWeaponMessageTime
	{
		public get()
		{
			return GetEntDataFloat(this.index, FindSendPropInfo("CTFPlayer", "m_hGrapplingHookTarget") - 4);
		}
		public set(float flSendPickupWeaponMessageTime)
		{
			SetEntDataFloat(this.index, FindSendPropInfo("CTFPlayer", "m_hGrapplingHookTarget") - 4, flSendPickupWeaponMessageTime);
		}
	}
	
	property int m_clientWearableVM
	{
		public get()
		{
			return m_clientWearableVM[this.index];
		}
		public set(int clientWearableVM)
		{
			m_clientWearableVM[this.index] = clientWearableVM;
		}
	}
	
	public void SetWearableVM(int wearable)
	{
		this.m_clientWearableVM = wearable;
	}
	
	public void RemoveWearableVM()
	{
		if (IsValidEntity(this.m_clientWearableVM))
		{
			RemoveEntity(this.m_clientWearableVM);
		}
		
		this.m_clientWearableVM = INVALID_ENT_REFERENCE;
	}
	
	public void Init()
	{
		this.m_clientWearableVM = INVALID_ENT_REFERENCE;
	}
}
