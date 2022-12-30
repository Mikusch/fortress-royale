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
static float m_flCrateOpenTime[MAXPLAYERS + 1];

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
	
	public bool IsAlive()
	{
		// TODO Respect player state
		return IsPlayerAlive(this.index);
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
			this.AddFlag(FL_FROZEN);
			
			FRCrate(crate).m_claimedBy = this.index;
			EmitSoundToAll(")ui/item_open_crate.wav", crate);
		}
		
		if (this.m_flCrateOpenTime + fr_crate_open_time.FloatValue > GetGameTime())
		{
			char szMessage[64];
			Format(szMessage, sizeof(szMessage), "%T", "Crate_Opening", this.index, this.index);
			
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
			
			EmitSoundToAll(")ui/itemcrate_smash_ultrarare_short.wav", crate, SNDCHAN_STATIC);
			
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
		this.RemoveFlag(FL_FROZEN);
		
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
	
	public void Init()
	{
		this.m_clientWearableVM = INVALID_ENT_REFERENCE;
	}
}
