static Handle g_ZoneTimer;

static float g_ZoneCentreMap[3];	//Centre of the map
static float g_ZoneCentreProp[3];	//Centre of the prop/zone

static int g_ZoneShrinkLevel;
static int g_ZoneShrinkMax;

static float g_ZoneDiameterMax;
static float g_ZoneDiameterMaxSafe;

static int g_ZoneSpritesLaserBeam;
static int g_ZoneSpritesGlow;

void Zone_Precache()
{
	g_ZoneSpritesLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	g_ZoneSpritesGlow = PrecacheModel("materials/sprites/glow01.vmt", true);
}

void Zone_RoundStart()
{
	g_ZoneTimer = null;
	
	//TODO move all of this to config
	g_ZoneShrinkLevel = 4;
	g_ZoneShrinkMax = 4;
	
	g_ZoneDiameterMax = 4000.0;
	g_ZoneDiameterMaxSafe = 2500.0;
	
	//g_ZoneCentreMap = g_CurrentBattleBusConfig.center;
	//g_ZoneCentreProp = g_CurrentBattleBusConfig.center;
}

void Zone_RoundArenaStart()
{
	g_ZoneTimer = CreateTimer(5.0, Timer_StartDisplay);
	
	int color[4] = { 0, 255, 0, 255 };
	TE_SetupBeamRingPoint(g_ZoneCentreMap, g_ZoneDiameterMax, g_ZoneDiameterMax+10.0, g_ZoneSpritesLaserBeam, g_ZoneSpritesGlow, 0, 10, 25.0, 10.0, 0.0, color, 10, 0);
	TE_SendToAll();
	
	color = { 255, 0, 0, 255 };
	TE_SetupBeamRingPoint(g_ZoneCentreMap, g_ZoneDiameterMaxSafe, g_ZoneDiameterMaxSafe+10.0, g_ZoneSpritesLaserBeam, g_ZoneSpritesGlow, 0, 10, 25.0, 10.0, 0.0, color, 10, 0);
	TE_SendToAll();
}

public Action Timer_StartDisplay(Handle timer)
{
	if (g_ZoneTimer != timer)
		return;
	
	g_ZoneShrinkLevel--;
	
	//Calculate new diameter of zone
	float diameter = float(g_ZoneShrinkLevel) / float(g_ZoneShrinkMax) * g_ZoneDiameterMax;
	
	//Max diameter to walk away from previous center
	float diameterSearch = 1.0 / float(g_ZoneShrinkMax) * g_ZoneDiameterMax;
	
	bool found = false;
	do
	{
		//Roll for random angle and offset position from center
		float angleRandom = GetRandomFloat(0.0, 360.0);
		float diameterRandom = GetRandomFloat(0.0, diameterSearch);
		
		float centerNew[3];
		centerNew[0] = (Cosine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		centerNew[1] = (Sine(DegToRad(angleRandom)) * diameterRandom / 2.0);
		AddVectors(centerNew, g_ZoneCentreProp, centerNew);
		
		//Check if new centre is not outside of 'safe' spot
		if (GetVectorDistance(g_ZoneCentreMap, centerNew) <= g_ZoneDiameterMaxSafe / 2.0)
		{
			g_ZoneCentreProp = centerNew;
			found = true;
		}
	}
	while (!found);
	
	int color[4] = { 0, 0, 255, 255 };
	TE_SetupBeamRingPoint(g_ZoneCentreProp, diameter, diameter+10.0, g_ZoneSpritesLaserBeam, g_ZoneSpritesGlow, 0, 10, 25.0, 10.0, 0.0, color, 10, 0);
	TE_SendToAll();
	
	if (g_ZoneShrinkLevel > 1)
		g_ZoneTimer = CreateTimer(5.0, Timer_StartDisplay);
}