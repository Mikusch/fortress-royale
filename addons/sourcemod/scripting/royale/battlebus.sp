/**
 * Copyright (C) 2023  Mikusch
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
	float model_angles[3];
	float model_scale;
	char default_anim[PLATFORM_MAX_PATH];
	char crate_name[64];
	float travel_height;
	float travel_diameter;
	float travel_time;
	float camera_offset[3];
	float camera_angles[3];
	ArrayList sounds;
	
	void Parse(KeyValues kv)
	{
		kv.GetString("model", this.model, sizeof(this.model), this.model);
		kv.GetVector("model_angles", this.model_angles, this.model_angles);
		this.model_scale = kv.GetFloat("model_scale", this.model_scale);
		kv.GetString("default_anim", this.default_anim, sizeof(this.default_anim), this.default_anim);
		kv.GetString("crate_name", this.crate_name, sizeof(this.crate_name), this.crate_name);
		this.travel_height = kv.GetFloat("travel_height", this.travel_height);
		this.travel_diameter = kv.GetFloat("travel_diameter", this.travel_diameter);
		this.travel_time = kv.GetFloat("travel_time", this.travel_time);
		kv.GetVector("camera_offset", this.camera_offset, this.camera_offset);
		kv.GetVector("camera_angles", this.camera_angles, this.camera_angles);
		
		if (kv.JumpToKey("sounds", false))
		{
			this.sounds = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
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

static int g_hBusPropEnt = INVALID_ENT_REFERENCE;
static Handle g_hBusDropSoundTimer;
static float g_flBusSpawnTime;

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
	
	float angles[3];
	AddVectors(g_battleBusData.camera_angles, g_battleBusData.model_angles, angles);
	
	TeleportEntity(camera, g_battleBusData.camera_offset, angles);
	
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
		
		SetClientViewEntity(client, camera);
	}
}

void BattleBus_OnEntityDestroyed(int entity)
{
	if (entity == EntRefToEntIndex(g_hBusPropEnt))
	{
		// Stop any lingering sounds when the bus gets destroyed
		ArrayList sounds = g_battleBusData.sounds;
		if (sounds)
		{
			for (int i = 0; i < sounds.Length; i++)
			{
				char szSound[PLATFORM_MAX_PATH];
				if (sounds.GetString(i, szSound, sizeof(szSound)))
				{
					if (PrecacheScriptSound(szSound))
					{
						EmitGameSoundToAll(szSound, entity, SND_STOP | SND_STOPLOOPING);
					}
					else if (PrecacheSound(szSound))
					{
						StopSound(entity, SNDCHAN_STATIC, szSound);
					}
				}
			}
		}
	}
}

bool BattleBus_IsActive()
{
	return g_flBusSpawnTime + g_battleBusData.travel_time > GetGameTime();
}

int BattleBus_GetEntity()
{
	return g_hBusPropEnt;
}

bool BattleBus_CalculateBusPath(int bus, float vecOrigin[3], float vecAngles[3], float vecVelocity[3])
{
	// The bus travels along the center of the zone
	float vecCenter[3];
	Zone_GetNewPosition(vecCenter);
	
	// Collect possible yaw angles and shuffle them
	float aDegs[360];
	for (int i = 0; i < sizeof(aDegs); i++)
	{
		aDegs[i] = float(i);
	}
	
	SortFloats(aDegs, sizeof(aDegs), Sort_Random);
	
	for (int i = 0; i < sizeof(aDegs); i++)
	{
		float flDeg = aDegs[i];
		
		vecOrigin[0] = (Cosine(DegToRad(flDeg)) * g_battleBusData.travel_diameter / 2.0) + vecCenter[0];
		vecOrigin[1] = (Sine(DegToRad(flDeg)) * g_battleBusData.travel_diameter / 2.0) + vecCenter[1];
		vecOrigin[2] = g_battleBusData.travel_height;
		
		vecAngles[1] = (flDeg >= 180.0) ? (flDeg - 180.0) : (flDeg + 180.0);
		AddVectors(vecAngles, g_battleBusData.model_angles, vecAngles);
		
		vecVelocity[0] = -Cosine(DegToRad(flDeg)) * g_battleBusData.travel_diameter / g_battleBusData.travel_time;
		vecVelocity[1] = -Sine(DegToRad(flDeg)) * g_battleBusData.travel_diameter / g_battleBusData.travel_time;
		
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
	if (!BattleBus_CalculateBusPath(bus, vecOrigin, vecAngles, vecVelocity))
	{
		RemoveEntity(bus);
		return false;
	}
	
	g_hBusPropEnt = EntIndexToEntRef(bus);
	g_flBusSpawnTime = GetGameTime();
	
	TeleportEntity(bus, vecOrigin, vecAngles, vecVelocity);
	CreateTimer(g_battleBusData.travel_time, func, g_hBusPropEnt, TIMER_FLAG_NO_MAPCHANGE);
	
	// Play a sound for arriving
	ArrayList sounds = g_battleBusData.sounds;
	if (sounds && sounds.Length)
	{
		char szSound[PLATFORM_MAX_PATH];
		if (sounds.GetString(GetRandomInt(0, sounds.Length - 1), szSound, sizeof(szSound)))
		{
			if (PrecacheScriptSound(szSound))
			{
				EmitGameSoundToAll(szSound, bus);
			}
			else if (PrecacheSound(szSound))
			{
				EmitSoundToAll(szSound, bus, SNDCHAN_STATIC, 150);
			}
		}
	}
	
	return true;
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
	CrateData crate;
	if (Config_GetCrateByName(g_battleBusData.crate_name, crate))
	{
		int prop = CreateEntityByName("prop_physics_override");
		if (IsValidEntity(prop))
		{
			DispatchKeyValue(prop, "targetname", crate.name);
			DispatchKeyValue(prop, "model", crate.model);
			DispatchKeyValueFloat(prop, "massScale", 1000.0);
			
			if (DispatchSpawn(prop))
			{
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
			}
		}
	}
	else
	{
		LogError("Failed to find crate with name '%s'", g_battleBusData.crate_name);
	}
}

bool BattleBus_EjectPlayer(int client)
{
	if (!IsValidEntity(g_hBusPropEnt))
		return false;
	
	if (FRPlayer(client).m_nPlayerState != FRPlayerState_InBattleBus)
		return false;
	
	TF2_ChangeClientTeam(client, TFTeam_Red);
	
	g_bAllowForceRespawn = true;
	TF2_RespawnPlayer(client);
	g_bAllowForceRespawn = false;
	
	// Disable the attached camera for this player
	int viewcontrol = -1;
	while ((viewcontrol = FindEntityByClassname(viewcontrol, "prop_dynamic")) != -1)
	{
		if (GetEntPropEnt(viewcontrol, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(g_hBusPropEnt))
			continue;
		
		SetClientViewEntity(client, client);
		break;
	}
	
	float vecOrigin[3], angRotation[3], vecVelocity[3];
	CBaseEntity(g_hBusPropEnt).GetAbsOrigin(vecOrigin);
	CBaseEntity(g_hBusPropEnt).GetAbsAngles(angRotation);
	CBaseEntity(g_hBusPropEnt).GetAbsVelocity(vecVelocity);
	
	// Eject the player
	TeleportEntity(client, vecOrigin, angRotation, vecVelocity);
	TF2_AddCondition(client, TFCond_TeleportedGlow, 12.0);
	
	// To avoid destroying people's ears when everyone drops at once
	g_hBusDropSoundTimer = CreateTimer(0.1, Timer_PlayDropSound);
	
	return true;
}

static void Timer_PlayDropSound(Handle timer)
{
	if (timer != g_hBusDropSoundTimer)
		return;
	
	EmitGameSoundToAll("MVM.Robot_Teleporter_Deliver", g_hBusPropEnt);
}

static int BattleBus_CreateBusEntity()
{
	int bus = CreateEntityByName("prop_dynamic");
	if (IsValidEntity(bus))
	{
		DispatchKeyValue(bus, "model", g_battleBusData.model);
		DispatchKeyValueFloat(bus, "modelscale", g_battleBusData.model_scale);
		DispatchKeyValue(bus, "defaultanim", g_battleBusData.default_anim);
		
		if (DispatchSpawn(bus))
		{
			// Needs to be set after CBaseProp::Spawn! 
			SDKCall_CBaseEntity_SetMoveType(bus, MOVETYPE_FLY, MOVECOLLIDE_FLY_CUSTOM);
			CBaseEntity(bus).SetNextThink(GetGameTime());
			
			return bus;
		}
	}
	
	return -1;
}

static int BattleBus_CreateCameraEntity()
{
	int viewcontrol = CreateEntityByName("prop_dynamic");
	if (IsValidEntity(viewcontrol))
	{
		SetEntityModel(viewcontrol, "models/empty.mdl");
		
		if (DispatchSpawn(viewcontrol))
			return viewcontrol;
	}
	
	return -1;
}

static bool BattleBus_IsValidBus(int entity)
{
	return IsValidEntity(entity) && EntIndexToEntRef(EntRefToEntIndex(entity)) == g_hBusPropEnt;
}
