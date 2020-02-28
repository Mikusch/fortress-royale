static int g_BattleBusPropRef = INVALID_ENT_REFERENCE;
static int g_BattleBusCameraRef = INVALID_ENT_REFERENCE;
static Handle g_BattleBusEndTimer;

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

//Eject offsets to pick one at random
static float g_BattleBusEjectOffset[][3] = {
	{-128.0, -128.0, 0.0},
	{-128.0, 0.0, 0.0},
	{-128.0, 128.0, 0.0},
	{0.0, -128.0, 0.0},
	{0.0, 0.0, 0.0},
	{0.0, 128.0, 0.0},
	{128.0, -128.0, 0.0},
	{128.0, 0.0, 0.0},
	{128.0, 128.0, 0.0}
}

static char g_BattleBusClientDropSound[] = ")mvm/mvm_tele_deliver.wav";

static char g_BattleBusModel[PLATFORM_MAX_PATH];
static float g_BattleBusCameraOffset[3];	//Camera offset from bus prop origin
static float g_BattleBusCameraAngles[3];	//Camera angle

static float g_BattleBusCentre[3];	//Centre of the map
static float g_BattleBusLength;		//Diameter of the map
static float g_BattleBusTime;		//How long it takes to go from starting position to end position

static float g_BattleBusOrigin[3];	//Bus starting origin
static float g_BattleBusAngles[3];	//Bus starting angles
static float g_BattleBusVel[3];		//Bus starting vel

void BattleBus_Init()
{
	//TODO move all of this to config
	g_BattleBusModel = "models/props_soho/bus001.mdl";
	
	g_BattleBusCameraOffset[0] = -128.0;
	g_BattleBusCameraOffset[1] = -320.0;
	g_BattleBusCameraOffset[2] = 384.0;
	
	g_BattleBusCameraAngles[0] = 75.0;
	g_BattleBusCameraAngles[1] = 15.0;
	
	g_BattleBusCentre[2] = 4096.0;
	g_BattleBusLength = 10000.0;
	g_BattleBusTime = 20.0;
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
	float angleDirection = GetRandomFloat(0.0, 360.0);
	
	if (angleDirection >= 180.0)
		g_BattleBusAngles[1] = angleDirection - 180.0;
	else
		g_BattleBusAngles[1] = angleDirection + 180.0;
	
	g_BattleBusOrigin[0] = (Cosine(DegToRad(angleDirection)) * g_BattleBusLength / 2.0) + g_BattleBusCentre[0];
	g_BattleBusOrigin[1] = (Sine(DegToRad(angleDirection)) * g_BattleBusLength / 2.0) + g_BattleBusCentre[1];
	g_BattleBusOrigin[2] = g_BattleBusCentre[2];
	
	g_BattleBusVel[0] = -Cosine(DegToRad(angleDirection)) * g_BattleBusLength / g_BattleBusTime;
	g_BattleBusVel[1] = -Sine(DegToRad(angleDirection)) * g_BattleBusLength / g_BattleBusTime;
	
	//Check if it safe to go this path with nothing in the way
	Handle trace = TR_TraceRayEx(g_BattleBusOrigin, g_BattleBusAngles, MASK_SOLID, RayType_Infinite);
	if (TR_DidHit(trace))
	{
		float endPos[3];
		TR_GetEndPosition(endPos, trace);
		
		//int laser = PrecacheModel("sprites/laserbeam.vmt");
		//TE_SetupBeamPoints(g_BattleBusOrigin, endPos, laser, 0, 0, 0, 300.0, 2.0, 2.0, 1, 0.0, {0, 255, 0, 255}, 15); 
		//TE_SendToAll();
		
		//Something is in the way, try agian find new path
		if (GetVectorDistance(g_BattleBusOrigin, endPos) < g_BattleBusLength)
			BattleBus_NewPos();
	}
		
	delete trace;
}

void BattleBus_SpawnProp()
{
	int bus = CreateEntityByName("tf_projectile_rocket");
	if (bus <= MaxClients)
		return;
	
	DispatchSpawn(bus);
	SetEntityModel(bus, g_BattleBusModel);
	g_BattleBusPropRef = EntIndexToEntRef(bus);
	
	SetEntProp(bus, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	int camera = CreateEntityByName("prop_dynamic");
	if (camera <= MaxClients)
		return;
	
	SetEntityModel(camera, MODEL_EMPTY);
	DispatchSpawn(camera);
	g_BattleBusCameraRef = EntIndexToEntRef(camera);
	
	TeleportEntity(camera, g_BattleBusCameraOffset, g_BattleBusCameraAngles, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(camera, "SetParent", bus, bus);
	
	//Teleport bus after camera, so camera can follow where bus is teleporting
	TeleportEntity(bus, g_BattleBusOrigin, g_BattleBusAngles, g_BattleBusVel);
	
	g_BattleBusEndTimer = CreateTimer(g_BattleBusTime, BattleBus_EndProp);
}

public Action BattleBus_EndProp(Handle timer)
{
	if (g_BattleBusEndTimer != timer)
		return;
	
	// Battle bus has reached its destination, eject all players still here a frame later
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).InBattleBus)
			RequestFrame(RequestFrame_EjectClient, GetClientSerial(client));
	}
	
	// Destroy prop
	RemoveEntity(g_BattleBusPropRef);
}

void BattleBus_SpectateBus(int client)
{
	if (g_BattleBusCameraRef != INVALID_ENT_REFERENCE)
	{
		FRPlayer(client).InBattleBus = true;
		SetClientViewEntity(client, g_BattleBusCameraRef);
	}
}

public void RequestFrame_EjectClient(int serial)
{
	int client = GetClientFromSerial(serial);
	if (0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
		BattleBus_EjectClient(client);
}

void BattleBus_EjectClient(int client)
{
	FRPlayer(client).InBattleBus = false;
	
	SetClientViewEntity(client, client);
	
	float ejectOrigin[3], busOrigin[3], clientMins[3], clientMaxs[3];
	GetEntPropVector(g_BattleBusPropRef, Prop_Data, "m_vecAbsOrigin", busOrigin);
	GetClientMins(client, clientMins);
	GetClientMaxs(client, clientMaxs);
	
	bool found;
	ejectOrigin = busOrigin;
	
	//Randomize list
	SortCustom2D(g_BattleBusEjectOffset, sizeof(g_BattleBusEjectOffset), SortCustom_Random);
	
	do
	{
		for (int i = 0; i < sizeof(g_BattleBusEjectOffset); i++)
		{
			float searchOrigin[3];
			AddVectors(ejectOrigin, g_BattleBusEjectOffset[i], searchOrigin);
			
			TR_TraceHull(searchOrigin, searchOrigin, clientMins, clientMaxs, MASK_SOLID);
			if (!TR_DidHit(null))
			{
				//Nothing was hit, safe to launch here
				ejectOrigin = searchOrigin;
				found = true;
				break;
			}
		}
		
		//If still could not be found, try again but higher up
		if (!found)
		{
			float searchOrigin[3]
			searchOrigin = ejectOrigin;
			searchOrigin[2] += 128.0;
			
			if (TR_PointOutsideWorld(searchOrigin))
				found = true;	//fuck it
			else
				ejectOrigin = searchOrigin;
		}
	}
	while (!found);
	
	TeleportEntity(client, ejectOrigin, NULL_VECTOR, NULL_VECTOR);
	EmitSoundToAll(g_BattleBusClientDropSound, client);
	
	RequestFrame(RequestFrame_DeployParachute, GetClientSerial(client));
}

void RequestFrame_DeployParachute(int serial)
{
	int client = GetClientFromSerial(serial);
	if (0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
		TF2_AddCondition(client, TFCond_Parachute);
}

public int SortCustom_Random(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	return GetRandomInt(0, 1) ? -1 : 1;
}