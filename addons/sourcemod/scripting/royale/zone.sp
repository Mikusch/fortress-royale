#define ZONE_MODEL			"models/br/br_zone_test.mdl"
#define ZONE_SHRINK_SOUND	"MVM.Siren"
#define ZONE_DIAMETER	15000.0
#define ZONE_DURATION	10.0

enum struct ZoneConfig
{
	int numShrinks;		/**< How many shrinks should be done */
	float diameterMax;	/**< Starting zone size */
	float diameterSafe; /**< center of the zone must always be inside this diameter of center of map */
	float center[3];	/**< center of the map, and starting zone position */
	
	void ReadConfig(KeyValues kv)
	{
		this.numShrinks = kv.GetNum("numshrinks", this.numShrinks);
		this.diameterMax = kv.GetFloat("diametermax", this.diameterMax);
		this.diameterSafe = kv.GetFloat("diametersafe", this.diameterSafe);
		kv.GetVector("center", this.center, this.center);
	}
}

static ZoneConfig g_ZoneConfig;

static Handle g_ZoneTimer;
static Handle g_ZoneTimerBleed;

static int g_ZonePropRef = INVALID_ENT_REFERENCE;	//Zone prop model
static float g_ZonePropcenterOld[3];	//Where the zone will start moving
static float g_ZonePropcenterNew[3];	//Where the zone will finish moving
static float g_ZoneShrinkStart;			//GameTime where prop start shrinking
static int g_ZoneShrinkLevel;		//Current shrink level, starting from ZoneConfig.numShrinks to 0

static int g_ZoneSpritesLaserBeam;

void Zone_ReadConfig(KeyValues kv)
{
	g_ZoneConfig.ReadConfig(kv);
}

void Zone_Precache()
{
	PrecacheModel(ZONE_MODEL);
	PrecacheSound("mvm/ambient_mp3/mvm_siren.mp3");
	g_ZoneSpritesLaserBeam = PrecacheModel("sprites/laserbeam.vmt", true);
	
	AddFileToDownloadsTable("materials/models/br/br_zone.vmt");
	AddFileToDownloadsTable("materials/models/br/br_zone.vtf");
	
	AddFileToDownloadsTable("models/br/br_zone_test.dx80.vtx");
	AddFileToDownloadsTable("models/br/br_zone_test.dx90.vtx");
	AddFileToDownloadsTable("models/br/br_zone_test.mdl");
	AddFileToDownloadsTable("models/br/br_zone_test.sw.vtx");
	AddFileToDownloadsTable("models/br/br_zone_test.vvd");
}

void Zone_RoundStart()
{
	g_ZoneTimer = null;
	g_ZoneShrinkLevel = g_ZoneConfig.numShrinks;
	g_ZonePropcenterOld = g_ZoneConfig.center;
	g_ZoneShrinkStart = 0.0;
	
	int zone = CreateEntityByName("prop_dynamic");
	if (zone > MaxClients)
	{
		DispatchKeyValueVector(zone, "origin", g_ZonePropcenterOld);
		DispatchKeyValue(zone, "model", ZONE_MODEL);
		DispatchKeyValue(zone, "disableshadows", "1");
		
		SetEntPropFloat(zone, Prop_Send, "m_flModelScale", SquareRoot(g_ZoneConfig.diameterMax / ZONE_DIAMETER));
		
		DispatchSpawn(zone);
		
		SetEntProp(zone, Prop_Send, "m_nSolidType", SOLID_NONE);
		
		SetVariantString("shrink");
		AcceptEntityInput(zone, "SetAnimation");
		
		SetVariantFloat(0.0);
		AcceptEntityInput(zone, "SetPlaybackRate");
		
		g_ZonePropRef = EntIndexToEntRef(zone);
		
		RequestFrame(Frame_UpdateZone, g_ZonePropRef);
	}
}

void Zone_RoundArenaStart()
{
	g_ZoneTimer = CreateTimer(fr_zone_startdisplay.FloatValue, Timer_StartDisplay);
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
		
		float centerNew[3];
		centerNew[0] = (Cosine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		centerNew[1] = (Sine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		AddVectors(centerNew, g_ZonePropcenterOld, centerNew);
		
		//Check if new center is not outside of 'safe' spot
		if (GetVectorDistance(g_ZoneConfig.center, centerNew) <= g_ZoneConfig.diameterSafe / 2.0)
		{
			g_ZonePropcenterNew = centerNew;
			found = true;
		}
	}
	while (!found);
	
	float endPos[3];
	endPos = g_ZonePropcenterNew;
	endPos[2] += 6144.0;
	
	TE_SetupBeamPoints(g_ZonePropcenterNew, endPos, g_ZoneSpritesLaserBeam, 0, 0, 0, fr_zone_display.FloatValue + fr_zone_shrink.FloatValue, 10.0, 10.0, 1, 0.0, {0, 255, 0, 255}, 15); 
	TE_SendToAll();
	
	g_ZoneTimer = CreateTimer(fr_zone_display.FloatValue, Timer_StartShrink);
}

public Action Timer_StartShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	EmitGameSoundToAll(ZONE_SHRINK_SOUND);
	char message[256];
	Format(message, sizeof(message), "%T", "Zone_ShrinkAlert", LANG_SERVER);
	TF2_ShowGameMessage(message, "ico_notify_ten_seconds");
	
	SetVariantFloat(1.0 / (fr_zone_shrink.FloatValue / (ZONE_DURATION / g_ZoneConfig.numShrinks)));
	AcceptEntityInput(g_ZonePropRef, "SetPlaybackRate");
	
	g_ZoneShrinkStart = GetGameTime();
	g_ZoneTimer = CreateTimer(fr_zone_shrink.FloatValue, Timer_FinishShrink);
}

public Action Timer_FinishShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	g_ZoneShrinkLevel--;
	
	g_ZonePropcenterOld = g_ZonePropcenterNew;
	TeleportEntity(g_ZonePropRef, g_ZonePropcenterNew, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantFloat(0.0);
	AcceptEntityInput(g_ZonePropRef, "SetPlaybackRate");
	
	if (g_ZoneShrinkLevel > 0)
		g_ZoneTimer = CreateTimer(fr_zone_nextdisplay.FloatValue, Timer_StartDisplay);
}

public void Frame_UpdateZone(int ref)
{
	int zone = EntRefToEntIndex(ref);
	if (zone <= MaxClients)
		return;
	
	float originZone[3];
	float percentage;
	
	float gametime = GetGameTime();
	if (g_ZoneShrinkStart > gametime - fr_zone_shrink.FloatValue)
	{
		//We in shrinking state, update zone position and diameter
		
		//Progress from level X to level X+1
		percentage = (gametime - g_ZoneShrinkStart) / fr_zone_shrink.FloatValue;
		
		SubtractVectors(g_ZonePropcenterNew, g_ZonePropcenterOld, originZone);	//Distance from start to end
		ScaleVector(originZone, percentage);									//Scale by percentage
		AddVectors(originZone, g_ZonePropcenterOld, originZone);				//Add distance to old center
		TeleportEntity(zone, originZone, NULL_VECTOR, NULL_VECTOR);
		
		//Progress from 1.0 to 0.0 (starting zone to zero size)
		percentage = (float(g_ZoneShrinkLevel) - percentage) / float(g_ZoneConfig.numShrinks);
	}
	else
	{
		//Zone is not shrinking
		GetEntPropVector(g_ZonePropRef, Prop_Data, "m_vecOrigin", originZone);
		percentage = float(g_ZoneShrinkLevel) / float(g_ZoneConfig.numShrinks);
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			float originClient[3];
			GetClientAbsOrigin(client, originClient);
			originClient[2] = originZone[2];
			
			bool outsideZone = GetVectorDistance(originClient, originZone) > g_ZoneConfig.diameterMax * percentage / 2.0;
			
			if (outsideZone && !TF2_IsPlayerInCondition(client, TFCond_Bleeding))
				TF2_MakeBleed(client, client, 9999.0);	//Does no damage
			else if (!outsideZone && FRPlayer(client).OutsideZone)
				TF2_RemoveCondition(client, TFCond_Bleeding);
			
			FRPlayer(client).OutsideZone = outsideZone;
		}
		else if (FRPlayer(client).OutsideZone)
		{
			FRPlayer(client).OutsideZone = false;
		}
	}
	
	RequestFrame(Frame_UpdateZone, ref);
}

public Action Timer_Bleed(Handle timer)
{
	if (g_ZoneTimerBleed != timer)
		return Plugin_Stop;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && FRPlayer(client).OutsideZone)
		{
			float damage = (float(g_ZoneConfig.numShrinks) - float(g_ZoneShrinkLevel)) / float(g_ZoneConfig.numShrinks) * 16.0;
			
			SDKHooks_TakeDamage(client, 0, client, damage, DMG_PREVENT_PHYSICS_FORCE);
		}
	}
	
	return Plugin_Continue;
}