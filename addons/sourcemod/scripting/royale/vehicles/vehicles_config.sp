static ArrayList g_VehiclesConfig;

void VehiclesConfig_Init()
{
	g_VehiclesConfig = new ArrayList(sizeof(Vehicle));
}

void VehiclesConfig_Clear()
{
	g_VehiclesConfig.Clear();
}

void VehiclesConfig_ReadConfig(KeyValues kv)
{
	if (kv.JumpToKey("Vehicles", false))
	{
		//Read through every Vehicles
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				Vehicle vehicle;
				vehicle.entity = INVALID_ENT_REFERENCE;
				vehicle.ReadConfig(kv);
				g_VehiclesConfig.PushArray(vehicle);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

bool VehiclesConfig_GetByName(const char[] name, Vehicle buffer)
{
	int length = g_VehiclesConfig.Length;
	for (int i = 0; i < length; i++)
	{
		Vehicle vehicle;
		g_VehiclesConfig.GetArray(i, vehicle);
		
		if (StrEqual(vehicle.name, name, false))
		{
			buffer = vehicle;
			return true;
		}
	}
	
	return false;
}