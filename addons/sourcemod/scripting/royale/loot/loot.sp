static StringMap g_LootTypeMap;

void Loot_Init()
{
	g_LootTypeMap = new StringMap();
	g_LootTypeMap.SetValue("WEAPON_COMMON", Loot_Weapon_Common);
	g_LootTypeMap.SetValue("WEAPON_UNCOMMON", Loot_Weapon_Uncommon);
	g_LootTypeMap.SetValue("WEAPON_RARE", Loot_Weapon_Rare);
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
			
			Loot_CreateGlow(crate);
			
			if (IsEntityStuck(crate))
				LogError("Entity crate at origin '%.0f %.0f %.0f' is stuck inside world or entity, possible crash incoming", loot.origin[0], loot.origin[1], loot.origin[2]);
			
			return EntIndexToEntRef(crate);
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

void Loot_SetCratePrefab(int crate, LootCrate loot)
{
	SetEntityModel(crate, loot.model);
	SetEntProp(crate, Prop_Data, "m_nSkin", loot.skin);
	SetEntProp(crate, Prop_Data, "m_iMaxHealth", loot.health);
	SetEntProp(crate, Prop_Data, "m_iHealth", loot.health);
}

stock ArrayList Loot_StrToLootTypes(const char[] str)
{
	ArrayList types = new ArrayList();
	
	char parts[32][PLATFORM_MAX_PATH];
	int count = ExplodeString(str, "|", parts, sizeof(parts), sizeof(parts[]));
	for (int i = 0; i < count; i++)
		types.Push(Loot_StrToLootType(parts[i]));
	
	return types;
}

stock LootType Loot_StrToLootType(const char[] str)
{
	LootType type;
	g_LootTypeMap.GetValue(str, type);
	return type;
}

stock bool Loot_IsCrate(int crate)
{
	LootCrate loot;
	return LootConfig_GetCrateByEntity(crate, loot) >= 0;
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

stock void Loot_DeleteCrate(int crate)
{
	LootCrate loot;
	int pos = LootConfig_GetCrateByEntity(crate, loot);
	if (pos >= 0)
	{
		loot.entity = INVALID_ENT_REFERENCE;
		LootConfig_SetCrate(pos, loot);
	}
	
	RemoveEntity(crate);
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
	
	//While loop to keep searching for loot until found valid
	LootTable lootTable;
	while (!LootTable_GetRandomLoot(lootTable, loot.GetRandomLootType(), class)) {  }
	
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
}