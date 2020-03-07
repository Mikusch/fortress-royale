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

methodmap CallbackParams < StringMap
{
	public CallbackParams()
	{
		return view_as<CallbackParams>(new StringMap());
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char key[CONFIG_MAXCHAR], value[CONFIG_MAXCHAR];
				kv.GetString("key", key, sizeof(key));
				kv.GetString("value", value, sizeof(value));
				this.SetString(key, value);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public bool GetBool(const char[] key, bool defValue = false)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return view_as<bool>(StringToInt(value));
	}
	
	public int GetInt(const char[] key, int defValue = 0)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToInt(value);
	}
	
	public float GetFloat(const char[] key, float defValue = 0.0)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToFloat(value);
	}
}

typedef LootCreateFunc = function int(CallbackParams params);

enum struct LootConfig
{
	LootType type;
	float chance;
	LootCreateFunc callback;
	CallbackParams callbackParams;
}

methodmap LootConfigs < ArrayList
{
	public LootConfigs()
	{
		return view_as<LootConfigs>(new ArrayList(sizeof(LootConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootConfig lootConfig;
				char type[CONFIG_MAXCHAR];
				kv.GetString("type", type, sizeof(type));
				lootConfig.type = Loot_StringToLootType(type);
				
				lootConfig.chance = kv.GetFloat("chance", 1.0);
				
				char callback[CONFIG_MAXCHAR];
				kv.GetString("callback", callback, sizeof(callback));
				lootConfig.callback = view_as<LootCreateFunc>(GetFunctionByName(null, callback));
				
				if (kv.JumpToKey("params", false))
				{
					lootConfig.callbackParams = new CallbackParams();
					lootConfig.callbackParams.ReadConfig(kv);
				}
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

static LootConfigs g_Loot;

void Config_Init()
{
	g_LootPrefabs = new LootPrefabsConfig();
	g_LootCrates = new LootCratesConfig();
	g_Loot = new LootConfigs();
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
			g_CurrentBattleBusConfig.ReadConfig(kv);
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
	kv = new KeyValues("LootConfig");
	if (kv.ImportFromFile(filePath))
	{
		LootConfigs lootConfigs = new LootConfigs();
		lootConfigs.ReadConfig(kv);
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