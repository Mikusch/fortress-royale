/*
 * Copyright (C) 2020  Mikusch & 42
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

enum struct ConsoleInfo
{
	CommandListener callback;
	char command[64];
}

static ArrayList g_ConsoleInfo;

void Console_Init()
{
	g_ConsoleInfo = new ArrayList(sizeof(ConsoleInfo));
	
	Console_Add(Console_JoinTeam, "jointeam");
	Console_Add(Console_JoinTeam, "autoteam");
	Console_Add(Console_JoinTeam, "spectate");
	Console_Add(Console_Build, "build");
	Console_Add(Console_Destroy, "destroy");
	Console_Add(Console_VoiceMenu, "voicemenu");
	Console_Add(Console_DropItem, "dropitem");
	Console_Add(Console_EurekaTeleport, "eureka_teleport");
}

void Console_Add(CommandListener callback, const char[] command)
{
	ConsoleInfo info;
	info.callback = callback;
	strcopy(info.command, sizeof(info.command), command);
	g_ConsoleInfo.PushArray(info);
}

void Console_Enable()
{
	int length = g_ConsoleInfo.Length;
	for (int i = 0; i < length; i++)
	{
		ConsoleInfo info;
		g_ConsoleInfo.GetArray(i, info);
		AddCommandListener(info.callback, info.command);
	}
}

void Console_Disable()
{
	int length = g_ConsoleInfo.Length;
	for (int i = 0; i < length; i++)
	{
		ConsoleInfo info;
		g_ConsoleInfo.GetArray(i, info);
		RemoveCommandListener(info.callback, info.command);
	}
}

public Action Console_JoinTeam(int client, const char[] command, int args)
{
	//Client's view entity is set to the bus, prevent switching teams
	if (FRPlayer(client).PlayerState == PlayerState_BattleBus)
		return Plugin_Handled;
	
	//Allow join spectator
	if (StrContains(command, "spectate") == 0)
	{
		FRPlayer(client).PlayerState = PlayerState_Waiting;
		return Plugin_Continue;
	}
	
	if (args > 0 && StrContains(command, "jointeam") == 0)
	{
		char team[16];
		GetCmdArg(1, team, sizeof(team));
		if (StrContains(team, "spectate") == 0)
		{
			FRPlayer(client).PlayerState = PlayerState_Waiting;
			return Plugin_Continue;
		}
	}
	
	if (!GameRules_GetProp("m_bInWaitingForPlayers") && IsPlayerAlive(client))
		return Plugin_Handled;
	
	//Force set client to dead team
	TF2_ChangeClientTeam(client, TFTeam_Dead);
	ShowVGUIPanel(client, TF2_GetClientTeam(client) == TFTeam_Blue ? "class_blue" : "class_red");
	return Plugin_Handled;
}

public Action Console_Build(int client, const char[] command, int args)
{
	// Check if player owns Construction PDA
	if (TF2_GetItemByClassname(client, "tf_weapon_pda_engineer_build") != INVALID_ENT_REFERENCE)
		return Plugin_Continue;
	
	// Block build by default
	return Plugin_Handled;
}

public Action Console_Destroy(int client, const char[] command, int args)
{
	// Check if player owns Destruction PDA
	if (TF2_GetItemByClassname(client, "tf_weapon_pda_engineer_destroy") != INVALID_ENT_REFERENCE)
		return Plugin_Continue;
	
	// Block destroy by default
	return Plugin_Handled;
}

public Action Console_VoiceMenu(int client, const char[] command, int args)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || args < 2)
		return Plugin_Continue;
	
	char arg1[2];
	char arg2[2];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if (arg1[0] == '0' && arg2[0] == '0')	//MEDIC!
	{
		if (TF2_TryToPickupDroppedWeapon(client))
			return Plugin_Handled;
		
		FRPlayer(client).InUse = true;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Console_DropItem(int client, const char[] command, int args)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return Plugin_Continue;
	
	if (!IsPlayerAlive(client))
		return Plugin_Continue;
	
	//Drop weapon, if player doesn't have a rune to drop instead
	for (int i = 0; i < sizeof(g_RuneConds); i++)
		if (TF2_IsPlayerInCondition(client, g_RuneConds[i]))
			return Plugin_Continue;
	
	//Drop item if the player has one
	if (GetEntPropEnt(client, Prop_Send, "m_hItem") != -1)
		return Plugin_Continue;
	
	//The following will be dropped (in that order):
	//- current active weapon
	//- wearables (can't be used as active weapon)
	//- weapons that can't be switched to (as determined by TF2)
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	bool found = weapon != -1 && TF2_ShouldDropWeapon(client, weapon);
	
	if (!found)
	{
		for (int slot = WeaponSlot_Primary; slot < WeaponSlot_BuilderEngie; slot++)
		{
			weapon = SDKCall_GetEquippedWearableForLoadoutSlot(client, slot);
			if (weapon != -1 && TF2_ShouldDropWeapon(client, weapon))
			{
				found = true;
				break;
			}
		}
	}
	
	if (!found)
	{
		for (int slot = WeaponSlot_Primary; slot < WeaponSlot_BuilderEngie; slot++)
		{
			weapon = GetPlayerWeaponSlot(client, slot);
			if (weapon != -1 && TF2_ShouldDropWeapon(client, weapon) && !SDKCall_WeaponCanSwitchTo(client, weapon))
			{
				found = true;
				break;
			}
		}
	}
	
	if (!found)	//No valid weapons to drop
		return Plugin_Continue;
	
	float origin[3], angles[3];
	if (SDKCall_CalculateAmmoPackPositionAndAngles(client, weapon, origin, angles))
	{
		TF2_CreateDroppedWeapon(client, weapon, true, origin, angles);
		TF2_RemoveItem(client, weapon);
		
		int melee = TF2_GetItemInSlot(client, WeaponSlot_Melee);
		if (melee == -1)	//Dropped melee weapon, give fists back
		{
			melee = TF2_CreateWeapon(INDEX_FISTS, g_FistsClassnames[TF2_GetPlayerClass(client)]);
			if (melee != -1)
				TF2_EquipWeapon(client, melee);
		}
		
		//Set new active weapon to melee
		if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == -1)
			TF2_SwitchActiveWeapon(client, melee);
		
		FRPlayer(client).LastWeaponPickupTime = GetGameTime();
		
		CreateTimer(0.1, Timer_UpdateClientHud, GetClientSerial(client));
	}
	
	return Plugin_Continue;
}

public Action Console_EurekaTeleport(int client, const char[] command, int args)
{
	//Prevent home teleport
	
	//No arg teleports home by default
	if (args != 1)
		return Plugin_Handled;
	
	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));
	if (StringToInt(arg) == view_as<int>(EUREKA_TELEPORT_HOME))
		return Plugin_Handled;
	
	return Plugin_Continue;
}