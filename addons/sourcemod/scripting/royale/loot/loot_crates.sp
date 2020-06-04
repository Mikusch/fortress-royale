enum struct LootCrate
{
	int entity; 					/**< Entity crate ref */
	char namePrefab[CONFIG_MAXCHAR];/**< Name of prefab if any */
	
	// Loots
	float origin[3];				/**< Spawn origin */
	float angles[3];				/**< Spawn angles */
	
	// LootDefault/LootBus/LootPrefabs
	char model[PLATFORM_MAX_PATH];	/**< World model */
	int skin;						/**< Model skin */
	char sound[PLATFORM_MAX_PATH];	/**< Sound this crate emits when opening */
	int health;						/**< Amount of damage required to open */
	ArrayList contents;				/**< ArrayList of contents bitflags to select at random */
	
	// LootBus
	float mass;						/**< Crate mass */
	float impact;					/**< Amount of impact when damages */
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetVector("origin", this.origin, this.origin);
		kv.GetVector("angles", this.angles, this.angles);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		this.skin = kv.GetNum("skin", this.skin);
		kv.GetString("sound", this.sound, PLATFORM_MAX_PATH, this.sound);
		PrecacheSound(this.sound);
		this.health = kv.GetNum("health", this.health);
		
		if (kv.JumpToKey("contents", false))
		{
			this.contents = new ArrayList();
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char type[PLATFORM_MAX_PATH];
					kv.GetString("type", type, sizeof(type));
					
					ArrayList types = Loot_StrToLootTypes(type);
					int frequency = kv.GetNum("frequency", 1);
					
					for (int i = 0; i < types.Length; i++)
					{
						LootType lootType = types.Get(i);
						for (int j = 0; j < frequency; j++)
							this.contents.Push(lootType);
					}
					
					delete types;
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
		
		this.mass = kv.GetFloat("mass", this.mass);
		this.impact = kv.GetFloat("impact", this.impact);
	}
	
	void SetConfig(KeyValues kv)
	{
		//We only care prefab, origin and angles to save to "Loot" section, for now
		kv.SetString("prefab", this.namePrefab);
		kv.SetVector("origin", this.origin);
		kv.SetVector("angles", this.angles);
	}
	
	LootType GetRandomLootType()
	{
		return this.contents.Get(GetRandomInt(0, this.contents.Length - 1));
	}
}