static LootCrateConfig g_LootCratesDefault;

methodmap LootPrefabsConfig < ArrayList
{
	public LootPrefabsConfig()
	{
		return view_as<LootPrefabsConfig>(new ArrayList(sizeof(LootCrateConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every prefabs
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrateConfig lootCrate;
				lootCrate = g_LootCratesDefault;
				
				//Must have a name for prefab
				kv.GetString("name", lootCrate.namePrefab, sizeof(lootCrate.namePrefab));
				if (lootCrate.namePrefab[0] == '\0')
				{
					LogError("Found prefab with missing 'name' key");
					continue;
				}
				
				lootCrate.ReadConfig(kv);
				this.PushArray(lootCrate);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public bool FindPrefab(const char[] name, LootCrateConfig lootBuffer)
	{
		int length = this.Length;
		for (int i = 0; i < length; i++)
		{
			LootCrateConfig lootCrate;
			this.GetArray(i, lootCrate);
			
			if (StrEqual(lootCrate.namePrefab, name))
			{
				lootBuffer = lootCrate;
				return true;
			}
		}
		
		return false;
	}
}

static LootPrefabsConfig g_LootPrefabs;

methodmap LootCratesConfig < ArrayList
{
	public LootCratesConfig()
	{
		return view_as<LootCratesConfig>(new ArrayList(sizeof(LootCrateConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every crates
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrateConfig lootCrate;
				
				//Attempt use prefab, otherwise use default
				kv.GetString("prefab", lootCrate.namePrefab, sizeof(lootCrate.namePrefab));
				if (!g_LootPrefabs.FindPrefab(lootCrate.namePrefab, lootCrate))
					lootCrate = g_LootCratesDefault;
				
				lootCrate.ReadConfig(kv);
				this.PushArray(lootCrate);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

static LootCratesConfig g_LootCrates;

void Config_Init()
{
	g_LootPrefabs = new LootPrefabsConfig();
	g_LootCrates = new LootCratesConfig();
	g_LootTable = new LootTable();
}

void Config_Refresh()
{
	g_LootPrefabs.Clear();
	
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
		
		if (kv.JumpToKey("LootDefault", false))
		{
			g_LootCratesDefault.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootPrefabs", false))
		{
			g_LootPrefabs.ReadConfig(kv);
			kv.GoBack();
		}
	}
	
	//Build file path
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/loot.cfg");
	
	//Finally, read the config
	kv = new KeyValues("LootTable");
	if (kv.ImportFromFile(filePath))
	{
		g_LootTable.ReadConfig(kv);
		kv.GoBack();
	}
	
	//Load map specific configs
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
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/maps/%s.cfg", tidyMapName);
	
	//Finally, read the config
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
		
		if (kv.JumpToKey("LootDefault", false))
		{
			g_LootCratesDefault.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootPrefabs", false))
		{
			g_LootPrefabs.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootCrates", false))
		{
			g_LootCrates.ReadConfig(kv);
			kv.GoBack();
		}
	}
	else
	{
		LogError("Configuration file for map %s could not be found at %s", mapName, filePath);
	}
	
	delete kv;
}

bool Config_GetLootCrate(int pos, LootCrateConfig lootCrate)
{
	if (pos < 0 || pos >= g_LootCrates.Length)
		return false;
	
	g_LootCrates.GetArray(pos, lootCrate);
	return true;
}
