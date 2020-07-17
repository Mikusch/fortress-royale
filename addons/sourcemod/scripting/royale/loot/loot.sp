static StringMap g_LootTypeMap;

void Loot_Init()
{
	g_LootTypeMap = new StringMap();
	g_LootTypeMap.SetValue("weapon", Loot_Weapon);
	g_LootTypeMap.SetValue("item_healthkit", Loot_Item_HealthKit);
	g_LootTypeMap.SetValue("item_ammopack", Loot_Item_AmmoPack);
	g_LootTypeMap.SetValue("spell_pickup", Loot_Pickup_Spell);
	g_LootTypeMap.SetValue("item_powerup", Loot_Item_Powerup);
}

void Loot_SpawnCratesInWorld()
{
	int pos;
	LootCrate loot;
	while (LootConfig_GetCrate(pos, loot))
	{
		if (GetRandomFloat() <= float(GetPlayerCount()) / float(TF_MAXPLAYERS))
		{
			loot.entity = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
			LootConfig_SetCrate(pos, loot);
		}
		
		pos++;
	}
}

int Loot_SpawnCrateInWorld(LootCrate loot, EntityOutput callback, bool physics = false)
{
	int crate = INVALID_ENT_REFERENCE;
	if (physics)
		crate = CreateEntityByName("prop_physics_override");
	else
		crate = CreateEntityByName("prop_dynamic_override");
	
	if (IsValidEntity(crate))
	{
		SetEntityModel(crate, loot.model);
		SetEntProp(crate, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
		
		if (physics)
		{
			DispatchKeyValueFloat(crate, "massScale", loot.mass);
			DispatchKeyValueFloat(crate, "physdamagescale", loot.impact);
		}
		
		if (DispatchSpawn(crate))
		{
			Loot_SetCratePrefab(crate, loot);
			SetEntProp(crate, Prop_Data, "m_takedamage", DAMAGE_YES);
			TeleportEntity(crate, loot.origin, loot.angles, NULL_VECTOR);
			HookSingleEntityOutput(crate, "OnBreak", callback, true);
			
			if (physics)
				AcceptEntityInput(crate, "EnableMotion");
			
			if (IsEntityStuck(crate))
				LogError("Entity crate at origin '%.0f %.0f %.0f' is stuck inside world or entity, possible crash incoming", loot.origin[0], loot.origin[1], loot.origin[2]);
			
			return EntIndexToEntRef(crate);
		}
	}
	
	return INVALID_ENT_REFERENCE;
}

void Loot_SetCratePrefab(int crate, LootCrate loot)
{
	SetEntityModel(crate, loot.model);
	SetEntProp(crate, Prop_Data, "m_nSkin", loot.skin);
	SetEntProp(crate, Prop_Data, "m_iMaxHealth", loot.health);
	SetEntProp(crate, Prop_Data, "m_iHealth", loot.health);
}

stock LootType Loot_StrToLootType(const char[] str)
{
	LootType type;
	g_LootTypeMap.GetValue(str, type);
	return type;
}

bool Loot_IsCrate(int crate)
{
	LootCrate loot;
	return LootConfig_GetCrateByEntity(crate, loot) >= 0;
}

void Loot_OnEntityDestroyed(int entity)
{
	int ref = EntIndexToEntRef(entity);
	
	LootCrate loot;
	int pos = LootConfig_GetCrateByEntity(ref, loot);
	if (pos >= 0)
	{
		loot.entity = INVALID_ENT_REFERENCE;
		LootConfig_SetCrate(pos, loot);
	}
}

public Action EntityOutput_OnBreakCrateConfig(const char[] output, int caller, int activator, float delay)
{
	int crate = EntIndexToEntRef(caller);
	
	LootCrate loot;
	int pos = LootConfig_GetCrateByEntity(crate, loot);
	if (pos >= 0)
		Loot_BreakCrate(GetOwnerLoop(activator), crate, loot);
}

public Action EntityOutput_OnBreakCrateBus(const char[] output, int caller, int activator, float delay)
{
	LootCrate loot;
	LootCrate_GetBus(loot);
	Loot_BreakCrate(GetOwnerLoop(activator), EntIndexToEntRef(caller), loot);
}

public void Loot_BreakCrate(int client, int crate, LootCrate loot)
{
	EmitSoundToAll(loot.sound, crate);
	
	TFClassType class = TFClass_Unknown;
	if (0 < client <= MaxClients && IsClientInGame(client))
		class = TF2_GetPlayerClass(client);
	
	//Search the contents table of this crate
	LootCrateContent content;
	while (loot.GetRandomLootCrateContent(content))
	{
		if (GetRandomFloat() <= content.percentage)
		{
			//Keep going until we find loot from the wanted type and tier
			LootTable lootTable;
			while (!LootTable_GetRandomLoot(lootTable, content.type, content.tier, class)) {  }
			
			float origin[3];
			GetEntPropVector(crate, Prop_Data, "m_vecOrigin", origin);
			
			//Calculate where centre of origin by boundary box
			float mins[3], maxs[3], offset[3];
			GetEntPropVector(crate, Prop_Data, "m_vecMins", mins);
			GetEntPropVector(crate, Prop_Data, "m_vecMaxs", maxs);
			AddVectors(maxs, mins, offset);
			ScaleVector(offset, 0.5);
			AddVectors(origin, offset, origin);
			
			//Start function call to loot creation function
			Call_StartFunction(null, lootTable.callback_create);
			Call_PushCell(client);
			Call_PushCell(lootTable.callbackParams);
			Call_PushArray(origin, sizeof(origin));
			
			if (Call_Finish() != SP_ERROR_NONE)
				LogError("Unable to call function for LootType '%d' class '%d'", lootTable.type, class);
			
			break;
		}
	}
}
