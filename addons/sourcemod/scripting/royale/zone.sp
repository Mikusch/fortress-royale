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
	int color[4];			/**< Color of the zone. */
	int color_ghost[4];		/**< Color of the ghost zone. */
	
	int num_shrinks;		/**< Amount of times the zone should shrink. */
	float diameter_max;		/**< Starting diameter of the zone. */
	float diameter_safe;	/**< Diameter the zone is allowed to move in. */
	
	float center[3];		/**< Starting center of the zone. */
	float center_z_min;		/**< Minimum allowed value on the z-axis the zone is allowed to move to. */
	float center_z_max;		/**< Maximum allowed value on the z-axis the zone is allowed to move to. */
	
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
		
		kv.GetVector("center", this.center, this.center);
		this.center_z_min = kv.GetFloat("center_z_min", this.center_z_min);
		this.center_z_max = kv.GetFloat("center_z_max", this.center_z_max);
	}
}

static ZoneConfig g_zoneData;

static bool g_bInitialized;
static int g_hZonePropEnt = INVALID_ENT_REFERENCE;
static int g_hZoneGhostPropEnt = INVALID_ENT_REFERENCE;
static float g_vecOldPosition[3];	// Position where the zone starts moving
static float g_vecNewPosition[3];	// Position where the zone finishes moving
static Handle g_hZoneTimer;
static int g_iShrinkLevel;
static float g_flShrinkStartTime;
static float g_flNextDamageTime;

void Zone_Precache()
{
	SuperPrecacheModel(ZONE_MODEL);
	
	AddFileToDownloadsTable("materials/models/kirillian/brsphere/br_fog_v3.vmt");
	AddFileToDownloadsTable("materials/models/kirillian/brsphere/br_fog_v3.vtf");
}

void Zone_Parse(KeyValues kv)
{
	g_zoneData.Parse(kv);
}

void Zone_OnRoundStart()
{
	Zone_Reset();
	
	float vecCenter[3];
	vecCenter = g_zoneData.center;
	
	if (!Zone_GetValidHeight(vecCenter))
	{
		LogError("Failed to find valid height for zone center (position %3.2f %3.2f %3.2f)", vecCenter[0], vecCenter[1], vecCenter[2]);
		return;
	}
	
	g_vecOldPosition = vecCenter;
	g_vecNewPosition = vecCenter;
	
	// Create our zone props
	g_hZonePropEnt = EntIndexToEntRef(Zone_CreateProp(vecCenter, g_zoneData.color));
	g_hZoneGhostPropEnt = EntIndexToEntRef(Zone_CreateProp(vecCenter, g_zoneData.color_ghost));
	AcceptEntityInput(g_hZoneGhostPropEnt, "Disable");
	
	g_bInitialized = true;
}

void Zone_Think()
{
	if (!g_bInitialized)
		return;
	
	float vecZoneOrigin[3], flShrinkPercentage;
	float flShrinkDuration = Zone_GetShrinkDuration();
	
	if (g_flShrinkStartTime != -1.0 && g_flShrinkStartTime + flShrinkDuration >= GetGameTime())
	{
		// We are shrinking, update zone position and model scale
		if (IsValidEntity(g_hZonePropEnt))
		{
			// Progress from level x+1 to level x
			float flProgress = (GetGameTime() - g_flShrinkStartTime) / flShrinkDuration;
			SubtractVectors(g_vecNewPosition, g_vecOldPosition, vecZoneOrigin); // Distance from start to end
			ScaleVector(vecZoneOrigin, flProgress); // Scale by progress
			AddVectors(vecZoneOrigin, g_vecOldPosition, vecZoneOrigin); // Add distance to old center
			TeleportEntity(g_hZonePropEnt, vecZoneOrigin);
			
			// Progress from 1.0 to 0.0 (starting zone to zero size)
			flShrinkPercentage = (float(g_iShrinkLevel + 1) - flProgress) / float(g_zoneData.num_shrinks);
			SetEntPropFloat(g_hZonePropEnt, Prop_Send, "m_flModelScale", Zone_GetPropModelScale(flShrinkPercentage));
		}
		
	}
	else
	{
		// Zone is not shrinking
		vecZoneOrigin = g_vecOldPosition;
		flShrinkPercentage = float(g_iShrinkLevel) / float(g_zoneData.num_shrinks);
	}
	
	float flRadius = g_zoneData.diameter_max * flShrinkPercentage / 2.0;
	
	if (GetGameTime() >= g_flNextDamageTime && g_nRoundState != FRRoundState_RoundEnd)
	{
		g_flNextDamageTime = GetGameTime() + 0.5;
		
		// Players take bleed damage
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if (!IsPlayerAlive(client))
				continue;
			
			float vecOrigin[3];
			GetClientAbsOrigin(client, vecOrigin);
			
			float ratio = GetVectorDistance(vecOrigin, vecZoneOrigin) / flRadius;
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
			float vecOrigin[3];
			GetEntPropVector(obj, Prop_Data, "m_vecAbsOrigin", vecOrigin);
			
			float ratio = GetVectorDistance(vecOrigin, vecZoneOrigin) / flRadius;
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

void Zone_OnSetupFinished()
{
	if (!g_bInitialized)
		return;
	
	g_hZoneTimer = CreateTimer(Zone_GetStartDisplayDuration(), Timer_StartDisplay, _, TIMER_FLAG_NO_MAPCHANGE);
}

static void Zone_Reset()
{
	g_bInitialized = false;
	g_hZonePropEnt = INVALID_ENT_REFERENCE;
	g_hZoneGhostPropEnt = INVALID_ENT_REFERENCE;
	g_vecOldPosition = NULL_VECTOR;
	g_vecNewPosition = NULL_VECTOR;
	g_hZoneTimer = null;
	g_iShrinkLevel = g_zoneData.num_shrinks;
	g_flShrinkStartTime = -1.0;
	g_flNextDamageTime = GetGameTime();
}

static int Zone_CreateProp(const float vecOrigin[3], const int aColor[4])
{
	int zone = CreateEntityByName("prop_dynamic");
	if (IsValidEntity(zone))
	{
		DispatchKeyValue(zone, "targetname", "fr_zone");
		DispatchKeyValue(zone, "model", ZONE_MODEL);
		DispatchKeyValueVector(zone, "origin", vecOrigin);
		DispatchKeyValue(zone, "disableshadows", "1");
		DispatchKeyValue(zone, "disablereceiveshadows", "1");
		DispatchKeyValueFloat(zone, "modelscale", Zone_GetPropModelScale());
		DispatchKeyValue(zone, "solid", "0");
		
		SetEntityRenderMode(zone, RENDER_TRANSCOLOR);
		SetEntityRenderColor(zone, aColor[0], aColor[1], aColor[2], aColor[3]);
		
		// Forces the entity to always transmit
		CBaseEntity(zone).AddEFlags(EFL_IN_SKYBOX);
		
		DispatchSpawn(zone);
		return zone;
	}
	
	return -1;
}

static Action Timer_StartDisplay(Handle hTimer)
{
	if (g_hZoneTimer != hTimer)
		return Plugin_Continue;
	
	// Maximum diameter to walk away from previous center
	float flSearchDiameter = 1.0 / float(g_zoneData.num_shrinks) * g_zoneData.diameter_max;
	
	for (;;)
	{
		// Get random angle and offset position from center
		float flAngle = GetRandomFloat(0.0, 360.0);
		float flDiameter = GetRandomFloat(0.0, flSearchDiameter);
		
		float vecOrigin[3], vecNewOrigin[3];
		vecNewOrigin[0] = (Cosine(DegToRad(flAngle)) * flDiameter / 2.0);
		vecNewOrigin[1] = (Sine(DegToRad(flAngle)) * flDiameter / 2.0);
		AddVectors(vecNewOrigin, g_vecOldPosition, vecNewOrigin);
		
		// Find the height of our new area
		if (!Zone_GetValidHeight(vecNewOrigin))
			continue;
		
		// Check if the new center is not outside of the 'safe' diameter (not counting height) 
		vecOrigin = g_zoneData.center;
		vecOrigin[2] = vecNewOrigin[2];
		if (GetVectorDistance(vecOrigin, vecNewOrigin) * 2.0 > g_zoneData.diameter_safe)
			continue;
		
		g_vecNewPosition = vecNewOrigin;
		break;
	}
	
	// Don't display ghost zone if we are on the last shrink level
	if (g_iShrinkLevel > 1)
	{
		// Teleport ghost zone to the new center, then update size and display
		if (IsValidEntity(g_hZoneGhostPropEnt))
		{
			TeleportEntity(g_hZoneGhostPropEnt, g_vecNewPosition);
			SetEntPropFloat(g_hZoneGhostPropEnt, Prop_Send, "m_flModelScale", Zone_GetPropModelScale(float(g_iShrinkLevel - 1) / float(g_zoneData.num_shrinks)));
			AcceptEntityInput(g_hZoneGhostPropEnt, "Enable");
		}
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char szMessage[64];
		Format(szMessage, sizeof(szMessage), "%T", "Zone_ShrinkWarning", client, Zone_GetDisplayDuration());
		SendHudNotificationCustom(client, szMessage, "ico_notify_thirty_seconds");
	}
	
	g_hZoneTimer = CreateTimer(Zone_GetDisplayDuration(), Timer_StartShrink, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

static Action Timer_StartShrink(Handle hTimer)
{
	if (g_hZoneTimer != hTimer)
		return Plugin_Continue;
	
	g_iShrinkLevel--;
	
	EmitGameSoundToAll("MVM.Warning");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char szMessage[64];
		Format(szMessage, sizeof(szMessage), "%T", "Zone_Shrinking", client);
		SendHudNotificationCustom(client, szMessage, "ico_notify_ten_seconds");
	}
	
	// Begin shrinking
	g_flShrinkStartTime = GetGameTime();
	g_hZoneTimer = CreateTimer(Zone_GetShrinkDuration(), Timer_FinishShrink, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

static Action Timer_FinishShrink(Handle hTimer)
{
	if (g_hZoneTimer != hTimer)
		return Plugin_Continue;
	
	// Stop shrinking
	g_flShrinkStartTime = -1.0;
	
	BattleBus_SpawnLootBus();
	
	if (g_iShrinkLevel > 0)
	{
		g_vecOldPosition = g_vecNewPosition;
		
		if (IsValidEntity(g_hZonePropEnt))
		{
			TeleportEntity(g_hZonePropEnt, g_vecNewPosition);
			SetEntPropFloat(g_hZonePropEnt, Prop_Send, "m_flModelScale", Zone_GetPropModelScale(float(g_iShrinkLevel) / float(g_zoneData.num_shrinks)));
		}
		
		// Hide the ghost zone
		if (IsValidEntity(g_hZoneGhostPropEnt))
		{
			AcceptEntityInput(g_hZoneGhostPropEnt, "Disable");
		}
		
		g_hZoneTimer = CreateTimer(Zone_GetNextDisplayDuration(), Timer_StartDisplay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		// Final shrink finished - remove the zone props
		if (IsValidEntity(g_hZonePropEnt))
		{
			RemoveEntity(g_hZonePropEnt);
		}
		
		if (IsValidEntity(g_hZoneGhostPropEnt))
		{
			RemoveEntity(g_hZoneGhostPropEnt);
		}
	}
	
	return Plugin_Continue;
}

static bool Zone_GetValidHeight(float vecOrigin[3])
{
	// Height is calculated by creating 25 traces in a 5 x 5 grid from max height down to ground to figure out average height
	ArrayList heights = new ArrayList();
	
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -2; y <= 2; y++)
		{
			float vecStart[3];
			vecStart[0] = vecOrigin[0] + (x * 64.0);
			vecStart[1] = vecOrigin[1] + (y * 64.0);
			vecStart[2] = g_zoneData.center_z_max;
			
			if (TR_GetPointContents(vecStart) & MASK_SOLID)
				continue;
			
			TR_TraceRayFilter(vecStart, { 90.0, 0.0, 0.0 }, MASK_SOLID, RayType_Infinite, TraceEntityFilter_HitWorld, _, TRACE_WORLD_ONLY);
			if (!TR_DidHit() || TR_GetEntityIndex() != 0)
				continue;
			
			float vecEnd[3];
			TR_GetEndPosition(vecEnd);
			
			if (vecEnd[2] < g_zoneData.center_z_min)
				continue;
			
			heights.Push(vecEnd[2]);
		}
	}
	
	if (heights.Length <= 10)
	{
		// Only collected 10 out of 25, origin is probably in a bad area to fight, refuse to give height
		delete heights;
		return false;
	}
	
	vecOrigin[2] = 0.0;
	for (int i = 0; i < heights.Length; i++)
	{
		vecOrigin[2] += view_as<float>(heights.Get(i));
	}
	
	vecOrigin[2] /= heights.Length;
	delete heights;
	return true;
}

void Zone_GetNewPosition(float center[3])
{
	center = g_vecNewPosition;
}

float Zone_GetSafeDiameter()
{
	return g_zoneData.diameter_safe;
}

float Zone_GetShrinkPercentage()
{
	return float(g_iShrinkLevel) / float(g_zoneData.num_shrinks);
}

static float Zone_GetPropModelScale(float flPercentage = 1.0)
{
	return SquareRoot(g_zoneData.diameter_max / ZONE_MODEL_DIAMETER * flPercentage);
}

static float Zone_GetStartDisplayDuration()
{
	return fr_zone_startdisplay.FloatValue + (fr_zone_startdisplay_player.FloatValue * float(GetAlivePlayerCount()));
}

static float Zone_GetDisplayDuration()
{
	return fr_zone_display.FloatValue + (fr_zone_display_player.FloatValue * float(GetAlivePlayerCount()));
}

static float Zone_GetShrinkDuration()
{
	return fr_zone_shrink.FloatValue + (fr_zone_shrink_player.FloatValue * float(GetAlivePlayerCount()));
}

static float Zone_GetNextDisplayDuration()
{
	return fr_zone_nextdisplay.FloatValue + (fr_zone_nextdisplay_player.FloatValue * float(GetAlivePlayerCount()));
}
