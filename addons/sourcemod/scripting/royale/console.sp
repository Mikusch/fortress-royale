void Console_Init()
{
	AddCommandListener(Console_JoinTeam, "jointeam");
	AddCommandListener(Console_JoinTeam, "autoteam");
	AddCommandListener(Console_Build, "build");
	AddCommandListener(Console_Destroy, "destroy");
	AddCommandListener(Console_VoiceMenu, "voicemenu");
	AddCommandListener(Console_EurekaTeleport, "eureka_teleport");
}

public Action Console_JoinTeam(int client, const char[] command, int args)
{
	//Allow join spectator
	if (args > 0 && StrEqual(command, "jointeam"))
	{
		char team[16];
		GetCmdArg(1, team, sizeof(team));
		if (StrEqual(team, "spectate"))
			return Plugin_Continue;
	}
	
	//Otherwise disallow
	if (IsPlayerAlive(client))
		return Plugin_Handled;
	
	TF2_ChangeClientTeam(client, TFTeam_Dead);
	ShowVGUIPanel(client, TF2_GetClientTeam(client) == TFTeam_Blue ? "class_blue" : "class_red");
	
	//Check if there even any red players to fix new round
	TF2_CheckTeamClientCount();
	return Plugin_Handled;
}

public Action Console_Build(int client, const char[] command, int args)
{
	// Check if player owns Construction PDA
	if (TF2_GetItemInSlot(client, WeaponSlot_PDABuild) > MaxClients)
		return Plugin_Continue;
	
	// Block build by default
	return Plugin_Handled;
}

public Action Console_Destroy(int client, const char[] command, int args)
{
	// Check if player owns Destruction PDA
	if (TF2_GetItemInSlot(client, WeaponSlot_PDADestroy) > MaxClients)
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
		SDKCall_TryToPickupDroppedWeapon(client);
	
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