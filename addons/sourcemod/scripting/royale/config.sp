static LootCrateConfig g_lootDefault;

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
				lootCrate = g_lootDefault;
				
				//Must have a name for prefab
				kv.GetString("name", lootCrate.namePrefab, CONFIG_MAXCHAR);
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

static LootPrefabsConfig g_lootPrefabs;

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
				kv.GetString("prefab", lootCrate.namePrefab, CONFIG_MAXCHAR);
				if (!g_lootPrefabs.FindPrefab(lootCrate.namePrefab, lootCrate))
					lootCrate = g_lootDefault;
				
				lootCrate.ReadConfig(kv);
				this.PushArray(lootCrate);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

static LootCratesConfig g_lootCrates;

void Config_Init()
{
	g_lootPrefabs = new LootPrefabsConfig();
	g_lootCrates = new LootCratesConfig();
}

void Config_Refresh()
{
	g_lootPrefabs.Clear();
	
	//Load 'global.cfg' for all maps
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/global.cfg");
	
	KeyValues kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		if (kv.JumpToKey("BattleBus", false))
		{
			g_CurrentBattleBusConfig.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootDefault", false))
		{
			g_lootDefault.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootPrefabs", false))
		{
			g_lootPrefabs.ReadConfig(kv);
			kv.GoBack();
		}
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
			g_CurrentBattleBusConfig.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootDefault", false))
		{
			g_lootDefault.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootPrefabs", false))
		{
			g_lootPrefabs.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootCrates", false))
		{
			g_lootCrates.ReadConfig(kv);
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
	if (pos < 0 || pos >= g_lootCrates.Length)
		return false;
	
	g_lootCrates.GetArray(pos, lootCrate);
	return true;
}