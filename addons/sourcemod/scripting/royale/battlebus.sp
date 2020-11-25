/*
 * Copyright (C) 2020  Mikusch & 42
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

enum struct BattleBusConfig
{
	char model[PLATFORM_MAX_PATH];
	int skin;
	float height;
	float diameter;
	float time;
	float cameraOffset[3];
	float cameraAngles[3];
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		
		this.skin = kv.GetNum("skin", this.skin);
		this.height = kv.GetFloat("height", this.height);
		this.diameter = kv.GetFloat("diameter", this.diameter);
		this.time = kv.GetFloat("time", this.time);
		kv.GetVector("camera_offset", this.cameraOffset, this.cameraOffset);
		kv.GetVector("camera_angles", this.cameraAngles, this.cameraAngles);
	}
}

static int g_BattleBusPropRef = INVALID_ENT_REFERENCE;
static int g_BattleBusCameraRef = INVALID_ENT_REFERENCE;
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
};

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

void BattleBus_NewPos(float diameter = 0.0)
{
	g_BattleBusPropRef = INVALID_ENT_REFERENCE;
	g_BattleBusCameraRef = INVALID_ENT_REFERENCE;
	
	//Get origin by zone's current origin
	float origin[3];
	Zone_GetNewCenter(origin);
	
	//Default diameter
	if (diameter <= 0.0)
		diameter = g_CurrentBattleBusConfig.diameter;
	
	//Create new pos to spawn bus for this round
	float angleDirection = GetRandomFloat(0.0, 360.0);
	
	if (angleDirection >= 180.0)
		g_BattleBusAngles[1] = angleDirection - 180.0;
	else
		g_BattleBusAngles[1] = angleDirection + 180.0;
	
	g_BattleBusOrigin[0] = (Cosine(DegToRad(angleDirection)) * diameter / 2.0) + origin[0];
	g_BattleBusOrigin[1] = (Sine(DegToRad(angleDirection)) * diameter / 2.0) + origin[1];
	g_BattleBusOrigin[2] = g_CurrentBattleBusConfig.height;
	
	g_BattleBusVelocity[0] = -Cosine(DegToRad(angleDirection)) * diameter / g_CurrentBattleBusConfig.time;
	g_BattleBusVelocity[1] = -Sine(DegToRad(angleDirection)) * diameter / g_CurrentBattleBusConfig.time;
	
	//Check if it safe to go this path with nothing in the way
	Handle trace = TR_TraceRayEx(g_BattleBusOrigin, g_BattleBusAngles, MASK_SOLID, RayType_Infinite);
	if (TR_DidHit(trace))
	{
		float endPos[3];
		TR_GetEndPosition(endPos, trace);
		
		//Something is in the way, try agian find new path
		if (GetVectorDistance(g_BattleBusOrigin, endPos) < g_CurrentBattleBusConfig.diameter)
			BattleBus_NewPos();
	}
	
	delete trace;
}

void BattleBus_SpawnPlayerBus()
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
	
	CreateTimer(g_CurrentBattleBusConfig.time, BattleBus_EndPlayerBus, g_BattleBusPropRef, TIMER_FLAG_NO_MAPCHANGE);
}

public Action BattleBus_EndPlayerBus(Handle timer, int bus)
{
	if (!IsValidEntity(bus))
		return;
	
	// Battle bus has reached its destination, eject all players still here
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).PlayerState == PlayerState_BattleBus)
			BattleBus_EjectClient(client);
	}
	
	// Destroy prop
	RemoveEntity(bus);
}

void BattleBus_SpectateBus(int client)
{
	if (g_BattleBusCameraRef != INVALID_ENT_REFERENCE)
	{
		FRPlayer(client).PlayerState = PlayerState_BattleBus;
		SetClientViewEntity(client, g_BattleBusCameraRef);
		ShowKeyHintText(client, "%t", "BattleBus_HowToDrop");
	}
}

void BattleBus_EjectClient(int client)
{
	int bus = EntRefToEntIndex(g_BattleBusPropRef);
	if (bus == INVALID_ENT_REFERENCE)
		return;
	
	//If player havent selected a class, pick random class for em
	//this is so that player can actually spawn into map, otherwise nothing happens
	if (view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass")) == TFClass_Unknown)
		SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
	
	//Respawn into alive team, removing ghost
	FRPlayer(client).PlayerState = PlayerState_Parachute;
	TF2_ChangeClientTeamSilent(client, TFTeam_Alive);
	TF2_RespawnPlayer(client);
	
	SetClientViewEntity(client, client);
	
	float ejectOrigin[3], busOrigin[3], clientMins[3], clientMaxs[3];
	GetEntPropVector(bus, Prop_Data, "m_vecAbsOrigin", busOrigin);
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
			float searchOrigin[3];
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
	EmitSoundToAll(g_BattleBusClientDropSound, bus);
	
	FRPlayer(client).SecToDeployParachute = fr_sectodeployparachute.IntValue;
	PrintHintText(client, "%t", "BattleBus_SecToDeployParachute", FRPlayer(client).SecToDeployParachute);
	CreateTimer(1.0, Timer_SecToDeployParachute, GetClientSerial(client));
}

public Action Timer_SecToDeployParachute(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (0 < client <= MaxClients && IsClientInGame(client))
	{
		if (FRPlayer(client).PlayerState == PlayerState_Parachute && !TF2_IsPlayerInCondition(client, TFCond_Parachute))
		{
			FRPlayer(client).SecToDeployParachute--;
			if (FRPlayer(client).SecToDeployParachute > 0)
			{
				PrintHintText(client, "%t", "BattleBus_SecToDeployParachute", FRPlayer(client).SecToDeployParachute);
				CreateTimer(1.0, Timer_SecToDeployParachute, serial);
			}
			else
			{
				TF2_AddCondition(client, TFCond_Parachute);
				CreateTimer(0.1, Timer_SecToDeployParachute, serial);
			}
		}
		else
		{
			FRPlayer(client).SecToDeployParachute = 0;
		}
	}
}

public int SortCustom_Random(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	return GetRandomInt(0, 1) ? -1 : 1;
}

void BattleBus_SpawnLootBus()
{
	float diameter = Zone_GetNewDiameter();
	if (diameter <= 0.0)
		return;
	
	int bus = CreateEntityByName("tf_projectile_rocket");
	if (bus <= MaxClients)
		return;
	
	DispatchSpawn(bus);
	bus = EntIndexToEntRef(bus);
	
	SetEntityModel(bus, g_CurrentBattleBusConfig.model);
	SetEntProp(bus, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	BattleBus_NewPos(diameter);
	
	TeleportEntity(bus, g_BattleBusOrigin, g_BattleBusAngles, g_BattleBusVelocity);
	
	char message[256];
	Format(message, sizeof(message), "%T", "BattleBus_IncomingCrate", LANG_SERVER);
	TF2_ShowGameMessage(message, "ico_build");
	
	CreateTimer(GetRandomFloat(0.0, g_CurrentBattleBusConfig.time), BattleBus_SpawnLootCrate, bus, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(g_CurrentBattleBusConfig.time, BattleBus_EndLootBus, bus, TIMER_FLAG_NO_MAPCHANGE);
}

public Action BattleBus_SpawnLootCrate(Handle timer, int bus)
{
	if (!IsValidEntity(bus))
		return;
	
	LootCrate loot;
	LootCrate_GetBus(loot);
	
	//Get vectors and convert to string, as that how config is done
	float origin[3], angles[3];
	GetEntPropVector(bus, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(bus, Prop_Data, "m_angRotation", angles);
	VectorToString(origin, loot.origin, sizeof(loot.origin));
	VectorToString(angles, loot.angles, sizeof(loot.angles));
	
	Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateBus, true);
}

public Action BattleBus_EndLootBus(Handle timer, int bus)
{
	// Destroy prop
	if (IsValidEntity(bus))
		RemoveEntity(bus);
}
