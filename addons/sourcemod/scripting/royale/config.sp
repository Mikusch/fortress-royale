void Config_Refresh()
{
	g_PrecacheWeapon.Clear();
	LootConfig_Clear();
	VehiclesConfig_Clear();
	
	//Load 'global.cfg' for all maps
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/global.cfg");
	Config_ReadMapConfig(filePath);
	
	//Load map specific config
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	Config_ReadMapConfig(filePath);
	
	//Build filepath for list of loot tables
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/loot.cfg");
	
	//Read the config
	KeyValues kv = new KeyValues("LootTable");
	if (kv.ImportFromFile(filePath))
		LootTable_ReadConfig(kv);
	
	delete kv;
}

void Config_ReadMapConfig(const char[] filePath)
{
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
		
		if (kv.JumpToKey("DownloadsTable", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char download[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, download, sizeof(download));
					AddFileToDownloadsTable(download);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
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

void Config_Save()
{
	char filePath[PLATFORM_MAX_PATH];
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	
	KeyValues kv = new KeyValues("MapConfig");
	kv.ImportFromFile(filePath);
	
	//Delete all Loot and Vehicle in config and create new one
	kv.JumpToKey("LootCrates", true);
	while (kv.DeleteKey("LootCrate")) {}
	LootConfig_SetConfig(kv);
	kv.GoBack();
	
	kv.JumpToKey("Vehicles", true);
	while (kv.DeleteKey("Vehicle")) {}
	VehiclesConfig_SetConfig(kv);
	kv.GoBack();
	
	kv.ExportToFile(filePath);
	
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

bool Config_HasMapFilepath()
{
	char filePath[PLATFORM_MAX_PATH];
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	
	KeyValues kv = new KeyValues("MapConfig");
	bool result = kv.ImportFromFile(filePath);
	delete kv;
	return result;
}