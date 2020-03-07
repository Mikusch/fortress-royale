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

static StringMap g_LootTypeMappings;
static ArrayList g_SpawnedCrates;

public void Loot_SpawnCratesInWorld()
{
	int i = 0;
	LootCrateConfig lootCrate;
	while (Config_GetLootCrate(i, lootCrate))
	{
		Loot_SpawnCrateInWorld(lootCrate, i);
		i++;
	}
}

public void Loot_SpawnCrateInWorld(LootCrateConfig config, int i)
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
				SetEntProp(crate, Prop_Data, "m_takedamage", DAMAGE_YES);
				TeleportEntity(crate, config.origin, config.angles, NULL_VECTOR);
				HookSingleEntityOutput(crate, "OnBreak", EntityOutput_OnBreak, true);
				
				int length = g_SpawnedCrates.Length;
				g_SpawnedCrates.Resize(length + 1);
				g_SpawnedCrates.Set(length, EntIndexToEntRef(crate), 0);
				g_SpawnedCrates.Set(length, i, 1);
			}
		}
	}
}

public void Loot_Init()
{
	g_SpawnedCrates = new ArrayList(2);
	g_LootTypeMappings = new StringMap();
	g_LootTypeMappings.SetValue("ALL", LOOT_ALL);
	g_LootTypeMappings.SetValue("WEAPON_ALL", LOOT_WEAPONS);
	g_LootTypeMappings.SetValue("PICKUP_ALL", LOOT_PICKUPS);
	g_LootTypeMappings.SetValue("POWERUP_ALL", LOOT_POWERUPS);
	g_LootTypeMappings.SetValue("WEAPON_PRIMARY", Loot_Weapon_Primary);
	g_LootTypeMappings.SetValue("WEAPON_SECONDARY", Loot_Weapon_Secondary);
	g_LootTypeMappings.SetValue("WEAPON_MELEE", Loot_Weapon_Melee);
	g_LootTypeMappings.SetValue("WEAPON_MISC", Loot_Weapon_Misc);
	g_LootTypeMappings.SetValue("PICKUP_HEALTH", Loot_Pickup_Health);
	g_LootTypeMappings.SetValue("PICKUP_AMMO", Loot_Pickup_Ammo);
	g_LootTypeMappings.SetValue("PICKUP_SPELL", Loot_Pickup_Spell);
	g_LootTypeMappings.SetValue("POWERUP_CRITS", Loot_Powerup_Crits);
	g_LootTypeMappings.SetValue("POWERUP_UBER", Loot_Powerup_Uber);
	g_LootTypeMappings.SetValue("POWERUP_RUNE", Loot_Powerup_Rune);
}

public LootType Loot_StringToLootType(const char[] str)
{
	LootType type;
	
	char parts[32][PLATFORM_MAX_PATH];
	if (ExplodeString(str, "|", parts, sizeof(parts), sizeof(parts[])) > 0)
	{
		for (int i = 0; i < sizeof(parts); i++)
		{
			TrimString(parts[i]);
			LootType temp;
			g_LootTypeMappings.GetValue(parts[i], temp);
			type |= temp;
		}
	}
	
	return type;
}

public Action EntityOutput_OnBreak(const char[] output, int caller, int activator, float delay)
{
	LootCrateConfig lootCrate;
	int i = g_SpawnedCrates.Get(g_SpawnedCrates.FindValue(EntIndexToEntRef(caller), 0), 1);
	if (Config_GetLootCrate(i, lootCrate))
	{
		// TODO: Spawn loot
	}
}
