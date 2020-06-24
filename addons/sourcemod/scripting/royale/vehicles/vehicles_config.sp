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
	g_VehiclesDefault.entity = INVALID_ENT_REFERENCE;
	
	int length = g_VehiclesPrefabs.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesPrefabs.GetArray(i, vehicle);
		vehicle.Delete();
	}
	
	g_VehiclesPrefabs.Clear();
	
	length = g_VehiclesConfig.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesConfig.GetArray(i, vehicle);
		vehicle.Delete();
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
		//Read through every Vehicles
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
		//Read through every Vehicles
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				Vehicle vehicle;
				
				//Attempt use prefab, otherwise use default
				kv.GetString("prefab", vehicle.name, sizeof(vehicle.name));
				if (!VehiclesConfig_GetByName(vehicle.name, vehicle))
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

bool VehiclesConfig_GetByName(const char[] name, Vehicle buffer)
{
	int length = g_VehiclesPrefabs.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesPrefabs.GetArray(i, vehicle);
		
		if (StrEqual(vehicle.name, name, false))
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

void VehiclesConfig_SetVehicle(int pos, Vehicle vehicle)
{
	g_VehiclesConfig.SetArray(pos, vehicle);
}

void VehiclesConfig_AddVehicle(Vehicle vehicle)
{
	g_VehiclesConfig.PushArray(vehicle);
}

void VehiclesConfig_DeleteByEntity(int entity)
{
	int pos = g_VehiclesConfig.FindValue(entity, Vehicle::entity);
	if (pos >= 0)
		g_VehiclesConfig.Erase(pos);
}

void VehiclesConfig_GetDefault(Vehicle vehicle)
{
	vehicle = g_VehiclesDefault;
}