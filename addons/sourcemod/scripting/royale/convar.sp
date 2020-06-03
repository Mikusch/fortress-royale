enum struct ConVarInfo
{
	ConVar convar;
	float value;
	float defaultValue;
}

static ArrayList ConVars;

void ConVar_Init()
{
	fr_healthmultiplier = CreateConVar("fr_healthmultiplier", "2.0", "Max health multiplier", _, true, 0.0);
	fr_fistsdamagemultiplier = CreateConVar("fr_fistsdamagemultiplier", "0.62", "Starting fists damage multiplier", _, true, 0.0);
	fr_sectodeployparachute = CreateConVar("fr_sectodeployparachute", "2", "Whole second to deploy parachute after ejecting from battle bus", _, true, 1.0);
	
	fr_zone_startdisplay = CreateConVar("fr_zone_startdisplay", "60.0", "", _, true, 0.0);
	fr_zone_display = CreateConVar("fr_zone_display", "45.0", "", _, true, 0.0);
	fr_zone_shrink = CreateConVar("fr_zone_shrink", "60.0", "", _, true, 0.0);
	fr_zone_nextdisplay = CreateConVar("fr_zone_nextdisplay", "0.0", "", _, true, 0.0);
	
	ConVars = new ArrayList(sizeof(ConVarInfo));
	
	ConVar_Add("mp_autoteambalance", 0.0);
	ConVar_Add("mp_teams_unbalance_limit", 0.0);
	ConVar_Add("mp_forcecamera", 0.0);
	ConVar_Add("mp_friendlyfire", 1.0);
	ConVar_Add("tf_arena_first_blood", 0.0);
	ConVar_Add("tf_avoidteammates", 0.0);
	ConVar_Add("tf_dropped_weapon_lifetime", 99999.0);
	ConVar_Add("tf_max_health_boost", 4.0);
	ConVar_Add("tf_spells_enabled", 1.0);
}

void ConVar_Add(const char[] name, float value)
{
	ConVarInfo info;
	info.convar = FindConVar(name);
	info.value = value;
	ConVars.PushArray(info);
}

void ConVar_Enable()
{
	for (int i = 0; i < ConVars.Length; i++)
	{
		ConVarInfo info;
		ConVars.GetArray(i, info);
		info.defaultValue = info.convar.FloatValue;
		ConVars.SetArray(i, info);
		
		info.convar.SetFloat(info.value);
		info.convar.AddChangeHook(ConVar_OnChanged);
	}
}

void ConVar_Disable()
{
	for (int i = 0; i < ConVars.Length; i++)
	{
		ConVarInfo info;
		ConVars.GetArray(i, info);
		
		info.convar.RemoveChangeHook(ConVar_OnChanged);
		info.convar.SetFloat(info.defaultValue);
	}
}

void ConVar_OnChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int index = ConVars.FindValue(convar, ConVarInfo::convar);
	if (index != -1)
	{
		ConVarInfo info;
		ConVars.GetArray(index, info);
		float value = StringToFloat(newValue);
		
		if (value != info.value)
			info.convar.SetFloat(info.value);
	}
}