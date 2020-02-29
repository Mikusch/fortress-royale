/**
 * Possible drops from loot crates
 */
enum ContentType
{
	ContentType_Weapon_Primary = (1<<0),	/**< Primary weapons */
	ContentType_Weapon_Secondary = (1<<1),	/**< Secondary weapons */
	ContentType_Weapon_Melee = (1<<2),		/**< Melee weapons */
	ContentType_Weapon_Misc = (1<<3),		/**< Grappling Hook, PDA, etc. */
	ContentType_Health = (1<<4),			/**< Health pickups */
	ContentType_Ammo = (1<<5),				/**< Ammunition pickups */
	ContentType_Spell = (1<<6),				/**< Halloween spells */
	ContentType_Powerup_Crits = (1<<7),		/**< Mannpower crit powerup */
	ContentType_Powerup_Uber = (1<<8),		/**< Mannpower uber powerup */
	ContentType_Powerup_Rune = (1<<9)		/**< Mannpower powerups */
}

/** Weapons to be dropped as tf_dropped_weapon entities */
#define CONTENT_TYPE_WEAPONS	ContentType_Weapon_Primary|ContentType_Weapon_Secondary|ContentType_Weapon_Melee|ContentType_Weapon_Misc
/** Entities that can be picked up by walking over them */
#define CONTENT_TYPE_PICKUPS	ContentType_Health|ContentType_Ammo|ContentType_Spell|ContentType_Powerup_Crits|ContentType_Powerup_Uber|ContentType_Powerup_Rune
/** Everything */
#define CONTENT_TYPE_ALL		view_as<ContentType>(0xFFFFFFFF)

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
	int crate = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(crate))
	{
		SetEntityModel(crate, config.model);
		// TODO: Set the rest of the config properties here (Hint: Also need to make crate solid)
		
		if (DispatchSpawn(crate))
		{
			TeleportEntity(crate, config.origin, config.angles, NULL_VECTOR);
			HookSingleEntityOutput(crate, "OnBreak", EntityOutput_OnBreak, true);
		}
	}
}

public Action EntityOutput_OnBreak(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("Crate was broken!");
	
	// TODO: Spawn loot
}
