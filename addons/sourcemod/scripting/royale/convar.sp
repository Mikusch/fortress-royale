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

#define MAX_COMMAND_LENGTH 1024

enum struct ConVarInfo
{
	ConVar convar;
	char value[MAX_COMMAND_LENGTH];
	char initialValue[MAX_COMMAND_LENGTH];
}

static ArrayList g_ConVarInfo;

void ConVar_Init()
{
	fr_enable = CreateConVar("fr_enable", "-1", "-1 to enable based on map config existance, 0 to force disable, 1 to force enable", _, true, -1.0, true, 1.0);
	fr_enable.AddChangeHook(ConVar_EnableChanged);
	
	fr_class_health[1] = CreateConVar("fr_class_health_scout", "250", "Max health for Scout", _, true, 1.0);
	fr_class_health[2] = CreateConVar("fr_class_health_sniper", "250", "Max health for Sniper", _, true, 1.0);
	fr_class_health[3] = CreateConVar("fr_class_health_soldier", "400", "Max health for Soldier", _, true, 1.0);
	fr_class_health[4] = CreateConVar("fr_class_health_demoman", "350", "Max health for Demoman", _, true, 1.0);
	fr_class_health[5] = CreateConVar("fr_class_health_medic", "300", "Max health for Medic", _, true, 1.0);
	fr_class_health[6] = CreateConVar("fr_class_health_heavy", "600", "Max health for Heavy", _, true, 1.0);
	fr_class_health[7] = CreateConVar("fr_class_health_pyro", "350", "Max health for Pyro", _, true, 1.0);
	fr_class_health[8] = CreateConVar("fr_class_health_spy", "250", "Max health for Spy", _, true, 1.0);
	fr_class_health[9] = CreateConVar("fr_class_health_engineer", "250", "Max health for Engineer", _, true, 1.0);
	
	fr_obj_health[0] = CreateConVar("fr_obj_health_dispenser", "300", "Base building health for Dispensers", _, true, 1.0);
	fr_obj_health[1] = CreateConVar("fr_obj_health_teleporter", "300", "Base building health for Teleporters", _, true, 1.0);
	fr_obj_health[2] = CreateConVar("fr_obj_health_sentrygun", "300", "Base building health for Sentry Guns", _, true, 1.0);
	fr_obj_health[3] = CreateConVar("fr_obj_health_sapper", "200", "Base building health for Sappers", _, true, 1.0);
	
	fr_fistsdamagemultiplier = CreateConVar("fr_fistsdamagemultiplier", "0.62", "Starting fists damage multiplier", _, true, 0.0);
	fr_sectodeployparachute = CreateConVar("fr_sectodeployparachute", "2", "Time in seconds to deploy parachute after ejecting from battle bus", _, true, 1.0);
	fr_classfilter = CreateConVar("fr_classfilter", "1", "Enable class filtering, restricting weapon loots by classes. Disabling may cause several issues", _, true, 0.0, true, 1.0);
	fr_randomclass = CreateConVar("fr_randomclass", "0", "If enabled, players will spawn as a random class", _, true, 0.0, true, 1.0);
	fr_bottle_points = CreateConVar("fr_bottle_points", "1", "How many points a bottle from fallen enemies contains, set to 0 to disable bottle drops");
	fr_multiwearable = CreateConVar("fr_multiwearable", "0", "Allow equip multiple wearables in same slot with weapons", _, true, 0.0, true, 1.0);
	
	fr_zone_startdisplay = CreateConVar("fr_zone_startdisplay", "30.0", "Seconds from round start to start zone display", _, true, 0.0);
	fr_zone_startdisplay_player = CreateConVar("fr_zone_startdisplay_player", "1.0", "Extra seconds on every player from round start to start zone display", _, true, 0.0);
	fr_zone_display = CreateConVar("fr_zone_display", "15.0", "Seconds to display next zone before shrink", _, true, 0.0);
	fr_zone_display_player = CreateConVar("fr_zone_display_player", "0.5", "Extra seconds on every player to display next zone before shrink", _, true, 0.0);
	fr_zone_shrink = CreateConVar("fr_zone_shrink", "20.0", "Seconds to shrink zone to next level", _, true, 0.0);
	fr_zone_shrink_player = CreateConVar("fr_zone_shrink_player", "0.67", "Extra seconds on every player to shrink zone to next level", _, true, 0.0);
	fr_zone_nextdisplay = CreateConVar("fr_zone_nextdisplay", "0.0", "Seconds after shrink to display next zone", _, true, 0.0);
	fr_zone_nextdisplay_player = CreateConVar("fr_zone_nextdisplay_player", "0.0", "Extra seconds on every player after shrink to display next zone", _, true, 0.0);
	fr_zone_damagemultiplier = CreateConVar("fr_zone_damagemultiplier", "0.25", "Damage multiplier of the zone", _, true, 0.0);
	
	fr_vehicle_passenger_damagemultiplier = CreateConVar("fr_vehicle_passenger_damagemultiplier", "0.25", "Damage multiplier to passengers of a vehicle", _, true, 0.0);
	fr_vehicle_lock_speed = CreateConVar("fr_vehicle_lock_speed", "10.0", "Vehicle must be going slower than this for player to enter or exit, in in/sec", _, true, 0.0);
	
	fr_truce_duration = CreateConVar("fr_truce_duration", "60.0", "How long the truce at the start of each round should last. Set to 0 to disable truce", _, true, 0.0);
	
	g_ConVarInfo = new ArrayList(sizeof(ConVarInfo));
	
	ConVar_Add("mp_autoteambalance", "0");
	ConVar_Add("mp_teams_unbalance_limit", "0");
	ConVar_Add("mp_forcecamera", "0");
	ConVar_Add("mp_friendlyfire", "1");
	ConVar_Add("mp_respawnwavetime", "99999.9");
	ConVar_Add("mp_waitingforplayers_time", "60");
	ConVar_Add("sv_turbophysics", "0");
	ConVar_Add("tf_allow_player_use", "1");
	ConVar_Add("tf_avoidteammates", "0");
	ConVar_Add("tf_dropped_weapon_lifetime", "99999");
	ConVar_Add("tf_parachute_maxspeed_xy", "600.0f");
	ConVar_Add("tf_parachute_maxspeed_z", "-200.0f");
	ConVar_Add("tf_spawn_glows_duration", "0");
	ConVar_Add("tf_spells_enabled", "1");
	ConVar_Add("tf_weapon_criticals", "0");
}

void ConVar_Add(const char[] name, const char[] value)
{
	ConVarInfo info;
	info.convar = FindConVar(name);
	strcopy(info.value, sizeof(info.value), value);
	g_ConVarInfo.PushArray(info);
}

void ConVar_Enable()
{
	for (int i = 0; i < g_ConVarInfo.Length; i++)
	{
		ConVarInfo info;
		g_ConVarInfo.GetArray(i, info);
		info.convar.GetString(info.initialValue, sizeof(info.initialValue));
		g_ConVarInfo.SetArray(i, info);
		
		info.convar.SetString(info.value);
		info.convar.AddChangeHook(ConVar_OnChanged);
	}
}

void ConVar_Disable()
{
	for (int i = 0; i < g_ConVarInfo.Length; i++)
	{
		ConVarInfo info;
		g_ConVarInfo.GetArray(i, info);
		
		info.convar.RemoveChangeHook(ConVar_OnChanged);
		info.convar.SetString(info.initialValue);
	}
}

void ConVar_OnChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int index = g_ConVarInfo.FindValue(convar, ConVarInfo::convar);
	if (index != -1)
	{
		ConVarInfo info;
		g_ConVarInfo.GetArray(index, info);
		
		if (!StrEqual(newValue, info.value))
			info.convar.SetString(info.value);
	}
}

public void ConVar_EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshEnable();
}
