/*
 * Copyright (C) 2020  Mikusch & 42
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

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

void Loot_OnEntitySpawned(int entity)
{
	char targetname[CONFIG_MAXCHAR];
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	LootCrate loot;
	if (StrEqual(targetname, "fr_crate"))
		LootCrate_GetDefault(loot);
	else if (!LootConfig_GetPrefabByTargetname(targetname, loot))
		return;
	
	
	if (!GameRules_GetProp("m_bInWaitingForPlayers") && GetRandomFloat() <= float(GetPlayerCount()) / float(TF_MAXPLAYERS))
	{
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", loot.health);
		SetEntProp(entity, Prop_Data, "m_iHealth", loot.health);
		SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_YES);
		HookSingleEntityOutput(entity, "OnBreak", EntityOutput_OnBreakCrateTargetname, true);
	}
	else
	{
		RemoveEntity(entity);
	}
}

void Loot_SetupFinished()
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
			
			//origin and angles in config is saved as string, convert to vector
			float origin[3], angles[3];
			StringToVector(loot.origin, origin);
			StringToVector(loot.angles, angles);
			TeleportEntity(crate, origin, angles, NULL_VECTOR);
			
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

public Action EntityOutput_OnBreakCrateTargetname(const char[] output, int caller, int activator, float delay)
{
	char targetname[CONFIG_MAXCHAR];
	GetEntPropString(caller, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	LootCrate loot;
	if (StrEqual(targetname, "fr_crate"))
		LootCrate_GetDefault(loot);
	else
		LootConfig_GetPrefabByTargetname(targetname, loot);
	
	Loot_BreakCrate(activator, EntIndexToEntRef(caller), loot);
}

public Action EntityOutput_OnBreakCrateConfig(const char[] output, int caller, int activator, float delay)
{
	int crate = EntIndexToEntRef(caller);
	
	LootCrate loot;
	int pos = LootConfig_GetCrateByEntity(crate, loot);
	if (pos >= 0)
		Loot_BreakCrate(activator, crate, loot);
}

public Action EntityOutput_OnBreakCrateBus(const char[] output, int caller, int activator, float delay)
{
	LootCrate loot;
	LootCrate_GetBus(loot);
	Loot_BreakCrate(activator, EntIndexToEntRef(caller), loot);
}

public void Loot_BreakCrate(int entity, int crate, LootCrate loot)
{
	int client = (entity == -1) ? -1 : GetOwnerLoop(entity);
	if ((client <= 0 || client > MaxClients) && entity != -1 && HasEntProp(entity, Prop_Send, "m_hLauncher"))
		client = GetOwnerLoop(GetEntPropEnt(entity, Prop_Send, "m_hLauncher"));
	
	EmitSoundToAll(loot.sound, crate);
	
	TFClassType class = TFClass_Unknown;
	if (0 < client <= MaxClients && IsClientInGame(client))
		class = TF2_GetPlayerClass(client);
	
	//Search the contents table of this crate while rolling for percentage chance
	LootTable lootTable;
	LootCrateContent content;
	do
	{
		loot.GetRandomLootCrateContent(content);
	}
	while (GetRandomFloat() > content.percentage || !LootTable_GetRandomLoot(lootTable, client, content, class));
	
	float origin[3];
	WorldSpaceCenter(crate, origin);
	
	//Start function call to loot creation function
	Call_StartFunction(null, lootTable.callback_create);
	Call_PushCell(client);
	Call_PushCell(lootTable.callbackParams);
	Call_PushArray(origin, sizeof(origin));
	
	if (Call_Finish() != SP_ERROR_NONE)
		LogError("Unable to call function for LootType '%d' class '%d'", lootTable.type, class);
	
	//Reset pickup time so client dont pickup weapon in an instant
	if (0 < client <= MaxClients)
		FRPlayer(client).LastWeaponPickupTime = GetGameTime();
}
