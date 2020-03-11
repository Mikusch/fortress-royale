static StringMap g_LootTypeMap;
static ArrayList g_SpawnedCrates;

public void Loot_Init()
{
	g_SpawnedCrates = new ArrayList(2);
	g_LootTypeMap = new StringMap();
	g_LootTypeMap.SetValue("ALL", LOOT_ALL);
	g_LootTypeMap.SetValue("WEAPON_ALL", LOOT_WEAPONS);
	g_LootTypeMap.SetValue("PICKUP_ALL", LOOT_PICKUPS);
	g_LootTypeMap.SetValue("POWERUP_ALL", LOOT_POWERUPS);
	g_LootTypeMap.SetValue("WEAPON_PRIMARY", Loot_Weapon_Primary);
	g_LootTypeMap.SetValue("WEAPON_SECONDARY", Loot_Weapon_Secondary);
	g_LootTypeMap.SetValue("WEAPON_MELEE", Loot_Weapon_Melee);
	g_LootTypeMap.SetValue("WEAPON_MISC", Loot_Weapon_Misc);
	g_LootTypeMap.SetValue("PICKUP_HEALTH", Loot_Pickup_Health);
	g_LootTypeMap.SetValue("PICKUP_AMMO", Loot_Pickup_Ammo);
	g_LootTypeMap.SetValue("PICKUP_SPELL", Loot_Pickup_Spell);
	g_LootTypeMap.SetValue("POWERUP_CRITS", Loot_Powerup_Crits);
	g_LootTypeMap.SetValue("POWERUP_UBER", Loot_Powerup_Uber);
	g_LootTypeMap.SetValue("POWERUP_RUNE", Loot_Powerup_Rune);
}

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

stock LootType Loot_StrToLootType(const char[] str)
{
	LootType type;
	
	char parts[32][PLATFORM_MAX_PATH];
	if (ExplodeString(str, "|", parts, sizeof(parts), sizeof(parts[])) > 0)
	{
		for (int i = 0; i < sizeof(parts); i++)
		{
			TrimString(parts[i]);
			LootType temp;
			g_LootTypeMap.GetValue(parts[i], temp);
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
		EmitSoundToAll(lootCrate.sound, caller);
		
		LootConfig loot;
		if (g_LootTable.GetRandomLoot(loot, lootCrate.GetRandomLootType()) > 0)
		{
			//Start function call to loot creation function
			Call_StartFunction(null, loot.callback);
			Call_PushCell(activator);
			Call_PushCell(loot.callbackParams);
			
			int entity;
			if (Call_Finish(entity) == SP_ERROR_NONE && entity > MaxClients)
			{
				float origin[3], angles[3], velocity[3];
				GetEntPropVector(caller, Prop_Data, "m_vecOrigin", origin);
				GetEntPropVector(caller, Prop_Data, "m_angRotation", angles);
				GetEntPropVector(caller, Prop_Data, "m_vecVelocity", velocity);
				TeleportEntity(entity, origin, angles, velocity);
			}
		}
	}
}
