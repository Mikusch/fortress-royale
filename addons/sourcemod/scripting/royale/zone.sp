enum struct ZoneConfig
{
	int numShrinks;		/**< How many shrinks should be done */
	float diameterMax;	/**< Starting zone size */
	float diameterSafe; /**< Centre of the zone must always be inside this diameter of centre of map */
	float center[3];	/**< Centre of the map, and starting zone position */
	
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
static float g_ZoneCentreProp[3];	//Centre of the prop/zone
static int g_ZoneShrinkLevel;		//Current shrink level, starting from ZoneConfig.numShrinks to 0

static int g_ZoneSpritesLaserBeam;
static int g_ZoneSpritesGlow;

void Zone_ReadConfig(KeyValues kv)
{
	g_ZoneConfig.ReadConfig(kv);
}

void Zone_Precache()
{
	g_ZoneSpritesLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	g_ZoneSpritesGlow = PrecacheModel("materials/sprites/glow01.vmt", true);
}

void Zone_RoundStart()
{
	g_ZoneTimer = null;
	g_ZoneShrinkLevel = g_ZoneConfig.numShrinks;
	g_ZoneCentreProp = g_ZoneConfig.center;
}

void Zone_RoundArenaStart()
{
	g_ZoneTimer = CreateTimer(5.0, Timer_StartDisplay);
	
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
		AddVectors(centerNew, g_ZoneCentreProp, centerNew);
		
		//Check if new centre is not outside of 'safe' spot
		if (GetVectorDistance(g_ZoneConfig.center, centerNew) <= g_ZoneConfig.diameterSafe / 2.0)
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