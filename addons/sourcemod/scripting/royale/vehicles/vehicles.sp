#define VEHICLE_ENTER_RANGE 150.0

enum struct Vehicle
{
	int entity;	/**< Entity ref */
	int client; /**< Client riding on this vehicle */
	
	char name[CONFIG_MAXCHAR];	/**< Name of vehicle */
	char model[PLATFORM_MAX_PATH];	/**< Entity model */
	float offset_player[3];	/**< Offset from entity to teleport player */
	float mass;				/**< Entity mass */
	float impact;			/**< Entity damage impact force */
	
	float rotate_speed;		/**< Rotation speed */
	float rotate_max; 		/**< Max rotation speed */
	
	float speed_forward;	/**< Forward speed */
	float speed_backward;	/**< Backward speed */
	float speed_max;		/**< Max speed */
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("name", this.name, CONFIG_MAXCHAR, this.name);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		
		kv.GetVector("offset_player", this.offset_player, this.offset_player);
		this.mass = kv.GetFloat("mass", this.mass);
		this.impact = kv.GetFloat("impact", this.impact);
		
		this.rotate_speed = kv.GetFloat("rotate_speed", this.rotate_speed);
		this.rotate_max = kv.GetFloat("rotate_max", this.rotate_max);
	
		this.speed_forward = kv.GetFloat("speed_forward", this.speed_forward);
		this.speed_backward = kv.GetFloat("speed_backward", this.speed_backward);
		this.speed_max = kv.GetFloat("speed_max", this.speed_max);
	}
}

static ArrayList g_VehiclesEntity;

void Vehicles_Init()
{
	g_VehiclesEntity = new ArrayList(sizeof(Vehicle));
}

void Vehicles_Create(Vehicle vehicle, int client)
{
	float position[3], angles[3];
	GetClientEyePosition(client, position);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(position))
		return;
	
	int entity = CreateEntityByName("prop_physics_override");
	if (!IsValidEntity(entity))
		return;
	
	SetEntityModel(entity, vehicle.model);
	DispatchKeyValueFloat(entity, "massScale", vehicle.mass);
	DispatchKeyValueFloat(entity, "physdamagescale", vehicle.impact);
	
	SetEntProp(entity, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_NO);
	
	if (!DispatchSpawn(entity) || !MoveEntityToClientEye(entity, client))
	{
		RemoveEntity(entity);
		return;
	}
	
	AcceptEntityInput(entity, "EnableMotion");
	
	vehicle.entity = EntIndexToEntRef(entity);
	g_VehiclesEntity.PushArray(vehicle);
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

void Vehicles_EnterVehicle(int entity, int client)
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
	
	FRPlayer(client).LastVehicleEnterTime = GetGameTime();
	
	//Set client to ride this vehicle
	vehicle.client = client;
	Vehicles_SetByEntity(vehicle);
	SDKHook(client, SDKHook_PreThink, Vehicles_PreThink);
	
	SDKHook(entity, SDKHook_OnTakeDamage, Vehicles_OnTakeDamage);
	
	//Force client duck and dont move
	SetEntProp(client, Prop_Send, "m_bDucking", true);
	SetEntProp(client, Prop_Send, "m_bDucked", true);
	SetEntityFlags(client, GetEntityFlags(client) | FL_DUCKING);
	SetEntityMoveType(client, MOVETYPE_NONE);
	
	SetVariantString("!activator");
	AcceptEntityInput(client, "SetParent", entity, entity);
	
	float angles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);
	
	//After client is parented, origin is now the offset of prop
	TeleportEntity(client, vehicle.offset_player, angles, NULL_VECTOR);
}

void Vehicles_ExitVehicle(int client)
{
	AcceptEntityInput(client, "ClearParent");
	SDKUnhook(client, SDKHook_PreThink, Vehicles_PreThink);
	SetEntityMoveType(client, MOVETYPE_WALK);
	
	Vehicle vehicle;
	if (Vehicles_GetByClient(client, vehicle))
	{
		SDKUnhook(vehicle.entity, SDKHook_OnTakeDamage, Vehicles_OnTakeDamage);
		
		vehicle.client = -1;
		Vehicles_SetByEntity(vehicle);
	}
	
	//TODO: Exit offset, if blocked teleport player to first free location
	float origin[3];
	GetClientAbsOrigin(client, origin);
	origin[2] += 150.0;
	TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
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
		
		if (buttons & IN_MOVELEFT && angVelocity[2] < vehicle.rotate_max)
		{
			angVelocity[2] += vehicle.rotate_speed;
			if (angVelocity[2] > vehicle.rotate_max)
				angVelocity[2] = vehicle.rotate_max;
		}
		
		if (buttons & IN_MOVERIGHT && angVelocity[2] > -vehicle.rotate_max)
		{
			angVelocity[2] -= vehicle.rotate_speed;
			if (angVelocity[2] < -vehicle.rotate_max)
				angVelocity[2] = -vehicle.rotate_max;
		}
		
		float fwd;
		if (buttons & IN_FORWARD)
			fwd += vehicle.speed_forward;
		
		if (buttons & IN_BACK)
			fwd -= vehicle.speed_backward;
		
		if (fwd)
		{
			float buffer[3];
			AnglesToVelocity(angles, buffer, fwd);
			
			for (int vec = 0; vec < 3; vec++)
			{
				if (-vehicle.speed_max < velocity[vec] < vehicle.speed_max)
				{
					velocity[vec] += buffer[vec];
					
					if (velocity[vec] < -vehicle.speed_max)
						velocity[vec] = -vehicle.speed_max;
					
					if (velocity[vec] > vehicle.speed_max)
						velocity[vec] = vehicle.speed_max;
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

public Action Vehicles_OnTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//Driver receives 1/4 of damage done to vehicle
	Vehicle vehicle;
	if (Vehicles_GetByEntity(EntIndexToEntRef(entity), vehicle) && 0 < vehicle.client <= MaxClients && IsPlayerAlive(vehicle.client) && attacker != vehicle.client)
		SDKHooks_TakeDamage(vehicle.client, inflictor, attacker, damage / 4, damagetype, weapon, damageForce, damagePosition);
}

void Vehicles_TryToEnterVehicle(int client)
{
	int entity = GetClientPointVisible(client, VEHICLE_ENTER_RANGE);
	if (entity != -1)
		Vehicles_EnterVehicle(entity, client);
}

bool Vehicles_GetByEntity(int entity, Vehicle vehicle)
{
	int pos = g_VehiclesEntity.FindValue(entity, Vehicle::entity);
	if (pos == -1)
		return false;
	
	g_VehiclesEntity.GetArray(pos, vehicle);
	return true;
}

bool Vehicles_GetByClient(int client, Vehicle vehicle)
{
	int pos = g_VehiclesEntity.FindValue(client, Vehicle::client);
	if (pos == -1)
		return false;
	
	g_VehiclesEntity.GetArray(pos, vehicle);
	return true;
}

void Vehicles_SetByEntity(Vehicle vehicle)
{
	int pos = g_VehiclesEntity.FindValue(vehicle.entity, Vehicle::entity);
	if (pos == -1)
		return;
	
	g_VehiclesEntity.SetArray(pos, vehicle);
}

void Vehicles_RemoveByClient(int client)
{
	int pos;
	do
	{
		pos = g_VehiclesEntity.FindValue(client, Vehicle::client);
		if (pos >= 0)
			g_VehiclesEntity.Erase(pos);
	}
	while (pos >= 0);
}