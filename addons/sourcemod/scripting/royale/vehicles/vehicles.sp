//TODO move defines to config
#define VEHICLE_ROTATE_SPEED	8.0
#define VEHICLE_ROTATE_MAX		50.0
#define VEHICLE_SPEED_FORWARD	30.0
#define VEHICLE_SPEED_BACKWARD	25.0
#define VEHICLE_SPEED_MAX		400.0

enum struct Vehicle
{
	int entity;	//Entity ref
	int client; //Client riding on this vehicle
}

static ArrayList g_Vehicles;

void Vehicles_Init()
{
	g_Vehicles = new ArrayList(sizeof(Vehicle));
}

void Vehicles_Create(int client)
{
	float position[3], angles[3];
	GetClientEyePosition(client, position);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(position))
		return;
	
	int entity = CreateEntityByName("prop_physics_override");
	if (!IsValidEntity(entity))
		return;
	
	//TODO config for model
	PrecacheModel("models/props_vehicles/pickup03.mdl");
	SetEntityModel(entity, "models/props_vehicles/pickup03.mdl");
	
	DispatchKeyValueFloat(entity, "massScale", 10.0);
	DispatchKeyValueFloat(entity, "physdamagescale", 1.0);
	
	SetEntProp(entity, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_NO);
	
	if (!DispatchSpawn(entity) || !MoveEntityToClientEye(entity, client))
	{
		RemoveEntity(entity);
		return;
	}
	
	AcceptEntityInput(entity, "EnableMotion");
	SDKHook(entity, SDKHook_Touch, Vehicles_Touch);
	
	Vehicle vehicle;
	vehicle.entity = EntIndexToEntRef(entity);
	g_Vehicles.PushArray(vehicle);
}

void Vehicles_OnEntityDestroyed(int entity)
{
	Vehicle vehicle;
	if (Vehicles_GetByEntity(EntIndexToEntRef(entity), vehicle))
	{
		if (0 < vehicle.client <= MaxClients && IsClientInGame(vehicle.client) && IsPlayerAlive(vehicle.client))
		{
			AcceptEntityInput(vehicle.client, "ClearParent");
			Vehicles_RemoveByClient(vehicle.client);
		}
	}
}

public Action Vehicles_Touch(int entity, int client)
{
	if (client <= 0 || client > MaxClients)
		return;
	
	entity = EntIndexToEntRef(entity);
	
	Vehicle vehicle;
	if (!Vehicles_GetByEntity(entity, vehicle))
		return;
	
	//Someone already taken this vehicle
	if (0 < vehicle.client <= MaxClients && IsClientInGame(vehicle.client) && IsPlayerAlive(vehicle.client))
		return;
	
	//Set client to ride this vehicle
	vehicle.client = client;
	Vehicles_SetByEntity(vehicle);
	SDKHook(client, SDKHook_PreThink, Vehicles_PreThink);
	
	//Force client duck and dont move
	SetEntProp(client, Prop_Send, "m_bDucking", true);
	SetEntProp(client, Prop_Send, "m_bDucked", true);
	SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);
	SetEntityMoveType(client, MOVETYPE_NONE);
	
	SetVariantString("!activator");
	AcceptEntityInput(client, "SetParent", entity, entity);
	
	float offset[3], angles[3];
	offset = view_as<float>({ 24.0, 12.0, 40.0 });
	GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);
	
	//After client is parented, origin is now the offset of prop
	TeleportEntity(client, offset, angles, NULL_VECTOR);
}

public Action Vehicles_PreThink(int client)
{
	Vehicle vehicle;
	if (!Vehicles_GetByClient(client, vehicle) || !IsValidEntity(vehicle.entity))
	{
		Vehicles_RemoveByClient(client);
		SDKUnhook(client, SDKHook_PreThink, Vehicles_PreThink);
		return;
	}
	
	if (IsPlayerAlive(client))
	{
		int buttons = GetClientButtons(client);
		
		float angles[3], velocity[3], angVelocity[3];
		GetEntPropVector(vehicle.entity, Prop_Data, "m_angRotation", angles);
		SDKCall_GetVelocity(vehicle.entity, velocity, angVelocity);
		
		//Reduce velocity and angVelocity down to not have entity act like riding on ice
		ScaleVector(velocity, 0.95);
		ScaleVector(angVelocity, 0.95);
		
		//Prevent barrel rolls
		angVelocity[0] -= angles[2] * 0.5;	//side
		angVelocity[1] -= angles[0] * 0.5;	//front
		
		if (buttons & IN_MOVELEFT && angVelocity[2] < VEHICLE_ROTATE_MAX)
		{
			angVelocity[2] += VEHICLE_ROTATE_SPEED;
			if (angVelocity[2] > VEHICLE_ROTATE_MAX)
				angVelocity[2] = VEHICLE_ROTATE_MAX;
		}
		
		if (buttons & IN_MOVERIGHT && angVelocity[2] > -VEHICLE_ROTATE_MAX)
		{
			angVelocity[2] -= VEHICLE_ROTATE_SPEED;
			if (angVelocity[2] < -VEHICLE_ROTATE_MAX)
				angVelocity[2] = -VEHICLE_ROTATE_MAX;
		}
		
		float fwd;
		if (buttons & IN_FORWARD)
			fwd += VEHICLE_SPEED_FORWARD;
		
		if (buttons & IN_BACK)
			fwd -= VEHICLE_SPEED_BACKWARD;
		
		if (fwd)
		{
			float buffer[3];
			AnglesToVelocity(angles, buffer, fwd);
			
			for (int vec = 0; vec < 3; vec++)
			{
				if (-VEHICLE_SPEED_MAX < velocity[vec] < VEHICLE_SPEED_MAX)
				{
					velocity[vec] += buffer[vec];
					
					if (velocity[vec] < -VEHICLE_SPEED_MAX)
						velocity[vec] = -VEHICLE_SPEED_MAX;
					
					if (velocity[vec] > VEHICLE_SPEED_MAX)
						velocity[vec] = VEHICLE_SPEED_MAX;
				}
			}
		}
		
		SDKCall_SetVelocity(vehicle.entity, velocity, angVelocity);
	}
	else
	{
		AcceptEntityInput(client, "ClearParent");
	}
}

bool Vehicles_GetByEntity(int entity, Vehicle vehicle)
{
	int pos = g_Vehicles.FindValue(entity, Vehicle::entity);
	if (pos == -1)
		return false;
	
	g_Vehicles.GetArray(pos, vehicle);
	return true;
}

bool Vehicles_GetByClient(int client, Vehicle vehicle)
{
	int pos = g_Vehicles.FindValue(client, Vehicle::client);
	if (pos == -1)
		return false;
	
	g_Vehicles.GetArray(pos, vehicle);
	return true;
}

void Vehicles_SetByEntity(Vehicle vehicle)
{
	int pos = g_Vehicles.FindValue(vehicle.entity, Vehicle::entity);
	if (pos == -1)
		return;
	
	g_Vehicles.SetArray(pos, vehicle);
}

void Vehicles_RemoveByClient(int client)
{
	int pos;
	do
	{
		pos = g_Vehicles.FindValue(client, Vehicle::client);
		if (pos >= 0)
			g_Vehicles.Erase(pos);
	}
	while (pos >= 0);
}