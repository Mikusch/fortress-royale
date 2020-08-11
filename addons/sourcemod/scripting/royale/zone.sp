#define ZONE_MODEL			"models/kirillian/brsphere_huge.mdl"
#define ZONE_SHRINK_SOUND	"MVM.Siren"
#define ZONE_DIAMETER	20000.0

#define ZONE_FADE_START_RATIO	0.95
#define ZONE_FADE_ALPHA_MAX		64

enum struct ZoneConfig
{
	int numShrinks;		/**< How many shrinks should be done */
	float diameterMax;	/**< Starting zone size */
	float diameterSafe; /**< center of the zone must always be inside this diameter of center of map */
	
	float center_x;
	float center_y;
	float center_z_max;
	float center_z_min;
	
	void ReadConfig(KeyValues kv)
	{
		this.numShrinks = kv.GetNum("numshrinks", this.numShrinks);
		this.diameterMax = kv.GetFloat("diametermax", this.diameterMax);
		this.diameterSafe = kv.GetFloat("diametersafe", this.diameterSafe);
		
		this.center_x = kv.GetFloat("center_x", this.center_x);
		this.center_y = kv.GetFloat("center_y", this.center_y);
		this.center_z_max = kv.GetFloat("center_z_max", this.center_z_max);
		this.center_z_min = kv.GetFloat("center_z_min", this.center_z_min);
	}
}

static ZoneConfig g_ZoneConfig;

static Handle g_ZoneTimer;
static Handle g_ZoneTimerBleed;

static int g_ZonePropRef = INVALID_ENT_REFERENCE;	//Zone prop model
static int g_ZoneGhostRef = INVALID_ENT_REFERENCE;	//Ghost zone prop model
static float g_ZonePropcenterOld[3];	//Where the zone will start moving
static float g_ZonePropcenterNew[3];	//Where the zone will finish moving
static float g_ZoneShrinkStart;			//GameTime where prop start shrinking
static int g_ZoneShrinkLevel;		//Current shrink level, starting from ZoneConfig.numShrinks to 0

void Zone_ReadConfig(KeyValues kv)
{
	g_ZoneConfig.ReadConfig(kv);
}

void Zone_Precache()
{
	PrecacheScriptSound(ZONE_SHRINK_SOUND);
	
	AddFileToDownloadsTable("models/kirillian/brsphere_huge.dx80.vtx");
	AddFileToDownloadsTable("models/kirillian/brsphere_huge.dx90.vtx");
	AddFileToDownloadsTable("models/kirillian/brsphere_huge.mdl");
	AddFileToDownloadsTable("models/kirillian/brsphere_huge.sw.vtx");
	AddFileToDownloadsTable("models/kirillian/brsphere_huge.vvd");

	AddFileToDownloadsTable("materials/models/kirillian/brsphere/br_fog.vmt");
	AddFileToDownloadsTable("materials/models/kirillian/brsphere/br_fog.vtf");
}

bool Zone_GetHeight(float origin[3])
{
	//Height is calculated by creating 25 traces in a 5 x 5 grid from max height down to ground to figure out average height
	ArrayList heights = new ArrayList();
	
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -2; y <= 2; y++)
		{
			float originStart[3], originEnd[3];
			originStart[0] = origin[0] + (x * 64.0);
			originStart[1] = origin[1] + (y * 64.0);
			originStart[2] = g_ZoneConfig.center_z_max;
			
			if (TR_GetPointContents(originStart) & MASK_SOLID)
				continue;
			
			TR_TraceRayFilter(originStart, view_as<float>({ 90.0, 0.0, 0.0 }), MASK_SOLID, RayType_Infinite, Trace_OnlyHitWorld);
			if (!TR_DidHit())
				continue;
			
			TR_GetEndPosition(originEnd);
			if (originEnd[2] < g_ZoneConfig.center_z_min)
				continue;
			
			heights.Push(originEnd[2]);
		}
	}
	
	int length = heights.Length;
	if (length <= 10)
	{
		//Only collected 10 out of 25, origin is probably in a bad area to fight, refuse to give height
		delete heights;
		return false;
	}
	
	origin[2] = 0.0;
	for (int i = 0; i < length; i++)
		origin[2] += view_as<float>(heights.Get(i));	//bullshit adds as int instead of float
	
	origin[2] /= length;
	delete heights;
	return true;
}

void Zone_RoundStart()
{
	g_ZoneTimer = null;
	g_ZoneShrinkLevel = g_ZoneConfig.numShrinks;
	g_ZoneShrinkStart = 0.0;
	
	float origin[3];
	origin[0] = g_ZoneConfig.center_x;
	origin[1] = g_ZoneConfig.center_y;
	if (!Zone_GetHeight(origin))
	{
		//bruh cant find valid spot in center of the map
		LogError("Unable to find valid height to set zone at center of the map");
		return;
	}
	
	g_ZonePropcenterOld = origin;
	g_ZonePropcenterNew = origin;
	
	//Create actual zone
	g_ZonePropRef = EntIndexToEntRef(CreateEntityByName("prop_dynamic"));
	
	DispatchKeyValueVector(g_ZonePropRef, "origin", origin);
	DispatchKeyValue(g_ZonePropRef, "model", ZONE_MODEL);
	DispatchKeyValue(g_ZonePropRef, "disableshadows", "1");
	
	SetEntPropFloat(g_ZonePropRef, Prop_Send, "m_flModelScale", Zone_GetPropScale());
	SetEntProp(g_ZonePropRef, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	DispatchSpawn(g_ZonePropRef);
	
	SetEntityRenderMode(g_ZonePropRef, RENDER_TRANSCOLOR);
	SetEntityRenderColor(g_ZonePropRef, 255, 0, 0, 255);
	
	//Create ghost zone
	g_ZoneGhostRef = EntIndexToEntRef(CreateEntityByName("prop_dynamic"));
	
	DispatchKeyValueVector(g_ZoneGhostRef, "origin", origin);
	DispatchKeyValue(g_ZoneGhostRef, "model", ZONE_MODEL);
	DispatchKeyValue(g_ZoneGhostRef, "disableshadows", "1");
	
	SetEntProp(g_ZoneGhostRef, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	DispatchSpawn(g_ZoneGhostRef);
	
	SetEntityRenderMode(g_ZoneGhostRef, RENDER_NONE);
	SetEntityRenderColor(g_ZoneGhostRef, 0, 0, 255, 255);
	
	RequestFrame(Frame_UpdateZone, g_ZonePropRef);
}

void Zone_SetupFinished()
{
	g_ZoneTimer = CreateTimer(Zone_GetStartDisplayDuration(), Timer_StartDisplay);
	g_ZoneTimerBleed = CreateTimer(0.5, Timer_Bleed, _, TIMER_REPEAT);
}

public Action Timer_StartDisplay(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	//Max diameter to walk away from previous center
	float diameterSearch = 1.0 / float(g_ZoneConfig.numShrinks) * g_ZoneConfig.diameterMax;
	
	bool found = false;
	do
	{
		//Roll for random angle and offset position from center
		float angleRandom = GetRandomFloat(0.0, 360.0);
		float diameterRandom = GetRandomFloat(0.0, diameterSearch);
		
		float origin[3], originNew[3];
		originNew[0] = (Cosine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		originNew[1] = (Sine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		AddVectors(originNew, g_ZonePropcenterOld, originNew);
		
		//Get height to put zone center ontop of it
		if (!Zone_GetHeight(originNew))
			continue;
		
		//Check if new center is not outside of 'safe' spot
		origin[0] = g_ZoneConfig.center_x;
		origin[1] = g_ZoneConfig.center_y;
		origin[2] = originNew[2];
		if (GetVectorDistance(origin, originNew) > g_ZoneConfig.diameterSafe / 2.0)
			continue;
		
		g_ZonePropcenterNew = originNew;
		found = true;
	}
	while (!found);
	
	if (g_ZoneShrinkLevel > 1)	//Dont bother display ghost if were doing last shrink
	{
		//Teleport ghost to new center, update size and display
		TeleportEntity(g_ZoneGhostRef, g_ZonePropcenterNew, NULL_VECTOR, NULL_VECTOR);
		SetEntPropFloat(g_ZoneGhostRef, Prop_Send, "m_flModelScale", Zone_GetPropScale(float(g_ZoneShrinkLevel - 1) / float(g_ZoneConfig.numShrinks)));
		SetEntityRenderMode(g_ZoneGhostRef, RENDER_TRANSCOLOR);
	}
	
	g_ZoneTimer = CreateTimer(Zone_GetDisplayDuration(), Timer_StartShrink);
}

public Action Timer_StartShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	g_ZoneShrinkLevel--;
	
	EmitGameSoundToAll(ZONE_SHRINK_SOUND);
	char message[256];
	Format(message, sizeof(message), "%T", "Zone_ShrinkAlert", LANG_SERVER);
	TF2_ShowGameMessage(message, "ico_notify_ten_seconds");
	
	g_ZoneShrinkStart = GetGameTime();
	g_ZoneTimer = CreateTimer(Zone_GetShrinkDuration(), Timer_FinishShrink);
}

public Action Timer_FinishShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	g_ZonePropcenterOld = g_ZonePropcenterNew;
	TeleportEntity(g_ZonePropRef, g_ZonePropcenterNew, NULL_VECTOR, NULL_VECTOR);
	SetEntPropFloat(g_ZonePropRef, Prop_Send, "m_flModelScale", Zone_GetPropScale(float(g_ZoneShrinkLevel) / float(g_ZoneConfig.numShrinks)));
	
	//Hide ghost prop
	SetEntityRenderMode(g_ZoneGhostRef, RENDER_NONE);
	
	BattleBus_SpawnLootBus();
	
	if (g_ZoneShrinkLevel > 0)
		g_ZoneTimer = CreateTimer(Zone_GetNextDisplayDuration(), Timer_StartDisplay);
}

public void Frame_UpdateZone(int ref)
{
	//ref param is just to help prevent this function called twice in one frame every round
	if (!IsValidEntity(ref))
		return;
	
	float originZone[3];
	float percentage;
	
	float gametime = GetGameTime();
	float duration = Zone_GetShrinkDuration();
	if (g_ZoneShrinkStart > gametime - duration)
	{
		//We in shrinking state, update zone position and model size
		
		//Progress from level X+1 to level X
		percentage = (gametime - g_ZoneShrinkStart) / duration;
		
		SubtractVectors(g_ZonePropcenterNew, g_ZonePropcenterOld, originZone);	//Distance from start to end
		ScaleVector(originZone, percentage);									//Scale by percentage
		AddVectors(originZone, g_ZonePropcenterOld, originZone);				//Add distance to old center
		TeleportEntity(g_ZonePropRef, originZone, NULL_VECTOR, NULL_VECTOR);
		
		//Progress from 1.0 to 0.0 (starting zone to zero size)
		percentage = (float(g_ZoneShrinkLevel + 1) - percentage) / float(g_ZoneConfig.numShrinks);
		SetEntPropFloat(g_ZonePropRef, Prop_Send, "m_flModelScale", Zone_GetPropScale(percentage));
	}
	else
	{
		//Zone is not shrinking
		originZone = g_ZonePropcenterOld;
		percentage = float(g_ZoneShrinkLevel) / float(g_ZoneConfig.numShrinks);
	}
	
	// Mark players outside zone
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			float originClient[3];
			GetClientAbsOrigin(client, originClient);
			
			float radius = g_ZoneConfig.diameterMax * percentage / 2.0;
			float ratio = GetVectorDistance(originClient, originZone) / radius;
			bool outsideZone = ratio > 1.0;
			
			//Create screen fade when approaching the zone border
			if (ratio > ZONE_FADE_START_RATIO)
			{
				float alpha;
				if (ratio > 1.0)
					alpha = float(ZONE_FADE_ALPHA_MAX);
				else
					alpha = (ratio - ZONE_FADE_START_RATIO) * (1.0 / (1.0 - ZONE_FADE_START_RATIO)) * ZONE_FADE_ALPHA_MAX;
				
				CreateFade(client, _, 255, 0, 0, RoundToNearest(alpha));
			}
			
			//Apply or remove bleed effect
			if (outsideZone && !TF2_IsPlayerInCondition(client, TFCond_Bleeding))
			{
				TF2_MakeBleed(client, client, 9999.0);	//Does no damage
			}
			else if (!outsideZone && FRPlayer(client).OutsideZone)
			{
				TF2_RemoveCondition(client, TFCond_Bleeding);
				FRPlayer(client).ZoneDamageTicks = 0;
			}
			
			FRPlayer(client).OutsideZone = outsideZone;
		}
		else if (FRPlayer(client).OutsideZone)
		{
			FRPlayer(client).OutsideZone = false;
		}
	}
	
	// Mark Engineer buildings outside zone
	int obj = MaxClients + 1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) > MaxClients)
	{
		FREntity entityObj = FREntity(obj);
		
		if (!GetEntProp(obj, Prop_Send, "m_bCarried"))
		{
			float originObj[3];
			GetEntPropVector(obj, Prop_Data, "m_vecAbsOrigin", originObj);
			originObj[2] = originZone[2];
			
			bool outsideZone = GetVectorDistance(originObj, originZone) > g_ZoneConfig.diameterMax * percentage / 2.0;
			
			if (!outsideZone && entityObj.OutsideZone)
				entityObj.ZoneDamageTicks++;
			
			entityObj.OutsideZone = outsideZone;
		}
		else if (entityObj.OutsideZone)
		{
			entityObj.OutsideZone = false;
		}
	}
	
	RequestFrame(Frame_UpdateZone, ref);
}

public Action Timer_Bleed(Handle timer)
{
	if (g_ZoneTimerBleed != timer)
		return Plugin_Stop;
	
	// Players
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && FRPlayer(client).OutsideZone)
		{
			FRPlayer(client).ZoneDamageTicks++;
			SDKHooks_TakeDamage(client, 0, client, Zone_GetCurrentDamage() * FRPlayer(client).ZoneDamageTicks * fr_zone_damagemultiplier.FloatValue, DMG_PREVENT_PHYSICS_FORCE);
		}
	}
	
	// Engineer buildings
	int obj = MaxClients + 1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) > MaxClients)
	{
		FREntity entityObj = FREntity(obj);
		if (!GetEntProp(obj, Prop_Send, "m_bCarried") && entityObj.OutsideZone)
		{
			entityObj.ZoneDamageTicks++;
			SetVariantInt(RoundFloat(Zone_GetCurrentDamage() * float(entityObj.ZoneDamageTicks) * fr_zone_damagemultiplier.FloatValue));
			AcceptEntityInput(obj, "RemoveHealth");
		}
	}
	
	return Plugin_Continue;
}

float Zone_GetCurrentDamage()
{
    return (float(g_ZoneConfig.numShrinks) - float(g_ZoneShrinkLevel)) / float(g_ZoneConfig.numShrinks) * 16.0;
}

void Zone_GetNewCenter(float center[3])
{
	center = g_ZonePropcenterNew;
}

float Zone_GetPropScale(float precentage = 1.0)
{
	return SquareRoot(g_ZoneConfig.diameterMax / ZONE_DIAMETER * precentage);
}

float Zone_GetNewDiameter()
{
	//Return diameter wherever new center zone would be at
	return g_ZoneConfig.diameterMax * (float(g_ZoneShrinkLevel) / float(g_ZoneConfig.numShrinks));
}

float Zone_GetStartDisplayDuration()
{
	return fr_zone_startdisplay.FloatValue + (fr_zone_startdisplay_player.FloatValue * float(g_PlayerCount));
}

float Zone_GetDisplayDuration()
{
	return fr_zone_display.FloatValue + (fr_zone_display_player.FloatValue * float(g_PlayerCount));
}

float Zone_GetShrinkDuration()
{
	return fr_zone_shrink.FloatValue + (fr_zone_shrink_player.FloatValue * float(g_PlayerCount));
}

float Zone_GetNextDisplayDuration()
{
	return fr_zone_nextdisplay.FloatValue + (fr_zone_nextdisplay_player.FloatValue * float(g_PlayerCount));
}