static int g_BattleBusPropRef = INVALID_ENT_REFERENCE;
static int g_BattleBusDropTeleportDestRef = INVALID_ENT_REFERENCE;

static char g_BattleBusMusic[][] =  {
	")ui/cyoa_musicdrunkenpipebomb.mp3", 
	")ui/cyoa_musicfasterthanaspeedingbullet.mp3", 
	")ui/cyoa_musicintruderalert.mp3", 
	")ui/cyoa_musicmedic.mp3", 
	")ui/cyoa_musicmoregun.mp3", 
	")ui/cyoa_musicmoregun2.mp3", 
	")ui/cyoa_musicplayingwithdanger.mp3", 
	")ui/cyoa_musicrightbehindyou.mp3", 
	")ui/cyoa_musicteamfortress2.mp3"
};

static char g_BattleBusHornSounds[][] =  {
	")ambient_mp3/mvm_warehouse/car_horn_01.mp3", 
	")ambient_mp3/mvm_warehouse/car_horn_02.mp3", 
	")ambient_mp3/mvm_warehouse/car_horn_03.mp3", 
	")ambient_mp3/mvm_warehouse/car_horn_04.mp3", 
	")ambient_mp3/mvm_warehouse/car_horn_05.mp3"
};

static char g_BattleBusClientDropSound[] = ")mvm/mvm_tele_deliver.wav";
static char g_BattleBusModel[] = "models/props_soho/bus001.mdl";	//TODO move this to config

static int g_BattleBusProp;			//Entity prop
static float g_BattleBusCentre[3];	//Centre of the map
static float g_BattleBusRadius;		//Radius of the map

static float g_BattleBusOrigin[3];	//Bus starting origin
static float g_BattleBusAngles[3];	//Bus starting angles
//static float g_BattleBusVel[3];		//Bus starting vel

void BattleBus_Init()
{
	//TODO move this to config
	g_BattleBusCentre[2] = 4096.0;
	g_BattleBusRadius = 5000.0;
}

void BattleBus_Precache()
{
	for (int i = 0; i < sizeof(g_BattleBusMusic); i++)
	{
		PrecacheSound(g_BattleBusMusic[i]);
	}
	
	for (int i = 0; i < sizeof(g_BattleBusHornSounds); i++)
	{
		PrecacheSound(g_BattleBusHornSounds[i]);
	}
	
	PrecacheSound(g_BattleBusClientDropSound);
	
	PrecacheModel(g_BattleBusModel);
}

void BattleBus_NewPos()
{
	//Create new pos to spawn bus for this round
	float angleDirection = -1.0;
	
	do
	{
		angleDirection = GetRandomFloat(0.0, 360.0);
		
		if (angleDirection >= 180.0)
			g_BattleBusAngles[1] = angleDirection - 180.0;
		else
			g_BattleBusAngles[1] = angleDirection + 180.0;
		
		g_BattleBusOrigin[0] = (Cosine(DegToRad(angleDirection)) * g_BattleBusRadius) + g_BattleBusCentre[0];
		g_BattleBusOrigin[1] = (Sine(DegToRad(angleDirection)) * g_BattleBusRadius) + g_BattleBusCentre[1];
		g_BattleBusOrigin[2] = g_BattleBusCentre[2];
		
		Handle trace = TR_TraceRayFilterEx(g_BattleBusOrigin, g_BattleBusAngles, MASK_SOLID, RayType_Infinite, BattleBus_TraceFilter, g_BattleBusProp);
		
		if (TR_DidHit(trace))
		{
			float endPos[3];
			TR_GetEndPosition(endPos, trace);
			
			PrintToChatAll("Start pos %.2f %.2f %.2f", g_BattleBusOrigin[0], g_BattleBusOrigin[1], g_BattleBusOrigin[2]);
			PrintToChatAll("End pos %.2f %.2f %.2f", endPos[0], endPos[1], endPos[2]);
			PrintToChatAll("angle %.2f", g_BattleBusAngles[1]);
			
			int laser = PrecacheModel("sprites/laserbeam.vmt");
			TE_SetupBeamPoints(g_BattleBusOrigin, endPos, laser, 0, 0, 0, 300.0, 2.0, 2.0, 1, 0.0, {0, 255, 0, 255}, 15); 
			TE_SendToAll();
			
			//Check if hit something thats in the way, try agian find new path
			if (GetVectorDistance(g_BattleBusOrigin, endPos) < g_BattleBusRadius * 2.0)
				angleDirection = -1.0;
		}
		
		delete trace;
	}
	while (angleDirection == -1.0);
}

void BattleBus_SpawnProp()
{
	g_BattleBusProp = CreateEntityByName("tf_projectile_rocket");
	if (g_BattleBusProp <= MaxClients)
		return;
	
	DispatchSpawn(g_BattleBusProp);
	
	SetEntityModel(g_BattleBusProp, g_BattleBusModel);
	SetEntProp(g_BattleBusProp, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	TeleportEntity(g_BattleBusProp, g_BattleBusOrigin, g_BattleBusAngles, NULL_VECTOR);
}

public bool BattleBus_TraceFilter(int entity, int contentsMask, any prop)
{
	return entity != prop;
}

void BattleBus_SpectateBus(int client)
{
	if (IsClientInGame(client) && g_BattleBusPropRef != INVALID_ENT_REFERENCE && !g_IsRoundActive)
	{
		FRPlayer(client).InBattleBus = true;
		SetClientViewEntity(client, g_BattleBusPropRef);
	}
}

public void EntityOutput_OnPass(const char[] output, int caller, int activator, float delay)
{
	// Battle bus has reached its destination, eject all players still here
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).InBattleBus)
			BattleBus_EjectClient(client);
	}
}

void BattleBus_EjectClient(int client)
{
	FRPlayer(client).InBattleBus = false;
	
	RequestFrame(RequestFrame_DeployParachute, client);
	
	SetClientViewEntity(client, client);
	
	float origin[3];
	GetEntPropVector(g_BattleBusDropTeleportDestRef, Prop_Data, "m_vecAbsOrigin", origin);
	TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	
	EmitSoundToAll(g_BattleBusClientDropSound, client);
}

void RequestFrame_DeployParachute(int client)
{
	TF2_AddCondition(client, TFCond_Parachute);
}