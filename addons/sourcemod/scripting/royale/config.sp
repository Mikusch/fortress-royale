void Config_Refresh()
{
	g_PrecacheWeapon.Clear();
	LootConfig_Clear();
	VehiclesConfig_Clear();
	
	//Load 'global.cfg' for all maps
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/global.cfg");
	
	KeyValues kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		if (kv.JumpToKey("BattleBus", false))
		{
			BattleBus_ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("Zone", false))
		{
			Zone_ReadConfig(kv);
			kv.GoBack();
		}
		
		LootConfig_ReadConfig(kv);
		
		VehiclesConfig_ReadConfig(kv);
	}
	
	delete kv;
	
	//Build filepath for list of loot tables
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/loot.cfg");
	
	//Read the config
	kv = new KeyValues("LootTable");
	if (kv.ImportFromFile(filePath))
		LootTable_ReadConfig(kv);
	
	delete kv;
	
	//Build filepath for vehicles
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/vehicles.cfg");
	
	//Read the config
	kv = new KeyValues("Vehicles");
	if (kv.ImportFromFile(filePath))
		VehiclesConfig_ReadConfig(kv);
	
	delete kv;
	
	//Load map specific configs
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	
	//Read the config
	kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		if (kv.JumpToKey("BattleBus", false))
		{
			BattleBus_ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("Zone", false))
		{
			Zone_ReadConfig(kv);
			kv.GoBack();
		}
		
		LootConfig_ReadConfig(kv);
		VehiclesConfig_ReadConfig(kv);
	}
	else
	{
		LogError("Configuration file for map could not be found at '%s'", filePath);
	}
	
	delete kv;
}

void Confg_GetMapFilepath(char[] filePath, int length)
{
	char mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	GetMapDisplayName(mapName, mapName, sizeof(mapName));
	
	//Split map prefix and first part of its name (e.g. pl_hightower)
	char nameParts[2][PLATFORM_MAX_PATH];
	ExplodeString(mapName, "_", nameParts, sizeof(nameParts), sizeof(nameParts[]));
	
	//Stitch name parts together
	char tidyMapName[PLATFORM_MAX_PATH];
	Format(tidyMapName, sizeof(tidyMapName), "%s_%s", nameParts[0], nameParts[1]);
	
	//Build file path
	BuildPath(Path_SM, filePath, length, "configs/royale/maps/%s.cfg", tidyMapName);
}