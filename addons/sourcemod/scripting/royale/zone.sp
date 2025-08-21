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

#define ZONE_FADE_START_DISTANCE	500.0
#define ZONE_FADE_ALPHA_MAX		32
#define ZONE_DAMAGE_INTERVAL	1.0

#define ZONE_MODEL				"models/kirillian/brsphere_huge_v3.mdl"
#define ZONE_MODEL_DIAMETER		20000.0

#define MIN_PLAYER_SCALE			0.5
#define ZONE_MAX_SCALE_PLAYERS			32

enum struct ZonePhase
{
	float wait_time;			/**< Time in seconds to wait before starting to shrink. */
	float shrink_time;			/**< Time in seconds for the zone to shrink to target size. */
	float damage_per_second;	/**< Damage dealt per second to players outside the zone. */
	float diameter_percent;	/**< Target diameter as percentage of maximum diameter (0.0 to 1.0). */
	bool moves_zone;			/**< Whether the zone moves to a new position during this phase. */
	
	void Parse(KeyValues kv)
	{
		this.wait_time = kv.GetFloat("wait_time");
		this.shrink_time = kv.GetFloat("shrink_time");
		this.damage_per_second = kv.GetFloat("damage_per_second");
		this.diameter_percent = kv.GetFloat("diameter_percent");
		this.moves_zone = kv.GetNum("moves_zone") != 0;
	}
}

enum struct ZoneConfig
{
	int color[4];			/**< Color of the zone. */
	int color_preview[4];	/**< Color of the zone preview. */
	
	float diameter_max;		/**< Starting diameter of the zone. */
	float diameter_safe;	/**< Diameter the zone is allowed to move in. */
	
	float center[3];		/**< Starting center of the zone. */
	float center_z_min;		/**< Minimum allowed value on the z-axis the zone is allowed to move to. */
	float center_z_max;		/**< Maximum allowed value on the z-axis the zone is allowed to move to. */
	
	ArrayList phases;		/**< List of zone phases defining shrink behavior. */
	
	void Parse(KeyValues kv)
	{
		// KeyValues.GetColor4 has no default value param so we check if the key is set
		char buffer[2];
		
		kv.GetString("color", buffer, sizeof(buffer));
		if (buffer[0])
		{
			kv.GetColor4("color", this.color);
		}
		
		kv.GetString("color_preview", buffer, sizeof(buffer));
		if (buffer[0])
		{
			kv.GetColor4("color_preview", this.color_preview);
		}
		
		this.diameter_max = kv.GetFloat("diameter_max", this.diameter_max);
		this.diameter_safe = kv.GetFloat("diameter_safe", this.diameter_safe);
		
		kv.GetVector("center", this.center, this.center);
		this.center_z_min = kv.GetFloat("center_z_min", this.center_z_min);
		this.center_z_max = kv.GetFloat("center_z_max", this.center_z_max);
		
		if (kv.JumpToKey("phases", false))
		{
			if (!this.phases)
				this.phases = new ArrayList(sizeof(ZonePhase));
			else
				this.phases.Clear();
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					ZonePhase phase;
					phase.Parse(kv);
					this.phases.PushArray(phase);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}
	
	void Delete()
	{
		delete this.phases;
	}
}

enum struct ZoneAreaScore
{
	float position[3];
	float score;
	float heightRange;
	float stdDev;
	int connectivity;
	int validPoints;
}

static ZoneConfig g_zoneData;

static bool g_bInitialized;
static int g_hZonePropEnt = INVALID_ENT_REFERENCE;
static int g_hZonePreviewPropEnt = INVALID_ENT_REFERENCE;
static float g_vecOldPosition[3];
static float g_vecNewPosition[3];
static Handle g_hZoneTimer;
static int g_iCurrentPhase;
static float g_flPhaseStartTime;
static float g_flNextDamageTime;
static bool g_bIsWaiting;
static bool g_bIsShrinking;

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
	
	if (!g_zoneData.phases || g_zoneData.phases.Length == 0)
	{
		LogError("No zone phases configured");
		return;
	}
	
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
	g_hZonePreviewPropEnt = EntIndexToEntRef(Zone_CreateProp(vecCenter, g_zoneData.color_preview));
	AcceptEntityInput(g_hZonePreviewPropEnt, "Disable");
	
	g_bInitialized = true;
}

void Zone_Think()
{
	if (!g_bInitialized)
		return;
	
	float vecZoneOrigin[3];
	float flCurrentDiameter = Zone_GetCurrentDiameter();
	
	if (g_bIsShrinking && g_flPhaseStartTime > 0.0)
	{
		ZonePhase phase;
		if (!Zone_GetCurrentPhase(phase))
			return;
		
		// Relative progress in this shrink cycle from 0 to 1 (current size to goal size)
		float flProgress = 0.0;
		if (phase.shrink_time > 0.0)
		{
			flProgress = (GetGameTime() - g_flPhaseStartTime) / Zone_GetScaledTime(phase.shrink_time);
			flProgress = Clamp(flProgress, 0.0, 1.0);
		}
		else
		{
			flProgress = 1.0;
		}
		
		SubtractVectors(g_vecNewPosition, g_vecOldPosition, vecZoneOrigin);
		ScaleVector(vecZoneOrigin, flProgress);
		AddVectors(vecZoneOrigin, g_vecOldPosition, vecZoneOrigin);
		
		float flTargetDiameter = Zone_GetPhaseDiameter(g_iCurrentPhase);
		float flPreviousDiameter = g_iCurrentPhase > 0 ? Zone_GetPhaseDiameter(g_iCurrentPhase - 1) : g_zoneData.diameter_max;
		flCurrentDiameter = flPreviousDiameter - (flPreviousDiameter - flTargetDiameter) * flProgress;
		
		// Let the zone prop wander
		if (IsValidEntity(g_hZonePropEnt))
		{
			DispatchKeyValueVector(g_hZonePropEnt, "origin", vecZoneOrigin);
			SetEntPropFloat(g_hZonePropEnt, Prop_Send, "m_flModelScale", Zone_GetPropModelScale(flCurrentDiameter));
		}
	}
	else
	{
		// Zone is not currently shrinking, enforce expected values
		vecZoneOrigin = g_vecOldPosition;
	}
	
	float flRadius = flCurrentDiameter / 2.0;
	
	if (g_nRoundState != FRRoundState_RoundEnd)
	{
		bool bIsDamageTick = false;
		
		if (GetGameTime() >= g_flNextDamageTime)
		{
			bIsDamageTick = true;
			g_flNextDamageTime = GetGameTime() + ZONE_DAMAGE_INTERVAL;
		}
		
		ZonePhase phase;
		float flDamage = 0.0;
		if (Zone_GetCurrentPhase(phase))
		{
			flDamage = phase.damage_per_second * ZONE_DAMAGE_INTERVAL;
		}
		
		// Players take damage while outside the zone
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if (!IsPlayerAlive(client))
				continue;
			
			float vecOrigin[3];
			GetClientAbsOrigin(client, vecOrigin);
			
			float flDistanceFromCenter = GetVectorDistance(vecOrigin, vecZoneOrigin);
			float flDistanceFromEdge = flRadius - flDistanceFromCenter;
			bool bIsOutsideZone = flDistanceFromEdge < 0.0;
			
			if (flDistanceFromEdge <= ZONE_FADE_START_DISTANCE)
			{
				// Screen fade for players near or outside the zone
				float fadeRatio = Clamp((ZONE_FADE_START_DISTANCE - flDistanceFromEdge) / ZONE_FADE_START_DISTANCE, 0.0, 1.0);
				int alpha = RoundToNearest(fadeRatio * (bIsOutsideZone ? ZONE_FADE_ALPHA_MAX : ZONE_FADE_ALPHA_MAX / 2));
				ScreenFade(client, g_zoneData.color[0], g_zoneData.color[1], g_zoneData.color[2], alpha, 1000, 0, FFADE_IN);
			}
			
			if (bIsOutsideZone && bIsDamageTick && flDamage > 0.0)
			{
				SDKHooks_TakeDamage(client, 0, 0, flDamage, DMG_PREVENT_PHYSICS_FORCE | DMG_NEVERGIB);
			}
		}
		
		// Buildings take damage and get disabled
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			float vecOrigin[3];
			CBaseEntity(obj).GetAbsOrigin(vecOrigin);
			
			float ratio = GetVectorDistance(vecOrigin, vecZoneOrigin) / flRadius;
			bool bIsOutsideZone = ratio > 1.0;
			
			if (bIsDamageTick)
			{
				if (bIsOutsideZone)
				{
					if (flDamage > 0.0)
						SDKHooks_TakeDamage(obj, 0, 0, flDamage);
					
					AcceptEntityInput(obj, "Disable");
				}
				else
				{
					AcceptEntityInput(obj, "Enable");
				}
			}
		}
	}
}

void Zone_OnSetupFinished()
{
	if (!g_bInitialized)
		return;
	
	g_iCurrentPhase = 0;
	Zone_StartWaitPhase();
}

static void Zone_Reset()
{
	g_bInitialized = false;
	g_hZonePropEnt = INVALID_ENT_REFERENCE;
	g_hZonePreviewPropEnt = INVALID_ENT_REFERENCE;
	g_vecOldPosition = NULL_VECTOR;
	g_vecNewPosition = NULL_VECTOR;
	g_hZoneTimer = null;
	g_iCurrentPhase = 0;
	g_flPhaseStartTime = 0.0;
	g_flNextDamageTime = GetGameTime();
	g_bIsWaiting = false;
	g_bIsShrinking = false;
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
		DispatchKeyValueFloat(zone, "modelscale", Zone_GetPropModelScale(g_zoneData.diameter_max));
		DispatchKeyValue(zone, "solid", "0");
		
		SetEntityRenderMode(zone, RENDER_TRANSCOLOR);
		SetEntityRenderColor(zone, aColor[0], aColor[1], aColor[2], aColor[3]);
		
		// Forces the zone to always transmit
		CBaseEntity(zone).AddEFlags(EFL_IN_SKYBOX);
		
		DispatchSpawn(zone);
		return zone;
	}
	
	return -1;
}

static void Zone_StartWaitPhase()
{
	if (!g_zoneData.phases || g_iCurrentPhase >= g_zoneData.phases.Length)
		return;
	
	g_bIsWaiting = true;
	g_bIsShrinking = false;
	
	ZonePhase phase;
	if (!Zone_GetCurrentPhase(phase))
		return;
	
	if (phase.wait_time > 0.0)
	{
		float flWaitTime = Zone_GetScaledTime(phase.wait_time);
		g_hZoneTimer = CreateTimer(flWaitTime, Timer_StartDisplay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		Timer_StartDisplay(null);
	}
}

static void Timer_StartDisplay(Handle hTimer)
{
	if (hTimer != null && g_hZoneTimer != hTimer)
		return;
	
	g_bIsWaiting = false;
	
	if (!g_zoneData.phases || g_iCurrentPhase >= g_zoneData.phases.Length)
		return;
	
	ZonePhase phase;
	if (!Zone_GetCurrentPhase(phase))
		return;
	
	bool bIsLastPhase = (g_iCurrentPhase == g_zoneData.phases.Length - 1);
	
	Zone_CalculateNewPosition();
	
	// Don't display ghost zone if the zone fully closes in
	if (!bIsLastPhase)
	{
		// Teleport ghost zone to the new center, then update size and display
		if (IsValidEntity(g_hZonePreviewPropEnt))
		{
			DispatchKeyValueVector(g_hZonePreviewPropEnt, "origin", g_vecNewPosition);
			float flNextDiameter = Zone_GetPhaseDiameter(g_iCurrentPhase);
			SetEntPropFloat(g_hZonePreviewPropEnt, Prop_Send, "m_flModelScale", Zone_GetPropModelScale(flNextDiameter));
			AcceptEntityInput(g_hZonePreviewPropEnt, "Enable");
		}
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char szMessage[64];
		Format(szMessage, sizeof(szMessage), "%T", "Zone_MoveWarning", client, RoundToFloor(phase.shrink_time));
		SendHudNotificationCustom(client, szMessage, "ico_notify_thirty_seconds");
	}
	
	Timer_StartShrink(null);
}

static void Timer_StartShrink(Handle hTimer)
{
	if (hTimer != null && g_hZoneTimer != hTimer)
		return;
	
	g_bIsShrinking = true;
	g_flPhaseStartTime = GetGameTime();
	
	EmitGameSoundToAll("MVM.Warning");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		char szMessage[64];
		Format(szMessage, sizeof(szMessage), "%T", "Zone_Moving", client);
		SendHudNotificationCustom(client, szMessage, "ico_notify_ten_seconds");
	}
	
	ZonePhase phase;
	if (!Zone_GetCurrentPhase(phase))
		return;
	
	float flShrinkTime = Zone_GetScaledTime(phase.shrink_time);
	if (flShrinkTime > 0.0)
	{
		g_hZoneTimer = CreateTimer(flShrinkTime, Timer_FinishShrink, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		Timer_FinishShrink(null);
	}
}

static void Timer_FinishShrink(Handle hTimer)
{
	if (hTimer != null && g_hZoneTimer != hTimer)
		return;
	
	g_bIsShrinking = false;
	g_flPhaseStartTime = 0.0;
	
	g_vecOldPosition = g_vecNewPosition;
	
	float flDiameter = Zone_GetPhaseDiameter(g_iCurrentPhase);
	
	if (flDiameter <= 0.0)
	{
		// Zone has fully closed, remove both props
		if (IsValidEntity(g_hZonePropEnt))
		{
			RemoveEntity(g_hZonePropEnt);
		}
		
		if (IsValidEntity(g_hZonePreviewPropEnt))
		{
			RemoveEntity(g_hZonePreviewPropEnt);
		}
	}
	else
	{
		if (IsValidEntity(g_hZonePropEnt))
		{
			DispatchKeyValueVector(g_hZonePropEnt, "origin", g_vecNewPosition);
			SetEntPropFloat(g_hZonePropEnt, Prop_Send, "m_flModelScale", Zone_GetPropModelScale(flDiameter));
		}
		
		if (IsValidEntity(g_hZonePreviewPropEnt))
		{
			AcceptEntityInput(g_hZonePreviewPropEnt, "Disable");
		}
	}
	
	bool bIsLastPhase = (g_iCurrentPhase == g_zoneData.phases.Length - 1);
	
	if (!bIsLastPhase && flDiameter > 0.0)
	{
		// Transition to the next phase
		g_iCurrentPhase++;
		Zone_StartWaitPhase();
	}
	
	BattleBus_SpawnLootBus();
}

static void Zone_CalculateNewPosition()
{
	ZonePhase phase;
	if (!Zone_GetCurrentPhase(phase))
		return;
	
	float flCurrentDiameter = Zone_GetCurrentDiameter();
	float flNextDiameter = Zone_GetPhaseDiameter(g_iCurrentPhase);
	
	bool bIsLastPhase = (g_iCurrentPhase == g_zoneData.phases.Length - 1);
	
	// If zone is meant to move, allow going anywhere within the safe diameter
	// If zone is stationary, only allow moving within the zone diameter
	float flMaxOffset = phase.moves_zone ? g_zoneData.diameter_safe / 2.0 : (flCurrentDiameter - flNextDiameter) / 2.0;
	
	// Try multiple candidate positions and pick the best one
	ArrayList candidates = new ArrayList(sizeof(ZoneAreaScore));
	int maxCandidates = 20;
	int attempts = 0;
	int maxAttempts = 100;
	
	while (candidates.Length < maxCandidates && attempts < maxAttempts)
	{
		attempts++;
		
		float vecNewOrigin[3];
		
		if (flMaxOffset > 0.0)
		{
			float flAngle = GetRandomFloat(0.0, 360.0);
			float flDistance = GetRandomFloat(0.0, flMaxOffset);
			
			vecNewOrigin[0] = g_vecOldPosition[0] + (Cosine(DegToRad(flAngle)) * flDistance);
			vecNewOrigin[1] = g_vecOldPosition[1] + (Sine(DegToRad(flAngle)) * flDistance);
			vecNewOrigin[2] = g_vecOldPosition[2];
		}
		else
		{
			vecNewOrigin = g_vecOldPosition;
		}
		
		// Check if within safe bounds
		float vecOrigin[3];
		vecOrigin = g_zoneData.center;
		vecOrigin[2] = vecNewOrigin[2];
		if (GetVectorDistance(vecOrigin, vecNewOrigin) * 2.0 > g_zoneData.diameter_safe)
			continue;
		
		// Evaluate this position
		ZoneAreaScore candidate;
		if (!Zone_EvaluatePosition(vecNewOrigin, candidate))
			continue;
		
		candidates.PushArray(candidate);
	}
	
	if (candidates.Length == 0)
	{
		// No valid positions found, stay in place
		g_vecNewPosition = g_vecOldPosition;
		delete candidates;
		return;
	}
	
	// Find the best scoring position
	int bestIndex = 0;
	float bestScore = -999999.0;
	
	for (int i = 0; i < candidates.Length; i++)
	{
		ZoneAreaScore candidate;
		candidates.GetArray(i, candidate);
		
		if (candidate.score > bestScore)
		{
			bestScore = candidate.score;
			bestIndex = i;
		}
	}
	
	ZoneAreaScore winner;
	candidates.GetArray(bestIndex, winner);
	g_vecNewPosition = winner.position;
	
	LogMessage("Zone moving to position %.1f %.1f %.1f (score: %.1f, height range: %.1f, connectivity: %d)",
		winner.position[0], winner.position[1], winner.position[2],
		winner.score, winner.heightRange, winner.connectivity);
	
	delete candidates;
}

static bool Zone_EvaluatePosition(float vecOrigin[3], ZoneAreaScore candidate)
{
	ArrayList heights = new ArrayList();
	ArrayList positions = new ArrayList(3);
	
	int gridSize = 5;
	float spacing = 64.0;
	int halfGrid = gridSize / 2;
	
	for (int x = -halfGrid; x <= halfGrid; x++)
	{
		for (int y = -halfGrid; y <= halfGrid; y++)
		{
			float vecStart[3];
			vecStart[0] = vecOrigin[0] + (x * spacing);
			vecStart[1] = vecOrigin[1] + (y * spacing);
			vecStart[2] = g_zoneData.center_z_max;
			
			if (TR_GetPointContents(vecStart) & MASK_SOLID)
				continue;
			
			TR_TraceRayFilter(vecStart, { 90.0, 0.0, 0.0 }, MASK_SOLID, RayType_Infinite, TraceEntityFilter_HitWorld);
			if (!TR_DidHit() || TR_GetEntityIndex() != 0)
				continue;
			
			float vecEnd[3];
			TR_GetEndPosition(vecEnd);
			
			if (vecEnd[2] < g_zoneData.center_z_min)
				continue;
			
			heights.Push(vecEnd[2]);
			positions.PushArray(vecEnd);
		}
	}
	
	candidate.validPoints = heights.Length;
	
	// Minimum 30% valid points to even consider the area
	int totalSamples = gridSize * gridSize;
	int minRequired = RoundToFloor(totalSamples * 0.3);
	
	if (heights.Length < minRequired)
	{
		delete heights;
		delete positions;
		return false;
	}
	
	// Calculate statistics
	float flMinHeight = 999999.0;
	float flMaxHeight = -999999.0;
	float flTotalHeight = 0.0;
	
	for (int i = 0; i < heights.Length; i++)
	{
		float h = heights.Get(i);
		flTotalHeight += h;
		if (h < flMinHeight) flMinHeight = h;
		if (h > flMaxHeight) flMaxHeight = h;
	}
	
	float flAvgHeight = flTotalHeight / heights.Length;
	candidate.heightRange = flMaxHeight - flMinHeight;
	
	// Calculate standard deviation
	float flVariance = 0.0;
	for (int i = 0; i < heights.Length; i++)
	{
		float h = heights.Get(i);
		float diff = h - flAvgHeight;
		flVariance += diff * diff;
	}
	flVariance /= heights.Length;
	candidate.stdDev = SquareRoot(flVariance);
	
	// Check connectivity
	candidate.connectivity = 0;
	for (int i = 0; i < positions.Length - 1; i++)
	{
		float pos1[3];
		positions.GetArray(i, pos1);
		
		for (int j = i + 1; j < positions.Length; j++)
		{
			float pos2[3];
			positions.GetArray(j, pos2);
			
			float dist = GetVectorDistance(pos1, pos2, true);
			if (dist > (spacing * spacing * 2.1))
				continue;
			
			float heightDiff = FloatAbs(pos1[2] - pos2[2]);
			if (heightDiff < 64.0)
			{
				candidate.connectivity++;
			}
		}
	}
	
	// Use median height for position
	heights.Sort(Sort_Ascending, Sort_Float);
	int medianIndex = heights.Length / 2;
	vecOrigin[2] = heights.Get(medianIndex);
	
	candidate.position = vecOrigin;
	
	// Calculate score
	candidate.score = Zone_CalculateAreaScore(candidate);
	
	delete heights;
	delete positions;
	return true;
}

static float Zone_CalculateAreaScore(ZoneAreaScore candidate)
{
	float score = 100.0;
	
	// Valid points bonus (more valid area = better)
	score += candidate.validPoints * 2.0;
	
	// Height range penalty (flatter = better, but some variation is OK)
	if (candidate.heightRange < 100.0)
	{
		score += 20.0; // Bonus for very flat areas
	}
	else if (candidate.heightRange < 300.0)
	{
		score += 10.0 - (candidate.heightRange / 30.0); // Small penalty
	}
	else if (candidate.heightRange < 500.0)
	{
		score -= (candidate.heightRange - 300.0) / 10.0; // Moderate penalty
	}
	else
	{
		score -= 30.0 + (candidate.heightRange - 500.0) / 20.0; // Heavy penalty
	}
	
	// Standard deviation penalty (more uniform = better)
	if (candidate.stdDev < 50.0)
	{
		score += 15.0; // Bonus for very uniform
	}
	else if (candidate.stdDev < 150.0)
	{
		score -= (candidate.stdDev - 50.0) / 10.0; // Gradual penalty
	}
	else
	{
		score -= 20.0 + (candidate.stdDev - 150.0) / 5.0; // Steep penalty
	}
	
	// Connectivity bonus (more walkable paths = better)
	score += candidate.connectivity * 0.5;
	
	// Penalize areas with too few connections relative to valid points
	float expectedConnections = float(candidate.validPoints) * 1.5;
	if (candidate.connectivity < expectedConnections)
	{
		score -= (expectedConnections - candidate.connectivity) * 0.3;
	}
	
	return score;
}

static bool Zone_GetValidHeight(float vecOrigin[3])
{
	ZoneAreaScore area;
	if (!Zone_EvaluatePosition(vecOrigin, area))
		return false;
	
	// For initial placement, accept any area with a positive score
	if (area.score > 0.0)
	{
		vecOrigin[2] = area.position[2];
		return true;
	}
	
	// If score is negative but not terrible, accept with warning
	if (area.score > -50.0)
	{
		LogMessage("Zone placed in suboptimal area (score: %.1f)", area.score);
		vecOrigin[2] = area.position[2];
		return true;
	}
	
	return false;
}

static bool Zone_GetCurrentPhase(ZonePhase phase)
{
	if (!g_zoneData.phases || g_iCurrentPhase < 0 || g_iCurrentPhase >= g_zoneData.phases.Length)
		return false;
	
	g_zoneData.phases.GetArray(g_iCurrentPhase, phase);
	return true;
}

static float Zone_GetPhaseDiameter(int phaseIndex)
{
	if (!g_zoneData.phases || phaseIndex < 0 || phaseIndex >= g_zoneData.phases.Length)
		return g_zoneData.diameter_max;
	
	ZonePhase phase;
	g_zoneData.phases.GetArray(phaseIndex, phase);
	return g_zoneData.diameter_max * phase.diameter_percent;
}

static float Zone_GetCurrentDiameter()
{
	if (g_iCurrentPhase == 0 && !g_bIsShrinking)
	{
		return g_zoneData.diameter_max;
	}
	
	int prevPhase = g_bIsShrinking ? g_iCurrentPhase - 1 : g_iCurrentPhase;
	if (prevPhase < 0) prevPhase = 0;
	
	return Zone_GetPhaseDiameter(prevPhase);
}

static float Zone_GetScaledTime(float baseTime)
{
	int playerCount = GetAlivePlayerCount();
	if (playerCount <= 0) playerCount = 1;
	if (playerCount > ZONE_MAX_SCALE_PLAYERS) playerCount = ZONE_MAX_SCALE_PLAYERS;
	
	float scale = MIN_PLAYER_SCALE + (1.0 - MIN_PLAYER_SCALE) * (float(playerCount) / float(ZONE_MAX_SCALE_PLAYERS));
	return baseTime * scale;
}

static float Zone_GetPropModelScale(float diameter)
{
	return SquareRoot(diameter / ZONE_MODEL_DIAMETER);
}

void Zone_GetNewPosition(float center[3])
{
	center = g_vecNewPosition;
}

float Zone_GetShrinkPercentage(float flProgressInLevel = 0.0)
{
	if (!g_zoneData.phases || g_iCurrentPhase >= g_zoneData.phases.Length)
		return 0.0;
	
	float flCurrentPercent = 1.0;
	float flNextPercent = 0.0;
	
	if (g_iCurrentPhase > 0)
	{
		ZonePhase prevPhase;
		g_zoneData.phases.GetArray(g_iCurrentPhase - 1, prevPhase);
		flCurrentPercent = prevPhase.diameter_percent;
	}
	
	ZonePhase phase;
	g_zoneData.phases.GetArray(g_iCurrentPhase, phase);
	flNextPercent = phase.diameter_percent;
	
	return flCurrentPercent - (flCurrentPercent - flNextPercent) * flProgressInLevel;
}

void Zone_Cleanup()
{
	g_zoneData.Delete();
}