void Console_Init()
{
	AddCommandListener(Console_JoinTeam, "jointeam");
	AddCommandListener(Console_JoinTeam, "autoteam");
	AddCommandListener(Console_Build, "build");
	AddCommandListener(Console_Destroy, "destroy");
	AddCommandListener(Console_VoiceMenu, "voicemenu");
	AddCommandListener(Console_DropItem, "dropitem");
	AddCommandListener(Console_EurekaTeleport, "eureka_teleport");
}

public Action Console_JoinTeam(int client, const char[] command, int args)
{
	//Allow join spectator
	if (args > 0 && StrContains(command, "jointeam") == 0)
	{
		char team[16];
		GetCmdArg(1, team, sizeof(team));
		if (StrContains(team, "spectate") == 0)
			return Plugin_Continue;
	}
	
	if (IsPlayerAlive(client))
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
	
	if (arg1[0] == '0' && arg2[0] == '0')
	{
		if (FRPlayer(client).LastWeaponPickupTime < GetGameTime() - 1.0)
			SDKCall_TryToPickupDroppedWeapon(client);
		
		//Entering and exiting vehicles
		if (FRPlayer(client).LastVehicleEnterTime < GetGameTime() - 1.0)
		{
			Vehicle vehicle;
			if (Vehicles_GetByClient(client, vehicle))
				Vehicles_ExitVehicle(client);
			else
				Vehicles_TryToEnterVehicle(client);
		}
	}
	
	return Plugin_Continue;
}

public Action Console_DropItem(int client, const char[] command, int args)
{
	if (!IsPlayerAlive(client))
		return Plugin_Continue;
	
	//Drop weapon, if player dont have rune to drop instead
	for (int i = 0; i < sizeof(g_runeConds); i++)
		if (TF2_IsPlayerInCondition(client, g_runeConds[i]))
			return Plugin_Continue;
	
	//Order on which weapons to drop if valid:
	//- current active weapon
	//- wearables (can't be used as active weapon)
	//- weapons (can't be used as active weapon if ammo is empty)
	
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
			if (weapon != -1 && TF2_ShouldDropWeapon(client, weapon))
			{
				found = true;
				break;
			}
		}
	}
	
	if (!found)	//No valid weapons to drop
		return Plugin_Continue;
	
	float origin[3], angles[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	
	TF2_CreateDroppedWeapon(client, weapon, true, origin, angles);
	TF2_RemoveItem(client, weapon);
	
	int melee = TF2_GetItemInSlot(client, WeaponSlot_Melee);
	if (melee == -1)	//Dropped melee weapon, give fists back
	{
		melee = TF2_CreateWeapon(INDEX_FISTS, g_fistsClassname[TF2_GetPlayerClass(client)]);
		if (melee != -1)
			TF2_EquipWeapon(client, melee);
	}
	
	//Set new active weapon to melee
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == -1)
		TF2_SwitchActiveWeapon(client, melee);
	
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