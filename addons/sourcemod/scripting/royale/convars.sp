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

void ConVars_Init()
{
	fr_setup_length = CreateConVar("fr_setup_length", "15", "Time before the battle bus takes off.");
	fr_truce_duration = CreateConVar("fr_truce_duration", "60", "Length of the truce period.");
	fr_crate_open_time = CreateConVar("fr_crate_open_time", "3", "Amount of time to open a crate.");
	fr_crate_open_range = CreateConVar("fr_crate_open_range", "64", "Range in HU that players may open crates from.");
	fr_crate_max_drops = CreateConVar("fr_crate_max_drops", "1", "Maximum amount of drops a player can receive from a crate.");
	fr_crate_max_extra_drops = CreateConVar("fr_crate_max_extra_drops", "2", "Maximum amount of extra drops a player can receive from a crate.");
	fr_max_ammo_boost = CreateConVar("fr_max_ammo_boost", "1.5", "Maximum ammo factor that players are allowed to carry.", _, true, 1.0);
	fr_parachute_auto_height = CreateConVar("fr_parachute_auto_height", "2500", "Minimum height from the ground for parachute to auto-activate.");
	fr_fists_damage_multiplier = CreateConVar("fr_fists_damage_multiplier", "0.7", "Damage multiplier to starting fists.");
	fr_medigun_damage = CreateConVar("fr_medigun_damage", "2", "Amount of damage that Medi Guns should deal per tick.");
	fr_dropped_weapon_ammo_percentage = CreateConVar("fr_dropped_weapon_ammo_percentage", "0.25", "How much of its maximum ammo a dropped weapon should start with.");
	
	fr_health_multiplier[TFClass_Scout] = CreateConVar("fr_health_multiplier_scout", "1.6", "Multiplier to maximum health for Scout.");
	fr_health_multiplier[TFClass_Sniper] = CreateConVar("fr_health_multiplier_sniper", "2", "Multiplier to maximum health for Sniper.");
	fr_health_multiplier[TFClass_Soldier] = CreateConVar("fr_health_multiplier_soldier", "1.75", "Multiplier to maximum health for Soldier.");
	fr_health_multiplier[TFClass_DemoMan] = CreateConVar("fr_health_multiplier_demoman", "2", "Multiplier to maximum health for Demoman.");
	fr_health_multiplier[TFClass_Medic] = CreateConVar("fr_health_multiplier_medic", "1.5", "Multiplier to maximum health for Medic.");
	fr_health_multiplier[TFClass_Heavy] = CreateConVar("fr_health_multiplier_heavy", "1.75", "Multiplier to maximum health for Heavy.");
	fr_health_multiplier[TFClass_Pyro] = CreateConVar("fr_health_multiplier_pyro", "1.6", "Multiplier to maximum health for Pyro.");
	fr_health_multiplier[TFClass_Spy] = CreateConVar("fr_health_multiplier_spy", "1.6", "Multiplier to maximum health for Spy.");
	fr_health_multiplier[TFClass_Engineer] = CreateConVar("fr_health_multiplier_engineer", "1.6", "Multiplier to maximum health for Engineer.");
	
	mp_disable_respawn_times = FindConVar("mp_disable_respawn_times");
	spec_freeze_traveltime = FindConVar("spec_freeze_traveltime");
	
	PSM_AddEnforcedConVar("tf_powerup_mode", "1");
	PSM_AddEnforcedConVar("tf_weapon_criticals", "0");
	PSM_AddEnforcedConVar("tf_parachute_maxspeed_xy", "600.0f");
	PSM_AddEnforcedConVar("tf_parachute_maxspeed_z", "-200.0f");
	PSM_AddEnforcedConVar("tf_spawn_glows_duration", "0");
	PSM_AddEnforcedConVar("mp_teams_unbalance_limit", "0");
	PSM_AddEnforcedConVar("mp_autoteambalance", "0");
	PSM_AddEnforcedConVar("mp_scrambleteams_auto", "0");
	PSM_AddEnforcedConVar("mp_forcecamera", "0");
	PSM_AddEnforcedConVar("mp_friendlyfire", "1");
}
