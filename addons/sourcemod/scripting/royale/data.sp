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

static bool m_bIsParachuting[MAXPLAYERS + 1];
static int m_hWearableVM[MAXPLAYERS + 1];
static float m_flCrateOpenTime[MAXPLAYERS + 1];
static FRPlayerState m_nPlayerState[MAXPLAYERS + 1];

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
	
	property bool m_bIsParachuting
	{
		public get()
		{
			return m_bIsParachuting[this.index];
		}
		public set(bool bIsParachuting)
		{
			m_bIsParachuting[this.index] = bIsParachuting;
		}
	}
	
	property int m_hWearableVM
	{
		public get()
		{
			return m_hWearableVM[this.index];
		}
		public set(int clientWearableVM)
		{
			m_hWearableVM[this.index] = clientWearableVM;
		}
	}
	
	property float m_flCrateOpenTime
	{
		public get()
		{
			return m_flCrateOpenTime[this.index];
		}
		public set(float flCrateOpenTime)
		{
			m_flCrateOpenTime[this.index] = flCrateOpenTime;
		}
	}
	
	property FRPlayerState m_nPlayerState
	{
		public get()
		{
			return m_nPlayerState[this.index];
		}
		public set(FRPlayerState nPlayerState)
		{
			m_nPlayerState[this.index] = nPlayerState;
		}
	}
	
	public FRPlayerState GetPlayerState()
	{
		return this.m_nPlayerState;
	}
	
	public void SetPlayerState(FRPlayerState nState)
	{
		LogMessage("Changing state to %d for %N", nState, this.index);
		
		this.m_nPlayerState = nState;
	}
	
	public void SetWearableVM(int wearable)
	{
		this.m_hWearableVM = wearable;
	}
	
	public void RemoveWearableVM()
	{
		if (IsValidEntity(this.m_hWearableVM))
		{
			RemoveEntity(this.m_hWearableVM);
		}
		
		this.m_hWearableVM = INVALID_ENT_REFERENCE;
	}
	
	public bool TryToOpenCrate(int crate)
	{
		// Crate is already claimed by another player
		if (!FRCrate(crate).CanUse(this.index))
		{
			return false;
		}
		
		// Claim and start opening this crate
		if (this.m_flCrateOpenTime == 0.0)
		{
			this.m_flCrateOpenTime = GetGameTime();
			
			FRCrate(crate).StartOpen(this.index);
		}
		
		if (this.m_flCrateOpenTime + fr_crate_open_time.FloatValue > GetGameTime())
		{
			char szMessage[64];
			Format(szMessage, sizeof(szMessage), "%T", "Crate_Opening", this.index);
			
			int iSeconds = RoundToCeil(GetGameTime() - this.m_flCrateOpenTime);
			for (int i = 0; i < iSeconds; i++)
			{
				Format(szMessage, sizeof(szMessage), "%s%s", szMessage, ".");
			}
			
			FRCrate(crate).SetText(szMessage);
		}
		else
		{
			this.StopOpeningCrate(crate);
			FRCrate(crate).DropItem(this.index);
			
			EmitSoundToAll(")ui/itemcrate_smash_rare.wav", crate, SNDCHAN_STATIC);
			
			float origin[3];
			CBaseEntity(crate).WorldSpaceCenter(origin);
			TE_TFParticleEffect(g_szCrateParticles[GetRandomInt(0, sizeof(g_szCrateParticles) - 1)], origin);
			TE_TFParticleEffect("mvm_loot_explosion", origin);
			
			AcceptEntityInput(crate, "Break");
		}
		
		return true;
	}
	
	public void StopOpeningCrate(int crate = -1)
	{
		// We are not opening a crate right now...
		if (this.m_flCrateOpenTime == 0.0)
			return;
		
		this.m_flCrateOpenTime = 0.0;
		
		// If no crate was passed in, search for claimed crates
		if (crate != -1)
		{
			FRCrate(crate).CancelOpen();
		}
		else
		{
			while ((crate = FindEntityByClassname(crate, "prop_dynamic")) != -1)
			{
				// Find our current crate
				if (FREntity(crate).IsValidCrate() && FRCrate(crate).m_claimedBy == this.index)
				{
					FRCrate(crate).CancelOpen();
					break;
				}
			}
		}
	}
	
	public void RemoveItem(int item)
	{
		if (TF2Util_IsEntityWeapon(item))
		{
			RemovePlayerItem(this.index, item);
			RemoveExtraWearables(item);
		}
		else if (TF2Util_IsEntityWearable(item))
		{
			TF2_RemoveWearable(this.index, item);
		}
		
		RemoveEntity(item);
	}
	
	public void RemoveAllItems()
	{
		for (int i = 0; i < this.GetPropArraySize(Prop_Send, "m_hMyWeapons"); ++i)
		{
			int weapon = this.GetPropEnt(Prop_Send, "m_hMyWeapons", i);
			if (weapon == -1)
				continue;
			
			this.RemoveItem(weapon);
		}
		
		for (int wbl = TF2Util_GetPlayerWearableCount(this.index) - 1; wbl >= 0; wbl--)
		{
			int wearable = TF2Util_GetPlayerWearable(this.index, wbl);
			if (wearable == -1)
				continue;
			
			this.RemoveItem(wearable);
		}
	}
	
	public bool IsInAVehicle()
	{
		return this.GetPropEnt(Prop_Data, "m_hVehicle") != -1;
	}
	
	public void Init()
	{
		this.m_bIsParachuting = false;
		this.m_flCrateOpenTime = 0.0;
		this.m_hWearableVM = INVALID_ENT_REFERENCE;
		this.SetPlayerState(FRPlayerState_Waiting);
	}
}
