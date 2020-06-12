public void Command_Init()
{
	RegAdminCmd("sm_editor", Command_Editor, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_vehicle", Command_Vehicle, ADMFLAG_CHANGEMAP);
}

public Action Command_Editor(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%T", "Command_NotInGame", LANG_SERVER);
		return Plugin_Handled;
	}

	Editor_Start(client);
	return Plugin_Handled;
}

public Action Command_Vehicle(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%T", "Command_NotInGame", LANG_SERVER);
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		ReplyToCommand(client, "%T", "Command_VehicleUsage", LANG_SERVER);
		return Plugin_Handled;
	}
	
	char name[CONFIG_MAXCHAR];
	GetCmdArgString(name, sizeof(name));
	
	Vehicle vehicle;
	if (!VehiclesConfig_GetByName(name, vehicle))
	{
		ReplyToCommand(client, "%T", "Command_VehicleCantFindName", LANG_SERVER, name);
		return Plugin_Handled;
	}
	
	Vehicles_CreateEntityAtCrosshair(vehicle, client);
	return Plugin_Handled;
}
