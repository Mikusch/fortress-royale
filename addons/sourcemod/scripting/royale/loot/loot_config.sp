static LootCrate g_LootCrateDefault;	//Default loot crate
static LootCrate g_LootCrateBus;		//Bus loot crate

methodmap LootPrefabs < ArrayList
{
	public LootPrefabs()
	{
		return view_as<LootPrefabs>(new ArrayList(sizeof(LootCrate)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every prefabs
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrate loot;
				loot = g_LootCrateDefault;
				
				//Must have a name for prefab
				kv.GetString("name", loot.namePrefab, sizeof(loot.namePrefab));
				if (!loot.namePrefab[0])
				{
					LogError("Found prefab with missing 'name' key");
					continue;
				}
				
				loot.ReadConfig(kv);
				this.PushArray(loot);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
	
	public bool FindPrefab(const char[] name, LootCrate lootBuffer)
	{
		int length = this.Length;
		for (int i = 0; i < length; i++)
		{
			LootCrate Loot;
			this.GetArray(i, Loot);
			
			if (StrEqual(Loot.namePrefab, name, false))
			{
				lootBuffer = Loot;
				return true;
			}
		}
		
		return false;
	}
}

static LootPrefabs g_LootPrefabs;		//All prefabs to copy

methodmap LootConfig < ArrayList
{
	public LootConfig()
	{
		return view_as<LootConfig>(new ArrayList(sizeof(LootCrate)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every crates
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrate loot;
				
				//Attempt use prefab, otherwise use default
				kv.GetString("prefab", loot.namePrefab, sizeof(loot.namePrefab));
				if (!g_LootPrefabs.FindPrefab(loot.namePrefab, loot))
					loot = g_LootCrateDefault;
				
				loot.ReadConfig(kv);
				this.PushArray(loot);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public void SetConfig(KeyValues kv)
	{
		int length = this.Length;
		for (int configIndex = 0; configIndex < length; configIndex++)
		{
			LootCrate loot;
			this.GetArray(configIndex, loot);
			
			kv.JumpToKey("322", true);	//Just so we can create new key without jumping to existing Loot
			kv.SetSectionName("LootCrate");
			loot.SetConfig(kv);
			kv.GoBack();
		}
	}
}

static LootConfig g_LootConfig;			//All loot crates from config

void LootConfig_Init()
{
	g_LootPrefabs = new LootPrefabs();
	g_LootConfig = new LootConfig();
	
	g_LootCrateDefault.entity = INVALID_ENT_REFERENCE;
}

void LootConfig_Clear()
{
	g_LootPrefabs.Clear();
	g_LootConfig.Clear();
}

void LootConfig_ReadConfig(KeyValues kv)
{
	if (kv.JumpToKey("LootDefault", false))
	{
		g_LootCrateDefault.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("LootBus", false))
	{
		g_LootCrateBus = g_LootCrateDefault;
		g_LootCrateBus.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("LootPrefabs", false))
	{
		g_LootPrefabs.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("LootCrates", false))
	{
		g_LootConfig.ReadConfig(kv);
		kv.GoBack();
	}
}

void LootConfig_Save()
{
	char filePath[PLATFORM_MAX_PATH];
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	
	KeyValues kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		kv.JumpToKey("LootCrates", true);
		
		//Delete all Loot in config and create new one
		while (kv.DeleteKey("LootCrate")) {}
		
		g_LootConfig.SetConfig(kv);
		kv.GoBack();
		
		kv.ExportToFile(filePath);
	}
	
	delete kv;
}

int LootConfig_AddCrate(LootCrate loot)
{
	g_LootConfig.PushArray(loot);
	return g_LootConfig.Length - 1;
}

void LootConfig_SetCrate(int pos, LootCrate loot)
{
	g_LootConfig.SetArray(pos, loot);
}

bool LootConfig_GetCrate(int pos, LootCrate loot)
{
	if (pos < 0 || pos >= g_LootConfig.Length)
		return false;
	
	g_LootConfig.GetArray(pos, loot);
	return true;
}

int LootConfig_GetCrateByEntity(int entity, LootCrate loot)
{
	int pos = g_LootConfig.FindValue(entity, LootCrate::entity);
	if (pos == -1)
		return -1;
	
	g_LootConfig.GetArray(pos, loot);
	return pos;
}

void LootConfig_DeleteCrateByEntity(int entity)
{
	int pos = g_LootConfig.FindValue(entity, LootCrate::entity);
	if (pos >= 0)
		g_LootConfig.Erase(pos);
}

bool LootConfig_GetPrefab(int pos, LootCrate loot)
{
	if (pos < 0 || pos >= g_LootPrefabs.Length)
		return false;
	
	g_LootPrefabs.GetArray(pos, loot);
	return true;
}

bool LootConfig_GetPrefabByName(const char[] name, LootCrate loot)
{
	return g_LootPrefabs.FindPrefab(name, loot);
}

void LootCrate_GetDefault(LootCrate loot)
{
	loot = g_LootCrateDefault;
}

void LootCrate_GetBus(LootCrate loot)
{
	loot = g_LootCrateBus;
}