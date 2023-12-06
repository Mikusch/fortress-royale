/**
 * Copyright (C) 2023  Mikusch
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

#pragma semicolon 1
#pragma newdecls required

#define COMMAND_MAX_LENGTH	512

enum struct ConVarData
{
	char name[COMMAND_MAX_LENGTH];
	char value[COMMAND_MAX_LENGTH];
	char initial_value[COMMAND_MAX_LENGTH];
}

static StringMap g_ConVars;

void ConVars_Init()
{
	g_ConVars = new StringMap();
	
	CreateConVar("sm_fr_version", PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_fr_enable = CreateConVar("sm_fr_enable", "1", "Enable the plugin?");
	sm_fr_setup_length = CreateConVar("sm_fr_setup_length", "15", "Time before the battle bus takes off.");
	sm_fr_truce_duration = CreateConVar("sm_fr_truce_duration", "60", "Length of the truce period.");
	sm_fr_crate_open_time = CreateConVar("sm_fr_crate_open_time", "3", "Amount of time to open a crate.");
	sm_fr_crate_open_range = CreateConVar("sm_fr_crate_open_range", "64", "Range in HU that players may open crates from.");
	sm_fr_crate_max_drops = CreateConVar("sm_fr_crate_max_drops", "1", "Maximum amount of drops a player can receive from a crate.");
	sm_fr_crate_max_extra_drops = CreateConVar("sm_fr_crate_max_extra_drops", "2", "Maximum amount of extra drops a player can receive from a crate.");
	sm_fr_max_ammo_boost = CreateConVar("sm_fr_max_ammo_boost", "1.5", "Maximum ammo factor that players are allowed to carry.", _, true, 1.0);
	sm_fr_parachute_auto_height = CreateConVar("sm_fr_parachute_auto_height", "2500", "Minimum height from the ground for parachute to auto-activate.");
	sm_fr_fists_damage_multiplier = CreateConVar("sm_fr_fists_damage_multiplier", "0.7", "Damage multiplier to starting fists.");
	sm_fr_medigun_damage = CreateConVar("sm_fr_medigun_damage", "2", "Amount of damage that Medi Guns should deal per tick.");
	sm_fr_dropped_weapon_ammo_percentage = CreateConVar("sm_fr_dropped_weapon_ammo_percentage", "0.25", "How much of its maximum ammo a dropped weapon should start with.");
	
	sm_fr_zone_startdisplay = CreateConVar("sm_fr_zone_startdisplay", "30", "Seconds from round start to start zone display", _, true, 0.0);
	sm_fr_zone_startdisplay_player = CreateConVar("sm_fr_zone_startdisplay_player", "1", "Extra seconds on every player from round start to start zone display", _, true, 0.0);
	sm_fr_zone_display = CreateConVar("sm_fr_zone_display", "15", "Seconds to display next zone before shrink", _, true, 0.0);
	sm_fr_zone_display_player = CreateConVar("sm_fr_zone_display_player", "0.5", "Extra seconds on every player to display next zone before shrink", _, true, 0.0);
	sm_fr_zone_nextdisplay = CreateConVar("sm_fr_zone_nextdisplay", "20", "Seconds after shrink to display next zone", _, true, 0.0);
	sm_fr_zone_nextdisplay_player = CreateConVar("sm_fr_zone_nextdisplay_player", "0", "Extra seconds on every player after shrink to display next zone", _, true, 0.0);
	sm_fr_zone_damage_min = CreateConVar("sm_fr_zone_damage_min", "1", "Minimum damage of the zone, when it hasn't shrunk yet.", _, true, 0.0);
	sm_fr_zone_damage_max = CreateConVar("sm_fr_zone_damage_max", "10", "Maximum damage of the zone, when it's fully shrunk.", _, true, 0.0);
	
	sm_fr_health_multiplier[TFClass_Scout] = CreateConVar("sm_fr_health_multiplier_scout", "1.6", "Multiplier to maximum health for Scout.");
	sm_fr_health_multiplier[TFClass_Sniper] = CreateConVar("sm_fr_health_multiplier_sniper", "2", "Multiplier to maximum health for Sniper.");
	sm_fr_health_multiplier[TFClass_Soldier] = CreateConVar("sm_fr_health_multiplier_soldier", "1.75", "Multiplier to maximum health for Soldier.");
	sm_fr_health_multiplier[TFClass_DemoMan] = CreateConVar("sm_fr_health_multiplier_demoman", "2", "Multiplier to maximum health for Demoman.");
	sm_fr_health_multiplier[TFClass_Medic] = CreateConVar("sm_fr_health_multiplier_medic", "1.5", "Multiplier to maximum health for Medic.");
	sm_fr_health_multiplier[TFClass_Heavy] = CreateConVar("sm_fr_health_multiplier_heavy", "1.75", "Multiplier to maximum health for Heavy.");
	sm_fr_health_multiplier[TFClass_Pyro] = CreateConVar("sm_fr_health_multiplier_pyro", "1.6", "Multiplier to maximum health for Pyro.");
	sm_fr_health_multiplier[TFClass_Spy] = CreateConVar("sm_fr_health_multiplier_spy", "1.6", "Multiplier to maximum health for Spy.");
	sm_fr_health_multiplier[TFClass_Engineer] = CreateConVar("sm_fr_health_multiplier_engineer", "1.6", "Multiplier to maximum health for Engineer.");
	
	sm_fr_enable.AddChangeHook(ConVarChanged_OnEnableChanged);
	
	mp_disable_respawn_times = FindConVar("mp_disable_respawn_times");
	spec_freeze_traveltime = FindConVar("spec_freeze_traveltime");
	
	ConVars_AddConVar("tf_powerup_mode", "1");
	ConVars_AddConVar("tf_weapon_criticals", "0");
	ConVars_AddConVar("tf_parachute_maxspeed_xy", "600.0f");
	ConVars_AddConVar("tf_parachute_maxspeed_z", "-200.0f");
	ConVars_AddConVar("tf_spawn_glows_duration", "0");
	ConVars_AddConVar("tf_spy_cloak_regen_rate", "0.0");
	ConVars_AddConVar("mp_teams_unbalance_limit", "0");
	ConVars_AddConVar("mp_autoteambalance", "0");
	ConVars_AddConVar("mp_scrambleteams_auto", "0");
	ConVars_AddConVar("mp_forcecamera", "0");
	ConVars_AddConVar("mp_friendlyfire", "1");
}

void ConVars_Toggle(bool enable)
{
	StringMapSnapshot snapshot = g_ConVars.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		int size = snapshot.KeyBufferSize(i);
		char[] key = new char[size];
		snapshot.GetKey(i, key, size);
		
		if (enable)
		{
			ConVars_Enable(key);
		}
		else
		{
			ConVars_Disable(key);
		}
	}
	delete snapshot;
}

void ConVars_OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, LIBRARY_FRIENDLYFIRE))
	{
		ConVars_AddConVar("sm_friendlyfire_medic_allow_healing", "1");
	}
}

void ConVars_OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, LIBRARY_FRIENDLYFIRE))
	{
		ConVars_RemoveConVar("sm_friendlyfire_medic_allow_healing");
	}
}

static void ConVars_AddConVar(const char[] name, const char[] value)
{
	ConVar convar = FindConVar(name);
	if (convar)
	{
		// Store convar data
		ConVarData data;
		strcopy(data.name, sizeof(data.name), name);
		strcopy(data.value, sizeof(data.value), value);
		g_ConVars.SetArray(name, data, sizeof(data));
		
		if (g_bEnabled)
		{
			ConVars_Enable(name);
		}
	}
	else
	{
		LogError("Failed to find convar with name %s", name);
	}
}

static void ConVars_RemoveConVar(const char[] name)
{
	ConVar convar = FindConVar(name);
	if (convar)
	{
		if (g_bEnabled)
		{
			ConVars_Disable(name);
		}
		
		g_ConVars.Remove(name);
	}
	else
	{
		LogError("Failed to find convar with name %s", name);
	}
}

static void ConVars_Enable(const char[] name)
{
	ConVarData data;
	if (g_ConVars.GetArray(name, data, sizeof(data)))
	{
		ConVar convar = FindConVar(data.name);
		
		// Store the current value so we can later reset the convar to it
		convar.GetString(data.initial_value, sizeof(data.initial_value));
		g_ConVars.SetArray(name, data, sizeof(data));
		
		// Update the current value
		convar.SetString(data.value);
		convar.AddChangeHook(ConVarChanged_OnTrackedConVarChanged);
	}
	else
	{
		LogError("Failed to enable convar with name %s", name);
	}
}

static void ConVars_Disable(const char[] name)
{
	ConVarData data;
	if (g_ConVars.GetArray(name, data, sizeof(data)))
	{
		ConVar convar = FindConVar(data.name);
		
		g_ConVars.SetArray(name, data, sizeof(data));
		
		// Restore the convar value
		convar.RemoveChangeHook(ConVarChanged_OnTrackedConVarChanged);
		convar.SetString(data.initial_value);
	}
	else
	{
		LogError("Failed to disable convar with name %s", name);
	}
}

static void ConVarChanged_OnTrackedConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char[] name = new char[sizeof(ConVarData::name)];
	convar.GetName(name, sizeof(ConVarData::name));
	
	ConVarData data;
	if (g_ConVars.GetArray(name, data, sizeof(data)))
	{
		if (!StrEqual(newValue, data.value))
		{
			strcopy(data.initial_value, sizeof(data.initial_value), newValue);
			g_ConVars.SetArray(name, data, sizeof(data));
			
			// Restore our value
			convar.SetString(data.value);
		}
	}
}

static void ConVarChanged_OnEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bEnabled != convar.BoolValue)
	{
		TogglePlugin(convar.BoolValue);
	}
}
