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

static Vehicle g_VehiclesDefault;
static ArrayList g_VehiclesPrefabs;
static ArrayList g_VehiclesConfig;

void VehiclesConfig_Init()
{
	g_VehiclesPrefabs = new ArrayList(sizeof(Vehicle));
	g_VehiclesConfig = new ArrayList(sizeof(Vehicle));
}

void VehiclesConfig_Clear()
{
	Vehicle nothing;
	g_VehiclesDefault = nothing;
	
	int length = g_VehiclesPrefabs.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesPrefabs.GetArray(i, vehicle);
	}
	
	g_VehiclesPrefabs.Clear();
	
	length = g_VehiclesConfig.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesConfig.GetArray(i, vehicle);
	}
	
	g_VehiclesConfig.Clear();
}

void VehiclesConfig_ReadConfig(KeyValues kv)
{
	if (kv.JumpToKey("VehicleDefault", false))
	{
		g_VehiclesDefault.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("VehiclePrefabs", false))
	{
		//Read through every VehiclePrefab
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				Vehicle vehicle;
				vehicle = g_VehiclesDefault;
				vehicle.ReadConfig(kv);
				g_VehiclesPrefabs.PushArray(vehicle);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	if (kv.JumpToKey("Vehicles", false))
	{
		//Read through every Vehicle
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				Vehicle vehicle;
				
				//Attempt use prefab, otherwise use default
				kv.GetString("targetname", vehicle.targetname, sizeof(vehicle.targetname));
				if (!VehiclesConfig_GetPrefabByTargetname(vehicle.targetname, vehicle))
					vehicle = g_VehiclesDefault;
				
				vehicle.ReadConfig(kv);
				g_VehiclesConfig.PushArray(vehicle);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

void VehiclesConfig_SetConfig(KeyValues kv)
{
	int length = g_VehiclesConfig.Length;
	for (int configIndex = 0; configIndex < length; configIndex++)
	{
		Vehicle vehicle;
		g_VehiclesConfig.GetArray(configIndex, vehicle);
		
		kv.JumpToKey("322", true);	//Just so we can create new key without jumping to existing Loot
		kv.SetSectionName("Vehicle");
		vehicle.SetConfig(kv);
		kv.GoBack();
	}
}

bool VehiclesConfig_GetPrefab(int pos, Vehicle buffer)
{
	if (pos < 0 || pos >= g_VehiclesPrefabs.Length)
		return false;
	
	g_VehiclesPrefabs.GetArray(pos, buffer);
	return true;
}

bool VehiclesConfig_GetPrefabByTargetname(const char[] name, Vehicle buffer)
{
	int length = g_VehiclesPrefabs.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesPrefabs.GetArray(i, vehicle);
		
		if (StrEqual(vehicle.targetname, name, false))
		{
			buffer = vehicle;
			return true;
		}
	}
	
	return false;
}

bool VehiclesConfig_GetVehicle(int pos, Vehicle vehicle)
{
	if (pos < 0 || pos >= g_VehiclesConfig.Length)
		return false;
	
	g_VehiclesConfig.GetArray(pos, vehicle);
	return true;
}

void VehiclesConfig_GetDefault(Vehicle vehicle)
{
	vehicle = g_VehiclesDefault;
}
