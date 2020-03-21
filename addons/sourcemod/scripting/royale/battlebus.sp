enum struct BattleBusConfig
{
	char model[PLATFORM_MAX_PATH];
	int skin;
	float center[3];
	float diameter;
	float time;
	float height;
	float cameraOffset[3];
	float cameraAngles[3];
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		
		this.skin = kv.GetNum("skin", this.skin);
		kv.GetVector("center", this.center, this.center);
		this.diameter = kv.GetFloat("diameter", this.diameter);
		this.time = kv.GetFloat("time", this.time);
		this.height = kv.GetFloat("height", this.height);
		kv.GetVector("camera_offset", this.cameraOffset, this.cameraOffset);
		kv.GetVector("camera_angles", this.cameraAngles, this.cameraAngles);
	}
}

static int g_BattleBusPropRef = INVALID_ENT_REFERENCE;
static int g_BattleBusCameraRef = INVALID_ENT_REFERENCE;
static Handle g_BattleBusEndTimer;
static BattleBusConfig g_CurrentBattleBusConfig;

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

//Eject offsets to pick one at random
static float g_BattleBusEjectOffset[][3] =  {
	{ -128.0, -128.0, 0.0 }, 
	{ -128.0, 0.0, 0.0 }, 
	{ -128.0, 128.0, 0.0 }, 
	{ 0.0, -128.0, 0.0 }, 
	{ 0.0, 0.0, 0.0 }, 
	{ 0.0, 128.0, 0.0 }, 
	{ 128.0, -128.0, 0.0 }, 
	{ 128.0, 0.0, 0.0 }, 
	{ 128.0, 128.0, 0.0 }
}

static float g_BattleBusOrigin[3];		//Bus starting origin
static float g_BattleBusAngles[3];		//Bus starting angles
static float g_BattleBusVelocity[3];	//Bus starting velocity

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
}

void BattleBus_ReadConfig(KeyValues kv)
{
	g_CurrentBattleBusConfig.ReadConfig(kv);
}

void BattleBus_NewPos()
{
	g_BattleBusPropRef = INVALID_ENT_REFERENCE;
	g_BattleBusCameraRef = INVALID_ENT_REFERENCE;
	
	//Create new pos to spawn bus for this round
	float angleDirection = GetRandomFloat(0.0, 360.0);
	
	if (angleDirection >= 180.0)
		g_BattleBusAngles[1] = angleDirection - 180.0;
	else
		g_BattleBusAngles[1] = angleDirection + 180.0;
	
	g_BattleBusOrigin[0] = (Cosine(DegToRad(angleDirection)) * g_CurrentBattleBusConfig.diameter / 2.0) + g_CurrentBattleBusConfig.center[0];
	g_BattleBusOrigin[1] = (Sine(DegToRad(angleDirection)) * g_CurrentBattleBusConfig.diameter / 2.0) + g_CurrentBattleBusConfig.center[1];
	g_BattleBusOrigin[2] = g_CurrentBattleBusConfig.center[2];
	
	g_BattleBusVelocity[0] = -Cosine(DegToRad(angleDirection)) * g_CurrentBattleBusConfig.diameter / g_CurrentBattleBusConfig.time;
	g_BattleBusVelocity[1] = -Sine(DegToRad(angleDirection)) * g_CurrentBattleBusConfig.diameter / g_CurrentBattleBusConfig.time;
	
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
		if (GetVectorDistance(g_BattleBusOrigin, endPos) < g_CurrentBattleBusConfig.diameter)
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
	SetEntityModel(bus, g_CurrentBattleBusConfig.model);
	g_BattleBusPropRef = EntIndexToEntRef(bus);
	
	SetEntProp(bus, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	int camera = CreateEntityByName("prop_dynamic");
	if (camera <= MaxClients)
		return;
	
	SetEntityModel(camera, MODEL_EMPTY);
	DispatchSpawn(camera);
	g_BattleBusCameraRef = EntIndexToEntRef(camera);
	
	TeleportEntity(camera, g_CurrentBattleBusConfig.cameraOffset, g_CurrentBattleBusConfig.cameraAngles, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(camera, "SetParent", bus, bus);
	
	//Teleport bus after camera, so camera can follow where bus is teleporting
	TeleportEntity(bus, g_BattleBusOrigin, g_BattleBusAngles, g_BattleBusVelocity);
	
	g_BattleBusEndTimer = CreateTimer(g_CurrentBattleBusConfig.time, BattleBus_EndProp);
}

public Action BattleBus_EndProp(Handle timer)
{
	if (g_BattleBusEndTimer != timer)
		return;
	
	// Battle bus has reached its destination, eject all players still here a frame later
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).PlayerState == PlayerState_BattleBus)
			RequestFrame(RequestFrame_EjectClient, GetClientSerial(client));
	}
	
	// Destroy prop
	if (g_BattleBusPropRef != INVALID_ENT_REFERENCE)
		RemoveEntity(g_BattleBusPropRef);
}

void BattleBus_SpectateBus(int client)
{
	if (g_BattleBusCameraRef != INVALID_ENT_REFERENCE)
	{
		FRPlayer(client).PlayerState = PlayerState_BattleBus;
		SetClientViewEntity(client, g_BattleBusCameraRef);
		PrintHintText(client, "%T", "BattleBus_HowToDrop", LANG_SERVER);
	}
}

public void RequestFrame_EjectClient(int serial)
{
	int client = GetClientFromSerial(serial);
	if (0 < client <= MaxClients && IsClientInGame(client) && FRPlayer(client).PlayerState == PlayerState_BattleBus)
		BattleBus_EjectClient(client);
}

void BattleBus_EjectClient(int client)
{
	if (g_BattleBusPropRef == INVALID_ENT_REFERENCE)
		return;
	
	FRPlayer(client).PlayerState = PlayerState_Alive;
	TF2_ChangeClientTeam(client, TFTeam_Alive);
	TF2_RespawnPlayer(client);
	
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
	TF2_AddCondition(client, TFCond_TeleportedGlow, 8.0);
	EmitSoundToAll(g_BattleBusClientDropSound, g_BattleBusPropRef);
	
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
