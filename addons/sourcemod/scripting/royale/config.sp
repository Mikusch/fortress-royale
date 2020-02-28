enum struct BattleBusConfig
{
	char model[PLATFORM_MAX_PATH];
	int skin;
	float diameter;
	float time;
	float height;
	float cameraOffset[3];
	float cameraAngles[3];
}

enum struct MapConfig
{
	BattleBusConfig battleBusConfig;
	// TODO: Move LootCrate struct into this (perhaps call it CrateConfig?)
}

public void Config_ReadMapConfig()
{
	char mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char nameParts[2][PLATFORM_MAX_PATH];
	
	//Split map prefix and first part of its name (e.g. pl_hightower)
	ExplodeString(mapName, "_", nameParts, 2, 32);
	
	//Clean up workshop map names
	if (strncmp("workshop/", nameParts[0], 9) == 0)
		ReplaceString(nameParts[0], sizeof(nameParts[]), "workshop/", "");
	else if (strncmp("workshop\\", nameParts[0], 9) == 0)
		ReplaceString(nameParts[0], sizeof(nameParts[]), "workshop\\", "");
	
	//Stitch name parts together
	char tidyMapName[PLATFORM_MAX_PATH];
	Format(tidyMapName, sizeof(tidyMapName), "%s_%s", nameParts[0], nameParts[1]);
	
	//Build file path
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/maps/%s.cfg", tidyMapName);
	
	//Finally, read the config
	KeyValues kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		ReadMapConfig(kv);
	}
	else
	{
		LogError("Configuration file for map %s could not be found at %s", mapName, filePath);
	}
	
	delete kv;
} 

void ReadMapConfig(KeyValues kv)
{
	// TODO: I'm lazy ok :(
}
