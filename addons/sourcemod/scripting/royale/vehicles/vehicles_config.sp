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

enum struct VehicleConfig
{
	/**< Info for each prefab config */
	char name[CONFIG_MAXCHAR];				/**< Name of vehicle */
	char model[PLATFORM_MAX_PATH];			/**< Vehicle model */
	int skin;								/**< Model skin */
	char vehiclescript[PLATFORM_MAX_PATH];	/**< Vehicle script path */
	VehicleType type;						/**< The type of vehicle */
	float minimum_speed_to_enter_exit;		/**< Minimum speed before entering and exiting is disallowed */
	
	/**< Info for each entity placed by map config */
	int entity;						/**< Entity index for editor */
	char origin[CONFIG_MAXCHAR];	/**< Positon to spawn entity in world */
	char angles[CONFIG_MAXCHAR];	/**< Angles to spawn entity in world */
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("name", this.name, CONFIG_MAXCHAR, this.name);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		this.skin = kv.GetNum("skin", this.skin);
		kv.GetString("vehiclescript", this.vehiclescript, PLATFORM_MAX_PATH, this.vehiclescript);
		
		char type[CONFIG_MAXCHAR];
		kv.GetString("type", type, sizeof(type));
		if (StrEqual(type, "car_wheels"))
			this.type = VEHICLE_TYPE_CAR_WHEELS;
		else if (StrEqual(type, "car_raycast"))
			this.type = VEHICLE_TYPE_JETSKI_RAYCAST;
		else if (StrEqual(type, "jetski_raycast"))
			this.type = VEHICLE_TYPE_JETSKI_RAYCAST;
		else if (StrEqual(type, "airboat_raycast"))
			this.type = VEHICLE_TYPE_AIRBOAT_RAYCAST;
		else if (type[0] != '\0')
			LogError("Invalid vehicle type '%s'", type);
		
		this.minimum_speed_to_enter_exit = kv.GetFloat("minimum_speed_to_enter_exit", this.minimum_speed_to_enter_exit);
		
		this.entity = INVALID_ENT_REFERENCE;
		
		//origin and angles is saved as string so we dont get float precision problem
		kv.GetString("origin", this.origin, CONFIG_MAXCHAR, this.origin);
		kv.GetString("angles", this.angles, CONFIG_MAXCHAR, this.angles);
	}
	
	void SetConfig(KeyValues kv)
	{
		//We only care name, origin and angles to save, for map config
		kv.SetString("name", this.name);
		kv.SetString("origin", this.origin);
		kv.SetString("angles", this.angles);
	}
}

static ArrayList g_VehiclesPrefabs;
static ArrayList g_VehiclesMap;

void VehiclesConfig_Init()
{
	g_VehiclesPrefabs = new ArrayList(sizeof(VehicleConfig));
	g_VehiclesMap = new ArrayList(sizeof(VehicleConfig));
}

void VehiclesConfig_Clear()
{
	g_VehiclesPrefabs.Clear();
	g_VehiclesMap.Clear();
}

void VehiclesConfig_ReadConfig(KeyValues kv)
{
	if (kv.JumpToKey("VehiclePrefabs", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				VehicleConfig config;
				config.ReadConfig(kv);
				g_VehiclesPrefabs.PushArray(config);
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
				VehicleConfig config;
				kv.GetString("name", config.name, sizeof(config.name));
				if (!VehiclesConfig_GetPrefabByName(config.name, config))
				{
					LogError("Unknown vehicle name for prefab '%s'", config.name);
					continue;
				}
				
				config.ReadConfig(kv);
				g_VehiclesMap.PushArray(config);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

void VehiclesConfig_SetConfig(KeyValues kv)
{
	int length = g_VehiclesMap.Length;
	for (int configIndex = 0; configIndex < length; configIndex++)
	{
		VehicleConfig config;
		g_VehiclesMap.GetArray(configIndex, config);
		
		kv.JumpToKey("322", true);	//Just so we can create new key without jumping to existing Loot
		config.SetConfig(kv);
		kv.GoBack();
	}
}

bool VehiclesConfig_GetPrefab(int pos, VehicleConfig buffer)
{
	if (pos < 0 || pos >= g_VehiclesPrefabs.Length)
		return false;
	
	g_VehiclesPrefabs.GetArray(pos, buffer);
	return true;
}

bool VehiclesConfig_GetPrefabByName(const char[] name, VehicleConfig buffer)
{
	int length = g_VehiclesPrefabs.Length;
	for (int i = 0; i < length; i++)
	{
		VehicleConfig config;
		g_VehiclesPrefabs.GetArray(i, config);
		
		if (StrEqual(config.name, name, false))
		{
			buffer = config;
			return true;
		}
	}
	
	return false;
}

void VehiclesConfig_AddMapVehicle(VehicleConfig config)
{
	g_VehiclesMap.PushArray(config);
}

void VehiclesConfig_SetMapVehicle(int pos, VehicleConfig config)
{
	g_VehiclesMap.SetArray(pos, config);
}

bool VehiclesConfig_GetMapVehicle(int pos, VehicleConfig buffer)
{
	if (pos < 0 || pos >= g_VehiclesMap.Length)
		return false;
	
	g_VehiclesMap.GetArray(pos, buffer);
	return true;
}

int VehiclesConfig_GetMapVehicleByEntity(int entity, VehicleConfig buffer)
{
	int pos = g_VehiclesMap.FindValue(entity, VehicleConfig::entity);
	if (pos >= 0)
		g_VehiclesMap.GetArray(pos, buffer);
	
	return pos;
}

bool VehiclesConfig_IsMapVehicle(int entity)
{
	return g_VehiclesMap.FindValue(entity, VehicleConfig::entity) >= 0;
}

void VehiclesConfig_DeleteMapVehicleByEntity(int entity)
{
	int pos = g_VehiclesMap.FindValue(entity, VehicleConfig::entity);
	if (pos >= 0)
		g_VehiclesMap.Erase(pos);
}
