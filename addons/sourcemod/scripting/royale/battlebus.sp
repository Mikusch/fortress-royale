/**
 * Copyright (C) 2022  Mikusch
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

#pragma newdecls required
#pragma semicolon 1

enum struct BattleBusData
{
	char model[PLATFORM_MAX_PATH];
	float model_scale;
	char crate_name[64];
	float travel_height;
	float travel_time;
	float camera_offset[3];
	float camera_angles[3];
	ArrayList sounds;
	
	void Parse(KeyValues kv)
	{
		kv.GetString("model", this.model, sizeof(this.model), this.model);
		this.model_scale = kv.GetFloat("model_scale", this.model_scale);
		kv.GetString("crate_name", this.crate_name, sizeof(this.crate_name), this.crate_name);
		this.travel_height = kv.GetFloat("travel_height", this.travel_height);
		this.travel_time = kv.GetFloat("travel_time", this.travel_time);
		kv.GetVector("camera_offset", this.camera_offset, this.camera_offset);
		kv.GetVector("camera_angles", this.camera_angles, this.camera_angles);
		
		if (kv.JumpToKey("sounds", false))
		{
			this.sounds = new ArrayList(PLATFORM_MAX_PATH);
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char szSound[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, szSound, sizeof(szSound));
					this.sounds.PushString(szSound);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}
}

static BattleBusData g_battleBusData;

static int g_hActiveBusEnt = INVALID_ENT_REFERENCE;
static float g_flBattleBusSpawnTime;

void BattleBus_Parse(KeyValues kv)
{
	g_battleBusData.Parse(kv);
}

void BattleBus_OnSetupFinished()
{
	int bus = BattleBus_CreateBusEntity();
	if (!IsValidEntity(bus))
	{
		LogError("Failed to create bus entity!");
		return;
	}
	
	int camera = BattleBus_CreateCameraEntity();
	if (!IsValidEntity(camera))
	{
		LogError("Failed to create camera entity!");
		return;
	}
	
	// Attach camera first, so it'll follow the bus when it is teleported
	SetVariantString("!activator");
	AcceptEntityInput(camera, "SetParent", bus);
	TeleportEntity(camera, g_battleBusData.camera_offset, g_battleBusData.camera_angles);
	
	if (!BattleBus_InitBusEnt(bus, Timer_EndPlayerBus))
		return;
	
	// Set all players into the bus
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (TF2_GetClientTeam(client) <= TFTeam_Spectator)
			continue;
		
		FRPlayer(client).SetPlayerState(FRPlayerState_InBattleBus);
		
		//SetVariantString("!activator");
		//AcceptEntityInput(camera, "Enable", client);
	}
}

bool BattleBus_IsActive()
{
	return g_flBattleBusSpawnTime + g_battleBusData.travel_time > GetGameTime();
}

int BattleBus_GetEntity()
{
	return g_hActiveBusEnt;
}

bool BattleBus_CalculateBusPath(int bus, float vecOrigin[3], float vecAngles[3], float vecVelocity[3])
{
	// The bus travels along the safe diameter of the zone, using its center
	float flDiameter = Zone_GetSafeDiameter();
	Zone_GetNewPosition(vecOrigin);
	
	// Collect possible yaw angles and shuffle them
	float aYaws[360];
	for (int i = 0; i < sizeof(aYaws); i++)
	{
		aYaws[i] = float(i);
	}
	
	SortFloats(aYaws, sizeof(aYaws), Sort_Random);
	
	for (int i = 0; i < sizeof(aYaws); i++)
	{
		float flYaw = aYaws[i];
		
		vecOrigin[0] = (Cosine(DegToRad(flYaw)) * flDiameter / 2.0) + vecOrigin[0];
		vecOrigin[1] = (Sine(DegToRad(flYaw)) * flDiameter / 2.0) + vecOrigin[1];
		vecOrigin[2] = g_battleBusData.travel_height;
		
		vecAngles[1] = (flYaw >= 180.0) ? (flYaw - 180.0) : (flYaw + 180.0);
		
		vecVelocity[0] = -Cosine(DegToRad(flYaw)) * flDiameter / g_battleBusData.travel_time;
		vecVelocity[1] = -Sine(DegToRad(flYaw)) * flDiameter / g_battleBusData.travel_time;
		
		// Check if the bus can go along this path without being obstructed
		float vecEndPosition[3];
		vecEndPosition = vecVelocity;
		ScaleVector(vecEndPosition, g_battleBusData.travel_time);
		AddVectors(vecEndPosition, vecOrigin, vecEndPosition);
		
		float vecMins[3], vecMaxs[3];
		GetEntPropVector(bus, Prop_Data, "m_vecMins", vecMins);
		GetEntPropVector(bus, Prop_Data, "m_vecMaxs", vecMaxs);
		
		TR_TraceHull(vecOrigin, vecEndPosition, vecMins, vecMaxs, MASK_SOLID);
		if (!TR_DidHit())
		{
			return true;
		}
	}
	
	int entity = TR_GetEntityIndex();
	if (IsValidEntity(entity))
	{
		char szClassname[64];
		if (GetEntityClassname(entity, szClassname, sizeof(szClassname)))
		{
			LogError("Unable to find valid bus path, would collide with entity %d (%s)", entity, szClassname);
		}
	}
	
	return false;
}

void BattleBus_SpawnLootBus()
{
	// No crate name set, do not spawn a loot bus
	if (!g_battleBusData.crate_name[0])
		return;
	
	int bus = BattleBus_CreateBusEntity();
	if (!IsValidEntity(bus))
	{
		LogError("Failed to create bus entity!");
		return;
	}
	
	if (!BattleBus_InitBusEnt(bus, Timer_EndLootBus))
		return;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char szMessage[64];
		Format(szMessage, sizeof(szMessage), "%T", "BattleBus_Incoming", client);
		SendHudNotificationCustom(client, szMessage, "ico_build");
	}
	
	// Calculate when the bus should drop its crate
	float flTravelTime = g_battleBusData.travel_time;
	float flTime = (flTravelTime - (flTravelTime * Zone_GetShrinkPercentage())) / 2.0;
	
	CreateTimer(GetRandomFloat(flTime, flTravelTime - flTime), Timer_DropLootCrate, EntIndexToEntRef(bus));
}

static bool BattleBus_InitBusEnt(int bus, Timer func)
{
	float vecOrigin[3], vecAngles[3], vecVelocity[3];
	if (BattleBus_CalculateBusPath(bus, vecOrigin, vecAngles, vecVelocity))
	{
		g_hActiveBusEnt = EntIndexToEntRef(bus);
		g_flBattleBusSpawnTime = GetGameTime();
		
		TeleportEntity(bus, vecOrigin, vecAngles, vecVelocity);
		CreateTimer(g_battleBusData.travel_time, func, g_hActiveBusEnt, TIMER_FLAG_NO_MAPCHANGE);
		
		// Play a sound for arriving
		ArrayList sounds = g_battleBusData.sounds;
		if (sounds && sounds.Length != 0)
		{
			char szSound[PLATFORM_MAX_PATH];
			if (sounds.GetString(GetRandomInt(0, sounds.Length - 1), szSound, sizeof(szSound)) != 0)
			{
				PrecacheSound(szSound);
				EmitSoundToAll(szSound, bus, SNDCHAN_STATIC, 150);
			}
		}
		
		return true;
	}
	
	return false;
}

static void Timer_EndPlayerBus(Handle timer, int bus)
{
	if (!BattleBus_IsValidBus(bus))
		return;
	
	// We reached our destination, eject all players still in here
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (FRPlayer(client).m_nPlayerState != FRPlayerState_InBattleBus)
			continue;
		
		BattleBus_EjectPlayer(client);
	}
	
	DissolveEntity(bus);
}

static void Timer_EndLootBus(Handle timer, int bus)
{
	if (!BattleBus_IsValidBus(bus))
		return;
	
	DissolveEntity(bus);
}

static void Timer_DropLootCrate(Handle timer, int bus)
{
	if (!BattleBus_IsValidBus(bus))
		return;
	
	// Create a physics-based crate
	CrateConfig crate;
	if (Config_GetCrateByName(g_battleBusData.crate_name, crate))
	{
		int prop = CreateEntityByName("prop_physics_override");
		if (IsValidEntity(prop))
		{
			DispatchKeyValue(prop, "targetname", crate.name);
			DispatchKeyValue(prop, "model", crate.model);
			DispatchKeyValueFloat(prop, "massScale", 500.0);
			
			if (DispatchSpawn(prop))
			{
				if (crate.breakable)
				{
					SetEntProp(prop, Prop_Data, "m_iMaxHealth", crate.health);
					SetEntProp(prop, Prop_Data, "m_iHealth", crate.health);
					SetEntProp(prop, Prop_Data, "m_takedamage", DAMAGE_YES);
				}
				
				float vecOrigin[3], vecAngles[3], vecVelocity[3];
				CBaseEntity(bus).GetAbsOrigin(vecOrigin);
				CBaseEntity(bus).GetAbsAngles(vecAngles);
				CBaseEntity(bus).GetAbsVelocity(vecVelocity);
				
				TeleportEntity(prop, vecOrigin, vecAngles, vecVelocity);
				
				int glow = CreateEntityByName("tf_glow");
				if (IsValidEntity(glow))
				{
					// We can just set this directly if we never spawn the entity
					SetEntPropEnt(glow, Prop_Send, "m_hTarget", prop);
					
					SetVariantString("!activator");
					AcceptEntityInput(glow, "SetParent", prop);
					
					SetVariantColor( { 255, 255, 0, 255 } );
					AcceptEntityInput(glow, "SetGlowColor");
				}
				
				HookSingleEntityOutput(prop, "OnBreak", EntityOutput_OnBreak, true);
			}
		}
	}
	else
	{
		LogError("Failed to find crate with name '%s'", g_battleBusData.crate_name);
	}
}

static void EntityOutput_OnBreak(const char[] output, int caller, int activator, float delay)
{
	char name[64];
	if (GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name)) != 0)
	{
		CrateConfig crate;
		if (Config_GetCrateByName(name, crate))
		{
			// We might have been broken by a non-player entity e.g. rocket projectile, find our real owner
			int owner = IsValidEntity(activator) ? FindParentOwnerEntity(activator) : -1;
			
			if (IsValidClient(owner))
			{
				crate.Open(caller, owner);
			}
		}
	}
}

bool BattleBus_EjectPlayer(int client)
{
	if (!IsValidEntity(g_hActiveBusEnt))
		return false;
	
	if (FRPlayer(client).m_nPlayerState != FRPlayerState_InBattleBus)
		return false;
	
	TF2_ChangeClientTeam(client, TFTeam_Red);
	
	g_bAllowForceRespawn = true;
	TF2_RespawnPlayer(client);
	g_bAllowForceRespawn = false;
	
	// Disable the attached camera for this player
	int viewcontrol = -1;
	while ((viewcontrol = FindEntityByClassname(viewcontrol, "point_viewcontrol")) != -1)
	{
		if (GetEntPropEnt(viewcontrol, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(g_hActiveBusEnt))
			continue;
		
		SetVariantString("!activator");
		AcceptEntityInput(viewcontrol, "Disable", client);
		break;
	}
	
	float vecOrigin[3];
	CBaseEntity(g_hActiveBusEnt).GetAbsOrigin(vecOrigin);
	
	// Eject the player
	TeleportEntity(client, vecOrigin);
	TF2_AddCondition(client, TFCond_TeleportedGlow, 12.0);
	EmitGameSoundToAll("MVM.Robot_Teleporter_Deliver", g_hActiveBusEnt);
	
	return true;
}

static int BattleBus_CreateBusEntity()
{
	int bus = CreateEntityByName("tf_projectile_rocket");
	if (IsValidEntity(bus) && DispatchSpawn(bus))
	{
		DispatchKeyValue(bus, "solid", "0");
		
		PrecacheModel(g_battleBusData.model);
		SetEntityModel(bus, g_battleBusData.model);
		SetModelScale(bus, g_battleBusData.model_scale);
		
		return bus;
	}
	
	return -1;
}

static int BattleBus_CreateCameraEntity()
{
	int viewcontrol = CreateEntityByName("point_viewcontrol");
	if (IsValidEntity(viewcontrol) && DispatchSpawn(viewcontrol))
	{
		return viewcontrol;
	}
	
	return -1;
}

static bool BattleBus_IsValidBus(int entity)
{
	return IsValidEntity(entity) && EntIndexToEntRef(EntRefToEntIndex(entity)) == g_hActiveBusEnt;
}
