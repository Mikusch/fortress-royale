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

enum struct Vehicle
{
	int entity;	/**< Entity index */
	
	/**< Config prefab */
	char targetname[CONFIG_MAXCHAR];/**< Name of vehicle */
	char model[PLATFORM_MAX_PATH];	/**< Vehicle model */
	char vehiclescript[PLATFORM_MAX_PATH];	/**< Vehicle script path */
	
	/**< Config map */
	char origin[CONFIG_MAXCHAR];/**< Positon to spawn entity in world */
	char angles[CONFIG_MAXCHAR];/**< Angles to spawn entity in world */
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("targetname", this.targetname, CONFIG_MAXCHAR, this.targetname);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		kv.GetString("vehiclescript", this.vehiclescript, PLATFORM_MAX_PATH, this.vehiclescript);
		PrecacheModel(this.model);
		
		//origin and angles is saved as string so we dont get float precision problem
		kv.GetString("origin", this.origin, CONFIG_MAXCHAR, this.origin);
		kv.GetString("angles", this.angles, CONFIG_MAXCHAR, this.angles);
	}
	
	void SetConfig(KeyValues kv)
	{
		//We only care targetname, origin and angles to save to "Vehicles" section, for now
		kv.SetString("targetname", this.targetname);
		kv.SetString("origin", this.origin);
		kv.SetString("angles", this.angles);
	}
}

void Vehicles_Init()
{
	//Load common vehicle sounds
	if (g_LoadSoundscript)
		LoadSoundScript("scripts/game_sounds_vehicles.txt");
}

void Vehicles_SetupFinished()
{
	int pos;
	Vehicle config;
	while (VehiclesConfig_GetVehicle(pos, config))
	{
		float origin[3], angles[3];
		StringToVector(config.origin, origin);
		StringToVector(config.angles, angles);
		
		Vehicles_CreateEntity(config.model, config.vehiclescript, origin, angles);
		pos++;
	}
	
	int vehicle = -1;
	while ((vehicle = FindEntityByClassname(vehicle, "prop_vehicle*")) != -1)
		Vehicles_UpdateEntity(vehicle);
}

void Vehicles_UpdateEntity(int entity)
{
	char targetname[CONFIG_MAXCHAR];
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	Vehicle vehicle;
	VehiclesConfig_GetDefault(vehicle);
	
	if (!StrEqual(targetname, vehicle.targetname) && !VehiclesConfig_GetPrefabByTargetname(targetname, vehicle))
		return;
	
	if (GameRules_GetProp("m_bInWaitingForPlayers") || g_RoundState == FRRoundState_Active)
	{
		RemoveEntity(entity);
		return;
	}
	
	DispatchKeyValue(entity, "vehiclescript", vehicle.vehiclescript);
	
	SDKHook(entity, SDKHook_Think, Vehicles_Think);
	SDKHook(entity, SDKHook_OnTakeDamage, Vehicles_OnTakeDamage);
}

void Vehicles_OnEntityDestroyed(int entity)
{
	char classname[256];
	GetEntityClassname(entity, classname, sizeof(classname));
	if (StrEqual(classname, "prop_vehicle_driveable"))
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hPlayer");
		if (0 < client <= MaxClients)
			SDKCall_HandlePassengerExit(entity, client);
	}
}

public Action Vehicles_CreateEntity(const char[] model, const char[] vehiclescript, const float origin[3], const float angles[3])
{
	int vehicle = CreateEntityByName("prop_vehicle_driveable");
	if (vehicle != -1)
	{
		DispatchKeyValue(vehicle, "model", model);
		DispatchKeyValue(vehicle, "vehiclescript", vehiclescript);
		DispatchKeyValue(vehicle, "spawnflags", "1"); //SF_PROP_VEHICLE_ALWAYSTHINK
		
		if (DispatchSpawn(vehicle))
		{
			TeleportEntity(vehicle, origin, angles, NULL_VECTOR);
			
			HookSingleEntityOutput(vehicle, "PlayerOn", Vehicle_PlayerOn);
			
			SDKHook(vehicle, SDKHook_Think, Vehicles_Think);
			SDKHook(vehicle, SDKHook_OnTakeDamage, Vehicles_OnTakeDamage);
		}
	}
	
	return Plugin_Handled;
}

public Action Vehicle_PlayerOn(const char[] output, int caller, int activator, float delay)
{
	AcceptEntityInput(caller, "TurnOn");
}

public void Vehicles_Think(int vehicle)
{
	SetEntProp(vehicle, Prop_Data, "m_bEnterAnimOn", false);
	SetEntProp(vehicle, Prop_Data, "m_bExitAnimOn", false);
}

public Action Vehicles_OnTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//Driver receives 1/4 of damage done to vehicle
	int client = GetEntPropEnt(entity, Prop_Send, "m_hPlayer");
	if (0 < client <= MaxClients)
		SDKHooks_TakeDamage(client, inflictor, attacker, damage / 4, damagetype, weapon, damageForce, damagePosition);
}
