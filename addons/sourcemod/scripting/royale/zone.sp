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

#define ZONE_MODEL				"models/kirillian/brsphere_huge_v3.mdl"
#define ZONE_MODEL_DIAMETER		20000.0

enum struct ZoneConfig
{
	int color[4]; /**< The color of the zone */
	int color_ghost[4]; /**< The color of the ghost zone */
	
	int num_shrinks; /**< How many shrinks should be done */
	float diameter_max; /**< Starting zone size */
	float diameter_safe; /**< Center of the zone must always be inside this diameter of center of map */
	
	float center[3];
	float center_min[3];
	float center_max[3];
	
	void Parse(KeyValues kv)
	{
		// KeyValues.GetColor4 has no default value param so we check if the key is set
		char buffer[2];
		
		kv.GetString("color", buffer, sizeof(buffer));
		if (buffer[0])
		{
			kv.GetColor4("color", this.color);
		}
		
		kv.GetString("color_ghost", buffer, sizeof(buffer));
		if (buffer[0])
		{
			kv.GetColor4("color_ghost", this.color_ghost);
		}
		
		this.num_shrinks = kv.GetNum("num_shrinks", this.num_shrinks);
		
		this.diameter_max = kv.GetFloat("diameter_max", this.diameter_max);
		this.diameter_safe = kv.GetFloat("diameter_safe", this.diameter_safe);
		
		kv.GetVector("center", this.center);
		kv.GetVector("center_min", this.center_min);
		kv.GetVector("center_max", this.center_max);
	}
}

static ZoneConfig g_ZoneConfig;

static float g_ZonePropcenterOld[3]; //Where the zone will start moving
static float g_ZonePropcenterNew[3]; //Where the zone will finish moving

int g_ZonePropRef = INVALID_ENT_REFERENCE;
int g_ZoneGhostRef = INVALID_ENT_REFERENCE;

Handle g_ZoneTimer;
int g_ZoneShrinkLevel;
float g_ZoneShrinkStart;
float g_flNextZoneDamageTick;

void Zone_Precache()
{
	SuperPrecacheModel(ZONE_MODEL);
	
	AddFileToDownloadsTable("materials/models/kirillian/brsphere/br_fog_v3.vmt");
	AddFileToDownloadsTable("materials/models/kirillian/brsphere/br_fog_v3.vtf");
}

void Zone_Parse(KeyValues kv)
{
	g_ZoneConfig.Parse(kv);
}

void Zone_OnRoundStart()
{
	g_ZoneTimer = null;
	g_ZoneShrinkLevel = g_ZoneConfig.num_shrinks;
	g_ZoneShrinkStart = 0.0;
	g_flNextZoneDamageTick = 0.0;
	
	float origin[3];
	origin = g_ZoneConfig.center;
	
	if (!Zone_GetValidHeight(origin))
	{
		LogError("Failed to find valid height for zone center (position %3.2f %3.2f %3.2f)", origin[0], origin[1], origin[2]);
		return;
	}
	
	g_ZonePropcenterOld = origin;
	g_ZonePropcenterNew = origin;
	
	// Create our zone props
	g_ZonePropRef = EntIndexToEntRef(CreateZoneProp(origin, g_ZoneConfig.color));
	g_ZoneGhostRef = EntIndexToEntRef(CreateZoneProp(origin, g_ZoneConfig.color_ghost));
}

int CreateZoneProp(const float origin[3], const int color[4])
{
	int zone = CreateEntityByName("prop_dynamic");
	if (IsValidEntity(zone))
	{
		DispatchKeyValue(zone, "model", ZONE_MODEL);
		DispatchKeyValueVector(zone, "origin", origin);
		DispatchKeyValue(zone, "disableshadows", "1");
		DispatchKeyValueFloat(zone, "modelscale", Zone_GetPropScale());
		DispatchKeyValue(zone, "solid", "0");
		
		SetEntityRenderMode(zone, RENDER_TRANSCOLOR);
		SetEntityRenderColor(zone, color[0], color[1], color[2], color[3]);
		
		// Forces the entity to always transmit
		CBaseEntity(zone).AddEFlags(EFL_IN_SKYBOX);
		
		DispatchSpawn(zone);
		return zone;
	}
	
	return -1;
}

void Zone_OnSetupFinished()
{
	g_ZoneTimer = CreateTimer(Zone_GetStartDisplayDuration(), Timer_StartDisplay, _, TIMER_FLAG_NO_MAPCHANGE);
}

static Action Timer_StartDisplay(Handle timer)
{
	if (g_ZoneTimer != timer)
		return Plugin_Continue;
	
	// Maximum diameter to walk away from previous center
	float diameterSearch = 1.0 / float(g_ZoneConfig.num_shrinks) * g_ZoneConfig.diameter_max;
	
	bool found = false;
	do
	{
		// Roll for random angle and offset position from center
		float angleRandom = GetRandomFloat(0.0, 360.0);
		float diameterRandom = GetRandomFloat(0.0, diameterSearch);
		
		float origin[3], originNew[3];
		originNew[0] = (Cosine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		originNew[1] = (Sine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		AddVectors(originNew, g_ZonePropcenterOld, originNew);
		
		// Find the height of our new area
		if (!Zone_GetValidHeight(originNew))
			continue;
		
		// Check if the new center is not outside of the 'safe' diameter (not counting height) 
		origin = g_ZoneConfig.center;
		origin[2] = originNew[2];
		if (GetVectorDistance(origin, originNew) * 2.0 > g_ZoneConfig.diameter_safe)
			continue;
		
		g_ZonePropcenterNew = originNew;
		found = true;
	}
	while (!found);
	
	// Don't display ghost zone if we are on the last shrink level
	if (g_ZoneShrinkLevel > 1)
	{
		// Teleport ghost zone to the new center, then update size and display
		TeleportEntity(g_ZoneGhostRef, g_ZonePropcenterNew);
		SetEntPropFloat(g_ZoneGhostRef, Prop_Send, "m_flModelScale", Zone_GetPropScale(float(g_ZoneShrinkLevel - 1) / float(g_ZoneConfig.num_shrinks)));
		AcceptEntityInput(g_ZoneGhostRef, "Enable");
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char message[64];
		Format(message, sizeof(message), "%T", "Zone_ShrinkWarning", client, Zone_GetDisplayDuration());
		SendHudNotificationCustom(client, message, "ico_notify_thirty_seconds");
	}
	
	g_ZoneTimer = CreateTimer(Zone_GetDisplayDuration(), Timer_StartShrink, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

static Action Timer_StartShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return Plugin_Continue;
	
	g_ZoneShrinkLevel--;
	
	EmitGameSoundToAll("MVM.Warning");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char message[64];
		Format(message, sizeof(message), "%T", "Zone_Shrinking", client);
		SendHudNotificationCustom(client, message, "ico_notify_ten_seconds");
	}
	
	// Begin shrinking
	g_ZoneShrinkStart = GetGameTime();
	g_ZoneTimer = CreateTimer(Zone_GetShrinkDuration(), Timer_FinishShrink, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

static Action Timer_FinishShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return Plugin_Continue;
	
	// Stop shrinking
	g_ZoneShrinkStart = 0.0;
	
	//BattleBus_SpawnLootBus();
	
	if (g_ZoneShrinkLevel > 0)
	{
		g_ZonePropcenterOld = g_ZonePropcenterNew;
		
		// Hide the ghost zone
		AcceptEntityInput(g_ZoneGhostRef, "Disable");
		
		TeleportEntity(g_ZonePropRef, g_ZonePropcenterNew);
		SetEntPropFloat(g_ZonePropRef, Prop_Send, "m_flModelScale", Zone_GetPropScale(float(g_ZoneShrinkLevel) / float(g_ZoneConfig.num_shrinks)));
		
		g_ZoneTimer = CreateTimer(Zone_GetNextDisplayDuration(), Timer_StartDisplay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		// Final shrink finished - remove the zone props
		RemoveEntity(g_ZonePropRef);
		RemoveEntity(g_ZoneGhostRef);
	}
	
	return Plugin_Continue;
}

void Zone_Think()
{
	float vecZoneOrigin[3];
	float percentage = 0.0;
	float duration = Zone_GetShrinkDuration();
	
	if (g_ZoneShrinkStart + duration > GetGameTime())
	{
		// We are shrinking, update zone position and model scale
		
		if (IsValidEntity(g_ZonePropRef))
		{
			// Progress from level x+1 to level x
			float progress = (GetGameTime() - g_ZoneShrinkStart) / duration;
			SubtractVectors(g_ZonePropcenterNew, g_ZonePropcenterOld, vecZoneOrigin); // Distance from start to end
			ScaleVector(vecZoneOrigin, progress); // Scale by progress
			AddVectors(vecZoneOrigin, g_ZonePropcenterOld, vecZoneOrigin); // Add distance to old center
			TeleportEntity(g_ZonePropRef, vecZoneOrigin);
			
			// Progress from 1.0 to 0.0 (starting zone to zero size)
			percentage = (float(g_ZoneShrinkLevel + 1) - progress) / float(g_ZoneConfig.num_shrinks);
			SetEntPropFloat(g_ZonePropRef, Prop_Send, "m_flModelScale", Zone_GetPropScale(percentage));
		}
	}
	else
	{
		// Zone is not shrinking
		vecZoneOrigin = g_ZonePropcenterOld;
		percentage = float(g_ZoneShrinkLevel) / float(g_ZoneConfig.num_shrinks);
	}
	
	float zoneRadius = g_ZoneConfig.diameter_max * percentage / 2.0;
	
	if (GetGameTime() >= g_flNextZoneDamageTick)
	{
		g_flNextZoneDamageTick = GetGameTime() + 0.5;
		
		// Players take damage and 
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if (!IsPlayerAlive(client))
				continue;
			
			float origin[3];
			GetClientAbsOrigin(client, origin);
			
			float ratio = GetVectorDistance(origin, vecZoneOrigin) / zoneRadius;
			bool isOutsideZone = ratio > 1.0;
			
			if (isOutsideZone)
			{
				TF2Util_MakePlayerBleed(client, client, 0.5, _, fr_zone_damage.IntValue);
			}
		}
		
		// Buildings take damage and get disabled
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			float origin[3];
			GetEntPropVector(obj, Prop_Data, "m_vecAbsOrigin", origin);
			
			float ratio = GetVectorDistance(origin, vecZoneOrigin) / zoneRadius;
			bool isOutsideZone = ratio > 1.0;
			
			if (isOutsideZone)
			{
				SDKHooks_TakeDamage(obj, 0, 0, fr_zone_damage.FloatValue);
				AcceptEntityInput(obj, "Disable");
			}
			else
			{
				AcceptEntityInput(obj, "Enable");
			}
		}
	}
}

bool Zone_GetValidHeight(float origin[3])
{
	// Height is calculated by creating 25 traces in a 5 x 5 grid from max height down to ground to figure out average height
	ArrayList heights = new ArrayList();
	
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -2; y <= 2; y++)
		{
			float originStart[3], originEnd[3];
			originStart[0] = origin[0] + (x * 64.0);
			originStart[1] = origin[1] + (y * 64.0);
			originStart[2] = g_ZoneConfig.center_max[2];
			
			if (TR_GetPointContents(originStart) & MASK_SOLID)
				continue;
			
			TR_TraceRayFilter(originStart, view_as<float>( { 90.0, 0.0, 0.0 } ), MASK_SOLID, RayType_Infinite, TraceEntityFilter_OnlyHitWorld, _, TRACE_WORLD_ONLY);
			if (!TR_DidHit())
				continue;
			
			TR_GetEndPosition(originEnd);
			if (originEnd[2] < g_ZoneConfig.center_min[2])
				continue;
			
			heights.Push(originEnd[2]);
		}
	}
	
	if (heights.Length <= 10)
	{
		// Only collected 10 out of 25, origin is probably in a bad area to fight, refuse to give height
		delete heights;
		return false;
	}
	
	origin[2] = 0.0;
	for (int i = 0; i < heights.Length; i++)
	{
		origin[2] += view_as<float>(heights.Get(i));
	}
	
	origin[2] /= heights.Length;
	delete heights;
	return true;
}

float Zone_GetPropScale(float percentage = 1.0)
{
	return SquareRoot(g_ZoneConfig.diameter_max / ZONE_MODEL_DIAMETER * percentage);
}

float Zone_GetNewDiameter()
{
	// Return diameter wherever new center zone would be at
	return g_ZoneConfig.diameter_max * (float(g_ZoneShrinkLevel) / float(g_ZoneConfig.num_shrinks));
}

float Zone_GetStartDisplayDuration()
{
	return fr_zone_startdisplay.FloatValue + (fr_zone_startdisplay_player.FloatValue * float(GetAlivePlayersCount()));
}

float Zone_GetDisplayDuration()
{
	return fr_zone_display.FloatValue + (fr_zone_display_player.FloatValue * float(GetAlivePlayersCount()));
}

float Zone_GetShrinkDuration()
{
	return fr_zone_shrink.FloatValue + (fr_zone_shrink_player.FloatValue * float(GetAlivePlayersCount()));
}

float Zone_GetNextDisplayDuration()
{
	return fr_zone_nextdisplay.FloatValue + (fr_zone_nextdisplay_player.FloatValue * float(GetAlivePlayersCount()));
}

bool TraceEntityFilter_OnlyHitWorld(int entity, int mask)
{
	return entity == 0;
}
