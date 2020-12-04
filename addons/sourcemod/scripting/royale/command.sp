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

void Command_Init()
{
	RegAdminCmd("sm_editor", Command_Editor, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_vehicle", Command_Vehicle, ADMFLAG_CHANGEMAP);
}

public Action Command_Editor(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}

	Editor_Start(client);
	return Plugin_Handled;
}

public Action Command_Vehicle(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		ReplyToCommand(client, "%t", "Command_VehicleUsage");
		return Plugin_Handled;
	}
	
	char name[CONFIG_MAXCHAR];
	GetCmdArgString(name, sizeof(name));
	
	VehicleConfig config;
	if (!VehiclesConfig_GetPrefabByTargetname(name, config))
	{
		ReplyToCommand(client, "%t", "Command_VehicleCantFindName", name);
		return Plugin_Handled;
	}
	
	Vehicles_CreateEntityAtCrosshair(config, client);
	return Plugin_Handled;
}