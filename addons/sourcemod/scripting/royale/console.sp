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
		AddCommandListener(CommandListener_JoinTeam, "jointeam");
		AddCommandListener(CommandListener_JoinTeam, "autoteam");
		AddCommandListener(CommandListener_JoinTeam, "spectate");
		AddCommandListener(CommandListener_Build, "build");
		AddCommandListener(CommandListener_Destroy, "destroy");
	}
	else
	{
		RemoveCommandListener(CommandListener_DropItem, "dropitem");
		RemoveCommandListener(CommandListener_JoinTeam, "jointeam");
		RemoveCommandListener(CommandListener_JoinTeam, "autoteam");
		RemoveCommandListener(CommandListener_JoinTeam, "spectate");
		RemoveCommandListener(CommandListener_Build, "build");
		RemoveCommandListener(CommandListener_Destroy, "destroy");
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
	bool bFound = (weapon != -1) && ShouldDropItem(client, weapon);
	
	if (!bFound)
	{
		for (int iLoadoutSlot = 0; iLoadoutSlot <= LOADOUT_POSITION_PDA2; iLoadoutSlot++)
		{
			weapon = TF2Util_GetPlayerLoadoutEntity(client, iLoadoutSlot);
			if (weapon == -1)
				continue;
			
			if (TF2Util_IsEntityWearable(weapon))
			{
				// Always drop wearables
				bFound = true;
				break;
			}
			else
			{
				if (ShouldDropItem(client, weapon) && !SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(client, weapon))
				{
					bFound = true;
					break;
				}
			}
		}
	}
	
	if (!bFound)
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
	
	char szWorldModel[PLATFORM_MAX_PATH];
	if (GetItemWorldModel(weapon, szWorldModel, sizeof(szWorldModel)))
	{
		int droppedWeapon = CreateDroppedWeapon(vecOrigin, vecAngles, szWorldModel, GetEntityAddress(weapon) + FindItemOffset(weapon));
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
		}
		
		bool bDroppedMelee = TF2Util_GetWeaponSlot(weapon) == TFWeaponSlot_Melee;
		FRPlayer(client).RemoveItem(weapon);
		
		// If we dropped our melee weapon, get our fists back
		if (bDroppedMelee)
		{
			weapon = GenerateDefaultItem(client, TF_DEFINDEX_FISTS);
			if (IsValidEntity(weapon))
			{
				ItemGiveTo(client, weapon);
				TF2Util_SetPlayerActiveWeapon(client, weapon);
			}
		}
	}
	
	return Plugin_Continue;
}

static Action CommandListener_JoinTeam(int client, const char[] command, int argc)
{
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	// Don't allow switching teams while in the bus or in dying state
	if (FRPlayer(client).GetPlayerState() == FRPlayerState_InBattleBus)
		return Plugin_Handled;
	
	// Allow players to join spectator team
	if (StrEqual(command, "spectate", false))
	{
		return Plugin_Continue;
	}
	
	if (argc > 0 && StrEqual(command, "jointeam", false))
	{
		char szTeamName[16];
		GetCmdArg(1, szTeamName, sizeof(szTeamName));
		
		if (StrEqual(szTeamName, "spectate", false) || StrEqual(szTeamName, "blue", false))
		{
			return Plugin_Continue;
		}
	}
	
	FakeClientCommand(client, "jointeam blue");
	return Plugin_Handled;
}

static Action CommandListener_Build(int client, const char[] command, int argc)
{
	int item = TF2Util_GetPlayerLoadoutEntity(client, LOADOUT_POSITION_PDA);
	if (IsValidEntity(item) && TF2Util_IsEntityWeapon(item) && TF2Util_GetWeaponID(item) == TF_WEAPON_PDA_ENGINEER_BUILD)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

static Action CommandListener_Destroy(int client, const char[] command, int argc)
{
	int item = TF2Util_GetPlayerLoadoutEntity(client, LOADOUT_POSITION_PDA);
	if (IsValidEntity(item) && TF2Util_IsEntityWeapon(item) && TF2Util_GetWeaponID(item) == TF_WEAPON_PDA_ENGINEER_DESTROY)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}
