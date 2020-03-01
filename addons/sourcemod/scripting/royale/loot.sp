/**
 * Possible drops from loot crates
 */
enum LootType
{
	Loot_Weapon_Primary = (1<<0),	/**< Primary weapons */
	Loot_Weapon_Secondary = (1<<1),	/**< Secondary weapons */
	Loot_Weapon_Melee = (1<<2),		/**< Melee weapons */
	Loot_Weapon_Misc = (1<<3),		/**< Grappling Hook, PDA, etc. */
	Loot_Pickup_Health = (1<<4),	/**< Health pickups */
	Loot_Pickup_Ammo = (1<<5),		/**< Ammunition pickups */
	Loot_Pickup_Spell = (1<<6),		/**< Halloween spells */
	Loot_Powerup_Crits = (1<<7),	/**< Mannpower crit powerup */
	Loot_Powerup_Uber = (1<<8),		/**< Mannpower uber powerup */
	Loot_Powerup_Rune = (1<<9)		/**< Mannpower rune powerup */
}

/** Everything */
#define LOOT_ALL		view_as<LootType>(0xFFFFFFFF)
/** Any weapon */
#define LOOT_WEAPONS	Loot_Weapon_Primary|Loot_Weapon_Secondary|Loot_Weapon_Melee|Loot_Weapon_Misc
/** Health, ammo and spells */
#define LOOT_PICKUPS	Loot_Pickup_Health|Loot_Pickup_Ammo|Loot_Pickup_Spell
/** Mannpower powerups */
#define LOOT_POWERUPS	Loot_Powerup_Crits|Loot_Powerup_Uber|Loot_Powerup_Rune

/**
 * Weapon information from configuration
 */
enum struct LootCrateWeapon
{
	int defindex;
	int chance;
}

public void Loot_SpawnCratesInWorld()
{
	for (int i = 0; i < g_CurrentLootCrateConfig.Length; i++)
	{
		LootCrateConfig config;
		g_CurrentLootCrateConfig.GetArray(i, config, sizeof(config));
		Loot_SpawnCrateInWorld(config)
	}
}

public void Loot_SpawnCrateInWorld(LootCrateConfig config)
{
	if (GetRandomFloat() <= config.chance)
	{
		int crate = CreateEntityByName("prop_dynamic_override");
		if (IsValidEntity(crate))
		{
			DispatchKeyValue(crate, "solid", "6");
			SetEntityModel(crate, config.model);
			SetEntProp(crate, Prop_Data, "m_nSkin", config.skin);
			SetEntProp(crate, Prop_Data, "m_iHealth", config.health);
			
			if (DispatchSpawn(crate))
			{
				TeleportEntity(crate, config.origin, config.angles, NULL_VECTOR);
				HookSingleEntityOutput(crate, "OnBreak", EntityOutput_OnBreak, true);
			}
		}
	}
}

public LootType Loot_StringToLootType(const char str[PLATFORM_MAX_PATH])
{
	LootType type;
	
	char parts[32][PLATFORM_MAX_PATH];
	if (ExplodeString(str, "|", parts, sizeof(parts), sizeof(parts[])) > 0)
	{
		for (int i = 0; i < sizeof(parts); i++)
		{
			TrimString(parts[i]);
			
			if (StrEqual(parts[i], "ALL"))
				type |= LOOT_ALL;
			else if (StrEqual(parts[i], "WEAPON_ALL"))
				type |= LOOT_WEAPONS;
			else if (StrEqual(parts[i], "PICKUP_ALL"))
				type |= LOOT_PICKUPS;
			else if (StrEqual(parts[i], "POWERUP_ALL"))
				type |= LOOT_POWERUPS;
			else if (StrEqual(parts[i], "WEAPON_PRIMARY"))
				type |= Loot_Weapon_Primary;
			else if (StrEqual(parts[i], "WEAPON_SECONDARY"))
				type |= Loot_Weapon_Secondary;
			else if (StrEqual(parts[i], "WEAPON_MELEE"))
				type |= Loot_Weapon_Melee;
			else if (StrEqual(parts[i], "WEAPON_MISC"))
				type |= Loot_Weapon_Misc;
			else if (StrEqual(parts[i], "PICKUP_HEALTH"))
				type |= Loot_Pickup_Health;
			else if (StrEqual(parts[i], "PICKUP_AMMO"))
				type |= Loot_Pickup_Ammo;
			else if (StrEqual(parts[i], "PICKUP_SPELL"))
				type |= Loot_Pickup_Spell;
			else if (StrEqual(parts[i], "POWERUP_CRITS"))
				type |= Loot_Powerup_Crits;
			else if (StrEqual(parts[i], "POWERUP_UBER"))
				type |= Loot_Powerup_Uber;
			else if (StrEqual(parts[i], "POWERUP_RUNE"))
				type |= Loot_Powerup_Rune;
		}
	}
	
	return type;
}

public Action EntityOutput_OnBreak(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("Crate was broken!");
	
	// TODO: Fetch config for this crate
	// EmitSoundToAll(config.sound, caller);
	// TODO: Spawn loot
}
