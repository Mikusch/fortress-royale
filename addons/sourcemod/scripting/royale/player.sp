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

static bool m_bIsParachuting[MAXPLAYERS + 1];
static float m_flLastMedigunDrainTime[MAXPLAYERS + 1];
static int m_hWearableVM[MAXPLAYERS + 1];
static int m_iOpeningCrate[MAXPLAYERS + 1];
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
	
	property float m_flLastMedigunDrainTime
	{
		public get()
		{
			return m_flLastMedigunDrainTime[this.index];
		}
		public set(float flMedigunLastDrainTime)
		{
			m_flLastMedigunDrainTime[this.index] = flMedigunLastDrainTime;
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
	
	property int m_iOpeningCrate
	{
		public get()
		{
			return m_iOpeningCrate[this.index];
		}
		public set(int crateRef)
		{
			m_iOpeningCrate[this.index] = crateRef;
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
	
	public bool IsAlive()
	{
		return IsPlayerAlive(this.index) || this.GetPlayerState() == FRPlayerState_InBattleBus;
	}
	
	public FRPlayerState GetPlayerState()
	{
		return this.m_nPlayerState;
	}
	
	public void SetPlayerState(FRPlayerState nState)
	{
		this.m_nPlayerState = nState;
	}
	
	public void SetWearableVM(int wearable)
	{
		this.m_hWearableVM = wearable;
	}
	
	public void RemoveWearableVM()
	{
		int wearable = EntRefToEntIndex(this.m_hWearableVM);
		if (wearable != -1)
		{
			TF2_RemoveWearable(this.index, wearable);
		}
		
		this.m_hWearableVM = INVALID_ENT_REFERENCE;
	}
	
	public void EquipItem(int item)
	{
		if (TF2Util_IsEntityWearable(item))
		{
			TF2Util_EquipPlayerWearable(this.index, item);
		}
		else
		{
			EquipPlayerWeapon(this.index, item);
		}
	}
	
	public bool TryToOpenCrate(int crate)
	{
		if (!FRCrate(crate).CanBeOpenedBy(this.index))
			return false;
		
		CrateData data;
		if (!FRCrate(crate).GetData(data))
			return false;
		
		int currentCrate = EntRefToEntIndex(this.m_iOpeningCrate);
		
		// If we're switching to a different crate, cancel the previous one
		if (currentCrate != -1 && currentCrate != crate)
		{
			if (FREntity(currentCrate).IsValidCrate())
			{
				FRCrate(currentCrate).CancelOpen();
			}
			this.m_iOpeningCrate = INVALID_ENT_REFERENCE;
		}
		
		// Start opening if not already opening this crate
		if (currentCrate != crate)
		{
			this.m_iOpeningCrate = EntIndexToEntRef(crate);
			FRCrate(crate).StartOpen(this.index);
		}
		
		// Let the crate handle the update logic
		if (FRCrate(crate).Update(this.index))
		{
			// Crate was opened successfully
			this.m_iOpeningCrate = INVALID_ENT_REFERENCE;
		}
		
		return true;
	}
	
	public void StopOpeningCrate(int crate = -1)
	{
		int currentCrate = EntRefToEntIndex(this.m_iOpeningCrate);
		
		// Not opening any crate
		if (currentCrate == -1)
			return;
		
		this.m_iOpeningCrate = INVALID_ENT_REFERENCE;
		
		if (crate == -1)
		{
			// Find any crates in the world still claimed by us
			while ((crate = FindEntityByClassname(crate, "prop_*")) != -1)
			{
				if (FREntity(crate).IsValidCrate() && FRCrate(crate).IsClaimedBy(this.index))
				{
					FRCrate(crate).CancelOpen();
				}
			}
		}
		else if (FREntity(crate).IsValidCrate())
		{
			FRCrate(crate).CancelOpen();
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
	
	public bool TryToPickupDroppedWeapon()
	{
		if (!SDKCall_CTFPlayer_CanAttack(this.index))
			return false;
		
		int activeWeapon = this.GetPropEnt(Prop_Send, "m_hActiveWeapon");
		if (activeWeapon != -1 && GetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack") > GetGameTime())
			return false;
		
		int droppedWeapon = this.GetDroppedWeaponInRange();
		if (droppedWeapon != -1 && !CBaseEntity(droppedWeapon).IsEFlagSet(EFL_KILLME))
		{
			if (SDKCall_CTFPlayer_PickupWeaponFromOther(this.index, droppedWeapon))
			{
				RemoveEntity(droppedWeapon);
				return true;
			}
		}

		return false;
	}

	public int GetDroppedWeaponInRange()
	{
		float vecEyePosition[3], vecEyeAngles[3], vecForward[3];
		GetClientEyePosition(this.index, vecEyePosition);
		GetClientEyeAngles(this.index, vecEyeAngles);
		GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
		
		float vecEnd[3];
		ScaleVector(vecForward, TF_WEAPON_PICKUP_RANGE);
		AddVectors(vecEyePosition, vecForward, vecEnd);
		
		TR_TraceRayFilter(vecEyePosition, vecEnd, MASK_SOLID | CONTENTS_DEBRIS, RayType_EndPoint, TraceEntityFilter_IgnorePlayer, this.index);
		
		int droppedWeapon = TR_GetEntityIndex();
		if (droppedWeapon == -1 || !FClassnameIs(droppedWeapon, "tf_dropped_weapon"))
			return -1;
		
		if (!this.CanPickupDroppedWeapon(droppedWeapon))
			return -1;
		
		float vecWeaponOrigin[3];
		GetEntPropVector(droppedWeapon, Prop_Data, "m_vecOrigin", vecWeaponOrigin);
		
		// too far?
		if (GetVectorDistance(vecEyePosition, vecWeaponOrigin) > TF_WEAPON_PICKUP_RANGE)
			return -1;
		
		return droppedWeapon;
	}

	// TODO complete this impl
	public bool CanPickupDroppedWeapon(int weapon)
	{
		int iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_Item");
		if (iItemDefinitionIndex == INVALID_ITEM_DEF_INDEX)
			return false;
		
		TFClassType playerClass = TF2_GetPlayerClass(this.index);
		if (playerClass == TFClass_Spy && (TF2_IsPlayerInCondition(this.index, TFCond_Stealthed) || this.GetPercentInvisible() > 0.0))
			return false;
		
		if (TF2_IsPlayerInCondition(this.index, TFCond_Taunting))
			return false;
		
		if (!IsPlayerAlive(this.index))
			return false;
		
		int activeWeapon = GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon");
		if (activeWeapon == -1 || !SDKCall_CTFWeaponBase_CanPickupOtherWeapon(activeWeapon))
			return false;
		
		int iItemSlot = TF2Econ_GetItemLoadoutSlot(iItemDefinitionIndex, playerClass);

		// Only allow to pick up our own class weapons
		return iItemSlot != -1;
	}

	public float GetPercentInvisible()
	{
		int offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
		return GetEntDataFloat(this.index, offset);
	}

	public void Init()
	{
		this.m_bIsParachuting = false;
		this.m_flLastMedigunDrainTime = -1.0;
		this.m_iOpeningCrate = INVALID_ENT_REFERENCE;
		this.m_hWearableVM = INVALID_ENT_REFERENCE;
		this.SetPlayerState(FRPlayerState_Waiting);
	}
}

static bool TraceEntityFilter_IgnorePlayer(int entity, int contentsMask, any data)
{
	return entity != data;
}
