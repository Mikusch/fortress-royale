static StringMap g_LootTypeMap;
static ArrayList g_SpawnedCrates;

void Loot_Init()
{
	g_SpawnedCrates = new ArrayList(2);
	g_LootTypeMap = new StringMap();
	g_LootTypeMap.SetValue("WEAPON_PRIMARY", Loot_Weapon_Primary);
	g_LootTypeMap.SetValue("WEAPON_SECONDARY", Loot_Weapon_Secondary);
	g_LootTypeMap.SetValue("WEAPON_MELEE", Loot_Weapon_Melee);
	g_LootTypeMap.SetValue("WEAPON_PDA", Loot_Weapon_PDA);
	g_LootTypeMap.SetValue("WEAPON_MISC", Loot_Weapon_Misc);
	g_LootTypeMap.SetValue("PICKUP_HEALTH", Loot_Pickup_Health);
	g_LootTypeMap.SetValue("PICKUP_AMMO", Loot_Pickup_Ammo);
	g_LootTypeMap.SetValue("PICKUP_SPELL", Loot_Pickup_Spell);
	g_LootTypeMap.SetValue("POWERUP_CRITS", Loot_Powerup_Crits);
	g_LootTypeMap.SetValue("POWERUP_UBER", Loot_Powerup_Uber);
	g_LootTypeMap.SetValue("POWERUP_RUNE", Loot_Powerup_Rune);
}

void Loot_SpawnCratesInWorld()
{
	int configIndex = 0;
	LootCrateConfig lootCrate;
	while (Config_GetLootCrate(configIndex, lootCrate))
	{
		Loot_SpawnCrateInWorld(lootCrate, configIndex);
		configIndex++;
	}
}

int Loot_SpawnCrateInWorld(LootCrateConfig config, int configIndex, bool force = false)
{
	if (force || GetRandomFloat() <= config.chance)
	{
		int crate = CreateEntityByName("prop_dynamic_override");
		if (IsValidEntity(crate))
		{
			SetEntProp(crate, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
			Loot_SetCratePrefab(crate, config);
			
			if (DispatchSpawn(crate))
			{
				SetEntProp(crate, Prop_Data, "m_takedamage", DAMAGE_YES);
				TeleportEntity(crate, config.origin, config.angles, NULL_VECTOR);
				HookSingleEntityOutput(crate, "OnBreak", EntityOutput_OnBreak, true);
				
				int length = g_SpawnedCrates.Length;
				g_SpawnedCrates.Resize(length + 1);
				g_SpawnedCrates.Set(length, EntIndexToEntRef(crate), 0);
				g_SpawnedCrates.Set(length, configIndex, 1);
				
				Loot_CreateGlow(crate);
				return EntIndexToEntRef(crate);
			}
		}
	}
	
	return INVALID_ENT_REFERENCE;
}

void Loot_CreateGlow(int entity)
{
	int glow = CreateEntityByName("tf_taunt_prop");
	if (IsValidEntity(glow) && DispatchSpawn(glow))
	{
		char model[PLATFORM_MAX_PATH];
		GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
		SetEntityModel(glow, model);
		
		SetEntPropEnt(glow, Prop_Data, "m_hEffectEntity", entity);
		SetEntProp(glow, Prop_Send, "m_bGlowEnabled", 1);
		
		int effects = GetEntProp(glow, Prop_Send, "m_fEffects");
		SetEntProp(glow, Prop_Send, "m_fEffects", effects | EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW);
		
		SetVariantString("!activator");
		AcceptEntityInput(glow, "SetParent", entity);
		
		SDKHook(glow, SDKHook_SetTransmit, Loot_SetTransmit);
	}
}

public Action Loot_SetTransmit(int glow, int client)
{
	int crate = GetEntPropEnt(glow, Prop_Data, "m_hMoveParent");
	if (client > 0 && client <= MaxClients && Loot_IsClientLookingAtCrate(crate, client))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public bool Loot_FilterClient(int entity, int contentsMask, any client)
{
	return entity != client;
}

void Loot_SetCratePrefab(int crate, LootCrateConfig config)
{
	SetEntityModel(crate, config.model);
	SetEntProp(crate, Prop_Data, "m_nSkin", config.skin);
	SetEntProp(crate, Prop_Data, "m_iMaxHealth", config.health);
	SetEntProp(crate, Prop_Data, "m_iHealth", config.health);
}

stock ArrayList Loot_StrToLootTypes(const char[] str)
{
	ArrayList types = new ArrayList();
	
	char parts[32][PLATFORM_MAX_PATH];
	if (ExplodeString(str, "|", parts, sizeof(parts), sizeof(parts[])) > 0)
	{
		for (int i = 0; i < sizeof(parts); i++)
		{
			if (!StrEqual(parts[i], NULL_STRING))
				types.Push(Loot_StrToLootType(parts[i]));
		}
	}
	
	return types;
}

stock LootType Loot_StrToLootType(const char[] str)
{
	LootType type;
	g_LootTypeMap.GetValue(str, type);
	return type;
}

stock bool Loot_IsCrate(int ref)
{
	return g_SpawnedCrates.FindValue(ref, 0) >= 0;
}

stock bool Loot_IsClientLookingAtCrate(int crate, int client)
{
	float position[3], angles[3];
	GetClientEyePosition(client, position);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(position))
		return false;
	
	Handle trace = TR_TraceRayFilterEx(position, angles, MASK_PLAYERSOLID, RayType_Infinite, Loot_FilterClient, client);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return false;
	}
	
	int entity = TR_GetEntityIndex(trace);
	delete trace;
	return Loot_IsCrate(EntIndexToEntRef(entity)) && entity == crate;
}

stock int Loot_GetCrateConfig(int ref, LootCrateConfig lootCrate)
{
	int index = g_SpawnedCrates.FindValue(ref, 0);
	if (index < 0)
		return -1;
	
	int configIndex = g_SpawnedCrates.Get(index, 1);
	if (!Config_GetLootCrate(configIndex, lootCrate))
		return -1;
	
	return configIndex;
}

stock void Loot_DeleteCrate(int ref)
{
	int index = g_SpawnedCrates.FindValue(ref, 0);
	if (index >= 0)
	{
		RemoveEntity(ref);
		g_SpawnedCrates.Erase(index);
	}
}

public Action EntityOutput_OnBreak(const char[] output, int caller, int activator, float delay)
{
	LootCrateConfig lootCrate;
	int configIndex = Loot_GetCrateConfig(EntIndexToEntRef(caller), lootCrate);
	if (configIndex >= 0)
	{
		EmitSoundToAll(lootCrate.sound, caller);
		
		int client = GetOwnerLoop(activator);
		
		//While loop to keep searching for loot until found valid
		LootConfig loot;
		while (g_LootTable.GetRandomLoot(loot, lootCrate.GetRandomLootType(), client) <= 0) {  }
		
		//Start function call to loot creation function
		Call_StartFunction(null, loot.callback_create);
		Call_PushCell(client);
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
