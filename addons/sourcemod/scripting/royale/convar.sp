static ConVar mp_autoteambalance;
static ConVar mp_teams_unbalance_limit;
static ConVar mp_friendlyfire;
static ConVar tf_arena_first_blood;
static ConVar tf_avoidteammates;
static ConVar tf_dropped_weapon_lifetime;
static ConVar tf_max_health_boost;
static ConVar tf_powerup_mode;
static ConVar tf_spells_enabled;

void ConVar_Init()
{
	fr_healthmultiplier = CreateConVar("fr_healthmultiplier", "1.5", "Max health multiplier (rounds to lowest 5)", _, true, 0.0);
	fr_fistsdamagemultiplier = CreateConVar("fr_fistsdamagemultiplier", "0.62", "Starting fists damage multiplier", _, true, 0.0);
	fr_sectodeployparachute = CreateConVar("fr_sectodeployparachute", "2", "Whole second to deploy parachute after ejecting from battle bus", _, true, 1.0);
	
	fr_zone_startdisplay = CreateConVar("fr_zone_startdisplay", "60.0", "", _, true, 0.0);
	fr_zone_display = CreateConVar("fr_zone_display", "45.0", "", _, true, 0.0);
	fr_zone_shrink = CreateConVar("fr_zone_shrink", "60.0", "", _, true, 0.0);
	fr_zone_nextdisplay = CreateConVar("fr_zone_nextdisplay", "0.0", "", _, true, 0.0);
	
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_avoidteammates = FindConVar("tf_avoidteammates");
	tf_dropped_weapon_lifetime = FindConVar("tf_dropped_weapon_lifetime");
	tf_max_health_boost = FindConVar("tf_max_health_boost");
	tf_powerup_mode = FindConVar("tf_powerup_mode");
	tf_spells_enabled = FindConVar("tf_spells_enabled");
}

void ConVar_Toggle(bool enable)
{
	static bool toggled = false;
	
	static int autoteambalance;
	static int teamsUnbalanceLimit;
	static bool friendlyfire;
	static bool firstblood;
	static bool avoidteammates;
	static float droppedweaponlifetime;
	static float maxhealthboost;
	static bool powerupmode;
	static bool spellsenabled;
	
	if (enable && !toggled)
	{
		toggled = true;
		
		autoteambalance = mp_autoteambalance.IntValue;
		mp_autoteambalance.IntValue = 0;
		
		teamsUnbalanceLimit = mp_teams_unbalance_limit.IntValue;
		mp_teams_unbalance_limit.IntValue = 0;
		
		friendlyfire = mp_friendlyfire.BoolValue;
		mp_friendlyfire.BoolValue = true;
		
		firstblood = tf_arena_first_blood.BoolValue;
		tf_arena_first_blood.BoolValue = false;
		
		avoidteammates = tf_avoidteammates.BoolValue;
		tf_avoidteammates.BoolValue = false;
		
		droppedweaponlifetime = tf_dropped_weapon_lifetime.FloatValue;
		tf_dropped_weapon_lifetime.FloatValue = 99999.0;
		
		maxhealthboost = tf_max_health_boost.FloatValue;
		tf_max_health_boost.FloatValue = 2.25;
		
		powerupmode = tf_powerup_mode.BoolValue;
		tf_powerup_mode.BoolValue = true;
		
		spellsenabled = tf_spells_enabled.BoolValue;
		tf_spells_enabled.BoolValue = true;
	}
	else if (!enable && toggled)
	{
		toggled = false;
		
		mp_autoteambalance.IntValue = autoteambalance;
		mp_teams_unbalance_limit.IntValue = teamsUnbalanceLimit;
		mp_friendlyfire.BoolValue = friendlyfire;
		tf_arena_first_blood.BoolValue = firstblood;
		tf_avoidteammates.BoolValue = avoidteammates;
		tf_dropped_weapon_lifetime.FloatValue = droppedweaponlifetime;
		tf_max_health_boost.FloatValue = maxhealthboost;
		tf_powerup_mode.BoolValue = powerupmode;
		tf_spells_enabled.BoolValue = spellsenabled;
	}
}
