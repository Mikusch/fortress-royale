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
	float travel_height;
	float travel_time;
	float camera_offset[3];
	float camera_angles[3];
	ArrayList sounds;
	
	void Parse(KeyValues kv)
	{
		kv.GetString("model", this.model, sizeof(this.model), this.model);
		this.model_scale = kv.GetFloat("model_scale", this.model_scale);
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

void BattleBus_Parse(KeyValues kv)
{
	g_battleBusData.Parse(kv);
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
		
		// Check if the blimp can go along this path without being obstructed
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

void BattleBus_OnSetupFinished()
{
	int camera = BattleBus_CreateCameraEntity();
	if (!IsValidEntity(camera))
	{
		LogError("Failed to create camera entity");
		return;
	}
	
	int bus = BattleBus_CreateBusEntity();
	if (!IsValidEntity(bus))
	{
		LogError("Failed to create bus entity");
		return;
	}
	
	g_hActiveBusEnt = EntIndexToEntRef(bus);
	
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
		
		FRPlayer(client).m_nPlayerState = FRPlayerState_InBattleBus;
		
		SetVariantString("!activator");
		AcceptEntityInput(camera, "Enable", client);
	}
}

void BattleBus_SpawnLootBus()
{
	int bus = BattleBus_CreateBusEntity();
	if (!IsValidEntity(bus))
	{
		LogError("Failed to create bus entity");
		return;
	}
	
	if (!BattleBus_InitBusEnt(bus, Timer_EndLootBus))
		return;
	
	// Calculate when the bus should drop its crate
	float flTravelTime = g_battleBusData.travel_time;
	float flTime = (flTravelTime - (flTravelTime * Zone_GetShrinkPercentage())) / 2.0;
	
	CreateTimer(GetRandomFloat(flTime, flTravelTime - flTime), Timer_DropLootCrate);
}

static bool BattleBus_InitBusEnt(int bus, Timer func)
{
	float vecOrigin[3], vecAngles[3], vecVelocity[3];
	if (BattleBus_CalculateBusPath(bus, vecOrigin, vecAngles, vecVelocity))
	{
		TeleportEntity(bus, vecOrigin, vecAngles, vecVelocity);
		CreateTimer(g_battleBusData.travel_time, func, _, TIMER_FLAG_NO_MAPCHANGE);
		
		// Play a sound for arriving
		ArrayList sounds = g_battleBusData.sounds;
		if (sounds && sounds.Length != 0)
		{
			char szSound[PLATFORM_MAX_PATH];
			if (sounds.GetString(GetRandomInt(0, sounds.Length - 1), szSound, sizeof(szSound)) != 0)
			{
				PrecacheSound(szSound);
				EmitSoundToAll(szSound, bus, SNDCHAN_STATIC, 155);
			}
		}
		
		return true;
	}
	
	return false;
}

static Action Timer_EndPlayerBus(Handle timer)
{
	if (!IsValidEntity(g_hActiveBusEnt))
		return Plugin_Continue;
	
	// We reached our destination, eject all players still in here
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (FRPlayer(client).m_nPlayerState != FRPlayerState_InBattleBus)
			continue;
		
		BattleBus_EjectPlayer(client);
	}
	
	// Dissolve the bus entity
	int dissolver = CreateEntityByName("env_entity_dissolver");
	if (IsValidEntity(dissolver) && DispatchSpawn(dissolver))
	{
		SetVariantString("!activator");
		AcceptEntityInput(dissolver, "Dissolve", g_hActiveBusEnt);
	}
	
	return Plugin_Continue;
}

static Action Timer_DropLootCrate(Handle timer)
{
	PrintToChatAll("TODO: Make the bus drop a crate here");
	
	return Plugin_Continue;
}

static Action Timer_EndLootBus(Handle timer)
{
	if (IsValidEntity(g_hActiveBusEnt))
	{
		RemoveEntity(g_hActiveBusEnt);
	}
	
	return Plugin_Continue;
}

void BattleBus_EjectPlayer(int client)
{
	if (!IsValidEntity(g_hActiveBusEnt))
		return;
	
	if (FRPlayer(client).m_nPlayerState != FRPlayerState_InBattleBus)
		return;
	
	FRPlayer(client).m_nPlayerState = FRPlayerState_Parachuting;
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
	
	// Eject!
	TeleportEntity(client, vecOrigin);
	EmitGameSoundToAll("MVM.Robot_Teleporter_Deliver", g_hActiveBusEnt);
}

static int BattleBus_CreateBusEntity()
{
	int bus = CreateEntityByName("tf_projectile_rocket");
	if (IsValidEntity(bus))
	{
		if (DispatchSpawn(bus))
		{
			DispatchKeyValue(bus, "solid", "0");
			
			PrecacheModel(g_battleBusData.model);
			SetEntityModel(bus, g_battleBusData.model);
			SetModelScale(bus, g_battleBusData.model_scale);
			
			return bus;
		}
	}
	
	return -1;
}

static int BattleBus_CreateCameraEntity()
{
	int viewcontrol = CreateEntityByName("point_viewcontrol");
	if (IsValidEntity(viewcontrol))
	{
		if (DispatchSpawn(viewcontrol))
		{
			return viewcontrol;
		}
	}
	
	return -1;
}
