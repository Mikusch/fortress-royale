public void Command_Init()
{
	RegAdminCmd("sm_car", Command_Car, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_editor", Command_Editor, ADMFLAG_CHANGEMAP);
}

public Action Command_Car(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		ReplyToCommand(iClient, "This Command can only be used ingame");
		return Plugin_Handled;
	}

	Vehicles_Create(iClient);
	return Plugin_Handled;
}

public Action Command_Editor(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		ReplyToCommand(iClient, "This Command can only be used ingame");
		return Plugin_Handled;
	}

	Editor_Start(iClient);
	return Plugin_Handled;
}