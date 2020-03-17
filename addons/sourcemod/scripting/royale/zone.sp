#define ZONE_MODEL			"models/br/br_zone.mdl"
#define ZONE_DIAMETER	14500.0
#define ZONE_DURATION	65.0

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
static int g_ZonePropRef = INVALID_ENT_REFERENCE;	//Zone prop model
static float g_ZonePropcenterOld[3];	//Where the zone will start moving
static float g_ZonePropcenterNew[3];	//Where the zone will finish moving
static float g_ZoneShrinkStart;			//GameTime where prop start shrinking
static int g_ZoneShrinkLevel;		//Current shrink level, starting from ZoneConfig.numShrinks to 0

static int g_ZoneSpritesLaserBeam;
static int g_ZoneSpritesGlow;

void Zone_ReadConfig(KeyValues kv)
{
	g_ZoneConfig.ReadConfig(kv);
}

void Zone_Precache()
{
	PrecacheModel(ZONE_MODEL);
	g_ZoneSpritesLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	g_ZoneSpritesGlow = PrecacheModel("materials/sprites/glow01.vmt", true);
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
		
		//SetEntPropFloat(zone, Prop_Send, "m_flModelScale", SquareRoot(g_ZoneConfig.diameterMax / ZONE_DIAMETER));	//TODO remove me
		
		DispatchSpawn(zone);
		
		SetEntProp(zone, Prop_Send, "m_nSolidType", SOLID_NONE);
		
		SetVariantString("shrink");
		AcceptEntityInput(zone, "SetAnimation");
		
		SetVariantFloat(0.0);
		AcceptEntityInput(zone, "SetPlaybackRate");
		
		//SetEntPropFloat(zone, Prop_Send, "m_flCycle", 1.0 - (g_ZoneConfig.diameterMax / ZONE_DIAMETER));
		
		g_ZonePropRef = EntIndexToEntRef(zone);
		
		RequestFrame(Frame_UpdateZone, g_ZonePropRef);
	}
}

void Zone_RoundArenaStart()
{
	g_ZoneTimer = CreateTimer(fr_zone_startdisplay.FloatValue, Timer_StartDisplay);
	
	int color[4] = { 0, 255, 0, 255 };
	TE_SetupBeamRingPoint(g_ZoneConfig.center, g_ZoneConfig.diameterMax, g_ZoneConfig.diameterMax+10.0, g_ZoneSpritesLaserBeam, g_ZoneSpritesGlow, 0, 10, 25.0, 10.0, 0.0, color, 10, 0);
	TE_SendToAll();
	
	color = { 255, 0, 0, 255 };
	TE_SetupBeamRingPoint(g_ZoneConfig.center, g_ZoneConfig.diameterSafe, g_ZoneConfig.diameterSafe+10.0, g_ZoneSpritesLaserBeam, g_ZoneSpritesGlow, 0, 10, 25.0, 10.0, 0.0, color, 10, 0);
	TE_SendToAll();
}

public Action Timer_StartDisplay(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	g_ZoneShrinkLevel--;
	
	//Calculate new diameter of zone
	float diameter = float(g_ZoneShrinkLevel) / float(g_ZoneConfig.numShrinks) * g_ZoneConfig.diameterMax;
	
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
	
	int color[4] = { 0, 0, 255, 255 };
	TE_SetupBeamRingPoint(g_ZonePropcenterNew, diameter, diameter+10.0, g_ZoneSpritesLaserBeam, g_ZoneSpritesGlow, 0, 10, 25.0, 10.0, 0.0, color, 10, 0);
	TE_SendToAll();
	
	float endPos[3];
	endPos = g_ZonePropcenterNew;
	endPos[2] += 6144.0;
	
	int laser = PrecacheModel("sprites/laserbeam.vmt");
	TE_SetupBeamPoints(g_ZonePropcenterNew, endPos, laser, 0, 0, 0, fr_zone_display.FloatValue + fr_zone_shrink.FloatValue, 10.0, 10.0, 1, 0.0, {0, 255, 0, 255}, 15); 
	TE_SendToAll();
	
	g_ZoneTimer = CreateTimer(fr_zone_display.FloatValue, Timer_StartShrink);
}

public Action Timer_StartShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	SetVariantFloat(fr_zone_shrink.FloatValue * g_ZoneConfig.numShrinks / ZONE_DURATION);
	AcceptEntityInput(g_ZonePropRef, "SetPlaybackRate");
	
	g_ZoneShrinkStart = GetGameTime();
	g_ZoneTimer = CreateTimer(fr_zone_shrink.FloatValue, Timer_FinishShrink);
}

public Action Timer_FinishShrink(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
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
	
	RequestFrame(Frame_UpdateZone, ref);
	
	float gametime = GetGameTime();
	if (g_ZoneShrinkStart < gametime - fr_zone_shrink.FloatValue)
		return;
	
	//We in shrinking state, update zone position and diameter
	
	//Progress from level X to level X+1
	float percentage = (gametime - g_ZoneShrinkStart) / fr_zone_shrink.FloatValue;
	
	float center[3];
	SubtractVectors(g_ZonePropcenterNew, g_ZonePropcenterOld, center);	//Distance from start to end
	ScaleVector(center, percentage);									//Scale by percentage
	AddVectors(center, g_ZonePropcenterOld, center);					//Add distance to old center
	TeleportEntity(zone, center, NULL_VECTOR, NULL_VECTOR);
}