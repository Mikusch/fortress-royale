#define VEHICLE_ENTER_RANGE 150.0

enum struct Vehicle
{
	int entity;			/**< Entity ref */
	int client; 		/**< Client riding on this vehicle */
	bool flight;		/**< Is the vehicle in flight? */
	float tilt[3]; 		/**< How much flight tilt is vehicle currently in */
	
	char name[CONFIG_MAXCHAR];	/**< Name of vehicle */
	char model[PLATFORM_MAX_PATH];	/**< Entity model */
	float offset_angles[3];	/**< Entity angles offset */
	float offset_player[3];	/**< Offset from entity to teleport player */
	float mass;				/**< Entity mass */
	float impact;			/**< Entity damage impact force */
	
	float rotate_speed;		/**< Rotation speed */
	float rotate_max; 		/**< Max rotation speed */
	
	float land_forward_speed;	/**< Forward speed while on land */
	float land_forward_max;		/**< Max forward speed  while on land */
	float land_backward_speed;	/**< Backward speed while on land */
	float land_backward_max;	/**< Max backward speed while on land */
	float land_height;			/**< Max land height to have max land effects */
	
	float water_forward_speed;	/**< Forward speed while on water */
	float water_forward_max;	/**< Max forward speed  while on water */
	float water_backward_speed;	/**< Backward speed while on water */
	float water_backward_max;	/**< Max backward speed while on water */
	float water_height;			/**< Max water height to have max water effects */
	
	float water_float_speed;	/**< If in water, speed vel to raise up to highest water level */
	float water_float_height;	/**< Max water height to have water float effects */
	
	float flight_upward;	/**< Flight upward speed */
	float flight_downward;	/**< Flight downward speed */
	
	float tilt_speed;		/**< Flight tilt, all directions */
	float tilt_max;			/**< Max tilt speed */
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("name", this.name, CONFIG_MAXCHAR, this.name);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		
		kv.GetVector("offset_angles", this.offset_angles, this.offset_angles);
		kv.GetVector("offset_player", this.offset_player, this.offset_player);
		this.mass = kv.GetFloat("mass", this.mass);
		this.impact = kv.GetFloat("impact", this.impact);
		
		this.rotate_speed = kv.GetFloat("rotate_speed", this.rotate_speed);
		this.rotate_max = kv.GetFloat("rotate_max", this.rotate_max);
		
		this.land_forward_speed = kv.GetFloat("land_forward_speed", this.land_forward_speed);
		this.land_forward_max = kv.GetFloat("land_forward_max", this.land_forward_max);
		this.land_backward_speed = kv.GetFloat("land_backward_speed", this.land_backward_speed);
		this.land_backward_max = kv.GetFloat("land_backward_max", this.land_backward_max);
		this.land_height = kv.GetFloat("land_height", this.land_height);
		
		this.water_forward_speed = kv.GetFloat("water_forward_speed", this.water_forward_speed);
		this.water_forward_max = kv.GetFloat("water_forward_max", this.water_forward_max);
		this.water_backward_speed = kv.GetFloat("water_backward_speed", this.water_backward_speed);
		this.water_backward_max = kv.GetFloat("water_backward_max", this.water_backward_max);
		this.water_height = kv.GetFloat("water_height", this.water_height);
		
		this.water_float_speed = kv.GetFloat("water_float_speed", this.water_float_speed);
		this.water_float_height = kv.GetFloat("water_float_height", this.water_float_height);
		
		this.flight_upward = kv.GetFloat("flight_upward", this.flight_upward);
		this.flight_downward = kv.GetFloat("flight_downward", this.flight_downward);
		
		this.tilt_speed = kv.GetFloat("tilt_speed", this.tilt_speed);
		this.tilt_max = kv.GetFloat("tilt_max", this.tilt_max);
	}
}

static ArrayList g_VehiclesEntity;

void Vehicles_Init()
{
	g_VehiclesEntity = new ArrayList(sizeof(Vehicle));
}

void Vehicles_Create(Vehicle vehicle, int client)
{
	float position[3];
	GetClientEyePosition(client, position);
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
	
	if (!DispatchSpawn(entity) || !MoveEntityToClientEye(entity, client, MASK_SOLID|MASK_WATER))
	{
		RemoveEntity(entity);
		return;
	}
	
	//Rotate entity from angles offset
	float angles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);
	SubtractVectors(angles, vehicle.offset_angles, angles);
	TeleportEntity(entity, NULL_VECTOR, angles, NULL_VECTOR);
	
	AcceptEntityInput(entity, "EnableMotion");
	
	SDKHook(entity, SDKHook_OnTakeDamage, Vehicles_OnTakeDamage);
	
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

void Vehicles_EnterVehicle(int entity, int toucher)
{
	entity = EntIndexToEntRef(entity);
	
	Vehicle vehicle;
	if (!Vehicles_GetByEntity(entity, vehicle))
		return;
	
	if (0 < vehicle.client <= MaxClients && IsClientInGame(vehicle.client) && IsPlayerAlive(vehicle.client))
	{
		//Someone already taken this vehicle
		if (vehicle.flight)
		{
			char classname[256];
			GetEntityClassname(toucher, classname, sizeof(classname));
			if (StrContains(classname, "worldspawn") == 0 || StrContains(classname, "prop_") == 0)
			{
				//Vehicle is touching world, end flight
				vehicle.flight = false;
				Vehicles_SetByEntity(vehicle);
			}
		}
	}
	else if (0 < toucher <= MaxClients)
	{
		//Set client to ride this vehicle
		vehicle.client = toucher;
		Vehicles_SetByEntity(vehicle);
		SDKHook(vehicle.client, SDKHook_PreThink, Vehicles_PreThink);
		FRPlayer(vehicle.client).LastVehicleEnterTime = GetGameTime();
		
		//Force client duck and dont move
		SetEntProp(vehicle.client, Prop_Send, "m_bDucking", true);
		SetEntProp(vehicle.client, Prop_Send, "m_bDucked", true);
		SetEntityFlags(vehicle.client, GetEntityFlags(vehicle.client)|FL_DUCKING);
		SetEntityMoveType(vehicle.client, MOVETYPE_NONE);
		
		SetVariantString("!activator");
		AcceptEntityInput(vehicle.client, "SetParent", entity, entity);
		
		//After client is parented, origin and angles is now the offset of prop
		TeleportEntity(vehicle.client, vehicle.offset_player, vehicle.offset_angles, NULL_VECTOR);
	}
}

void Vehicles_ExitVehicle(int client)
{
	AcceptEntityInput(client, "ClearParent");
	SDKUnhook(client, SDKHook_PreThink, Vehicles_PreThink);
	SetEntityMoveType(client, MOVETYPE_WALK);
	
	Vehicle vehicle;
	if (Vehicles_GetByClient(client, vehicle))
	{
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
		
		//Helicopter
		if (vehicle.flight)
		{
			if (buttons & IN_FORWARD)
				vehicle.tilt[0] = fMin(vehicle.tilt[0] + vehicle.tilt_speed, vehicle.tilt_max);
			else
				vehicle.tilt[0] = fMax(vehicle.tilt[0] - vehicle.tilt_speed, 0.0);
			
			Vehicles_SetByEntity(vehicle);
			SubtractVectors(angles, vehicle.tilt, angles);
		}
		
		//Stabilize vehicle's angle vel, for helicopter and prevent barrel rolls
		angVelocity[0] -= angles[2] * 0.5;	//side
		angVelocity[1] -= angles[0] * 0.5;	//front
		
		if (vehicle.flight)	//Dont consider upward/downward angles for helicopter
			angles[0] = 0.0;
		
		AddVectors(angles, vehicle.offset_angles, angles);
		
		//Reduce velocity and angVelocity down to not have entity act like riding on ice
		ScaleVector(velocity, 0.95);
		ScaleVector(angVelocity, 0.95);
		
		if (buttons & IN_MOVELEFT)
			angVelocity[2] = fMin(angVelocity[2] + vehicle.rotate_speed, vehicle.rotate_max);
		
		if (buttons & IN_MOVERIGHT)
			angVelocity[2] = fMax(angVelocity[2] - vehicle.rotate_speed, -vehicle.rotate_max);
		
		float water = 0.0;	// Percentage the vehicle is in water
		float height;
		if (GetWaterHeightFromEntity(vehicle.entity, height) && height > -vehicle.land_height)
			water = fMin(height + vehicle.land_height, vehicle.land_height + vehicle.water_height) / (vehicle.land_height + vehicle.water_height);
		
		if ((buttons & IN_FORWARD && !(buttons & IN_BACK)) || (buttons & IN_BACK && !(buttons & IN_FORWARD)))
		{
			float speed, max;
			
			if (buttons & IN_FORWARD)
			{
				speed = ((1.0 - water) * vehicle.land_forward_speed) + (water * vehicle.water_forward_speed);
				max = ((1.0 - water) * vehicle.land_forward_max) + (water * vehicle.water_forward_max);
			}
			else if (buttons & IN_BACK)
			{
				speed = -((1.0 - water) * vehicle.land_backward_speed) - (water * vehicle.water_backward_speed);
				max = ((1.0 - water) * vehicle.land_backward_max) + (water * vehicle.water_backward_max);
			}
			
			float direction[3];
			AnglesToVelocity(angles, direction, speed);
			AddVectors(velocity, direction, velocity);
			
			speed = GetVectorLength(velocity);
			if (speed > max)
				ScaleVector(velocity, max / speed);
		}
		
		if (water > 0.0 && vehicle.water_float_height > 0.0)	//TODO always run this, even when player not on vehicle
			velocity[2] += fMin(height, vehicle.water_float_height) / vehicle.water_float_height * vehicle.water_float_speed;
		
		if (buttons & IN_JUMP && vehicle.flight_upward > 0.0)
		{
			//Set flight to vehicle
			vehicle.flight = true;
			Vehicles_SetByEntity(vehicle);
			
			velocity[2] = fMax(velocity[2] + vehicle.flight_upward, vehicle.flight_upward);
		}
		
		if (buttons & IN_DUCK && vehicle.flight)
		{
			velocity[2] = fMin(velocity[2] - vehicle.flight_downward, vehicle.flight_downward);
		}
		
		if (!(buttons & IN_JUMP || buttons & IN_DUCK) && vehicle.flight)
		{
			//Slow down vehicle upward/downward vel, as no gravity doesnt slow down vel
			if (velocity[2] > 0.0)
				velocity[2] = fMin(velocity[2] - vehicle.flight_upward, 0.0);
			else if (velocity[2] < 0.0)
				velocity[2] = fMax(velocity[2] + vehicle.flight_downward, 0.0);
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