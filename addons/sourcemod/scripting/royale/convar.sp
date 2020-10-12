enum struct ConVarInfo
{
	ConVar convar;
	float value;
	float defaultValue;
}

static ArrayList g_ConVarInfo;

void ConVar_Init()
{
	fr_enable = CreateConVar("fr_enable", "-1", "-1 to enable based on map config existance, 0 to force disable, 1 to force enable", _, true, -1.0, true, 1.0);
	fr_enable.AddChangeHook(ConVar_EnableChanged);
	
	//tag mismatch haha
	fr_healthmultiplier[1] = CreateConVar("fr_healthmultiplier_scout", "1.6", "Max health multiplier for Scout", _, true, 0.0);
	fr_healthmultiplier[2] = CreateConVar("fr_healthmultiplier_sniper", "2.4", "Max health multiplier for Sniper", _, true, 0.0);
	fr_healthmultiplier[3] = CreateConVar("fr_healthmultiplier_soldier", "2.0", "Max health multiplier for Soldier", _, true, 0.0);
	fr_healthmultiplier[4] = CreateConVar("fr_healthmultiplier_demoman", "2.0", "Max health multiplier for Demoman", _, true, 0.0);
	fr_healthmultiplier[5] = CreateConVar("fr_healthmultiplier_medic", "1.6667", "Max health multiplier for Medic", _, true, 0.0);
	fr_healthmultiplier[6] = CreateConVar("fr_healthmultiplier_heavy", "1.5", "Max health multiplier for Heavy", _, true, 0.0);
	fr_healthmultiplier[7] = CreateConVar("fr_healthmultiplier_pyro", "2.0", "Max health multiplier for Pyro", _, true, 0.0);
	fr_healthmultiplier[8] = CreateConVar("fr_healthmultiplier_spy", "2.8", "Max health multiplier for Spy", _, true, 0.0);
	fr_healthmultiplier[9] = CreateConVar("fr_healthmultiplier_engineer", "2.4", "Max health multiplier for Engineer", _, true, 0.0);
	
	fr_fistsdamagemultiplier = CreateConVar("fr_fistsdamagemultiplier", "0.62", "Starting fists damage multiplier", _, true, 0.0);
	fr_sectodeployparachute = CreateConVar("fr_sectodeployparachute", "2", "Whole second to deploy parachute after ejecting from battle bus", _, true, 1.0);
	fr_classfilter = CreateConVar("fr_classfilter", "1", "Enable class filtering, restricting weapon loots by classes. Disabling may cause several issues", _, true, 0.0, true, 1.0);
	
	fr_zone_startdisplay = CreateConVar("fr_zone_startdisplay", "30.0", "Seconds from round start to start zone display", _, true, 0.0);
	fr_zone_startdisplay_player = CreateConVar("fr_zone_startdisplay_player", "1.0", "Extra seconds on every player from round start to start zone display", _, true, 0.0);
	fr_zone_display = CreateConVar("fr_zone_display", "15.0", "Seconds to display next zone before shrink", _, true, 0.0);
	fr_zone_display_player = CreateConVar("fr_zone_display_player", "0.5", "Extra seconds on every player to display next zone before shrink", _, true, 0.0);
	fr_zone_shrink = CreateConVar("fr_zone_shrink", "20.0", "Seconds to shrink zone to next level", _, true, 0.0);
	fr_zone_shrink_player = CreateConVar("fr_zone_shrink_player", "0.67", "Extra seconds on every player to shrink zone to next level", _, true, 0.0);
	fr_zone_nextdisplay = CreateConVar("fr_zone_nextdisplay", "0.0", "Seconds after shrink to display next zone", _, true, 0.0);
	fr_zone_nextdisplay_player = CreateConVar("fr_zone_nextdisplay_player", "0.0", "Extra seconds on every player after shrink to display next zone", _, true, 0.0);
	fr_zone_damagemultiplier = CreateConVar("fr_zone_damagemultiplier", "0.25", "", _, true, 0.0);
	
	fr_truce_duration = CreateConVar("fr_truce_duration", "60", "How long the truce at the beginning of the round should last", _, true, 0.0);
	
	g_ConVarInfo = new ArrayList(sizeof(ConVarInfo));
	
	ConVar_Add("mp_autoteambalance", 0.0);
	ConVar_Add("mp_teams_unbalance_limit", 0.0);
	ConVar_Add("mp_forcecamera", 0.0);
	ConVar_Add("mp_friendlyfire", 1.0);
	ConVar_Add("mp_respawnwavetime", 99999.0);
	ConVar_Add("tf_avoidteammates", 0.0);
	ConVar_Add("tf_dropped_weapon_lifetime", 99999.0);
	ConVar_Add("tf_helpme_range", -1.0);
	ConVar_Add("tf_max_health_boost", 4.0);
	ConVar_Add("tf_parachute_maxspeed_xy", 600.0);
	ConVar_Add("tf_parachute_maxspeed_z", -200.0);
	ConVar_Add("tf_spawn_glows_duration", 0.0);
	ConVar_Add("tf_spells_enabled", 1.0);
	ConVar_Add("tf_weapon_criticals", 0.0);
}

void ConVar_Add(const char[] name, float value)
{
	ConVarInfo info;
	info.convar = FindConVar(name);
	info.value = value;
	g_ConVarInfo.PushArray(info);
}

void ConVar_Enable()
{
	for (int i = 0; i < g_ConVarInfo.Length; i++)
	{
		ConVarInfo info;
		g_ConVarInfo.GetArray(i, info);
		info.defaultValue = info.convar.FloatValue;
		g_ConVarInfo.SetArray(i, info);
		
		info.convar.SetFloat(info.value);
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
		info.convar.SetFloat(info.defaultValue);
	}
}

void ConVar_OnChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int index = g_ConVarInfo.FindValue(convar, ConVarInfo::convar);
	if (index != -1)
	{
		ConVarInfo info;
		g_ConVarInfo.GetArray(index, info);
		float value = StringToFloat(newValue);
		
		if (value != info.value)
			info.convar.SetFloat(info.value);
	}
}

public void ConVar_EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshEnable();
}
