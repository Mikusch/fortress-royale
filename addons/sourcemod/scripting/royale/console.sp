void Console_Init()
{
	AddCommandListener(Console_JoinTeam, "jointeam");
	AddCommandListener(Console_JoinTeam, "autoteam");
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
	return Plugin_Handled;
}