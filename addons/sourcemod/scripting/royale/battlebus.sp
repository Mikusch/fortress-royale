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

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (FRPlayer(client).InBattleBus && buttons & IN_JUMP)
		BattleBus_EjectClient(client);
}

public void BattleBus_OnDestPathTrackSpawn(int entity)
{
	HookSingleEntityOutput(entity, "OnPass", EntityOutput_OnPass, true);
}

public void BattleBus_OnPropSpawn(int entity)
{
	g_BattleBusPropRef = EntIndexToEntRef(entity);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		BattleBus_SpectateBus(client);
	}
}

public void BattleBus_SpectateBus(int client)
{
	if (IsClientInGame(client) && g_BattleBusPropRef != INVALID_ENT_REFERENCE && !g_IsRoundActive)
	{
		FRPlayer(client).InBattleBus = true;
		SetClientViewEntity(client, g_BattleBusPropRef);
	}
}

public void BattleBus_OnDropDestinationSpawn(int entity)
{
	g_BattleBusDropTeleportDestRef = EntIndexToEntRef(entity);
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

public void BattleBus_EjectClient(int client)
{
	FRPlayer(client).InBattleBus = false;
	
	RequestFrame(RequestFrame_DeployParachute, client);
	
	SetClientViewEntity(client, client);
	
	float origin[3];
	GetEntPropVector(g_BattleBusDropTeleportDestRef, Prop_Data, "m_vecAbsOrigin", origin);
	TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	
	EmitSoundToAll(g_BattleBusClientDropSound, client);
}

public void RequestFrame_DeployParachute(int client)
{
	TF2_AddCondition(client, TFCond_Parachute);
}

public void BattleBus_Precache()
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
