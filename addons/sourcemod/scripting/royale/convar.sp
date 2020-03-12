static ConVar mp_autoteambalance;
static ConVar mp_teams_unbalance_limit;
static ConVar mp_friendlyfire;
static ConVar tf_avoidteammates;

void ConVar_Init()
{
	fr_healthmultiplier = CreateConVar("fr_healthmultiplier", "1.5", "Max Health Multiplier (Rounded to lowest 5)", _, true, 0.0);
	
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	tf_avoidteammates = FindConVar("tf_avoidteammates");
}

void ConVar_Toggle(bool enable)
{
	static bool toggled = false;
	
	static int autoteambalance;
	static int teamsUnbalanceLimit;
	static bool friendlyfire;
	static bool avoidteammates;
	
	if (enable && !toggled)
	{
		toggled = true;
		
		autoteambalance = mp_autoteambalance.IntValue;
		mp_autoteambalance.IntValue = 0;
		
		teamsUnbalanceLimit = mp_teams_unbalance_limit.IntValue;
		mp_teams_unbalance_limit.IntValue = 0;
		
		friendlyfire = mp_friendlyfire.BoolValue;
		mp_friendlyfire.BoolValue = true;
		
		avoidteammates = tf_avoidteammates.BoolValue;
		tf_avoidteammates.BoolValue = false;
	}
	else if (!enable && toggled)
	{
		toggled = false;
		
		mp_autoteambalance.IntValue = autoteambalance;
		mp_teams_unbalance_limit.IntValue = teamsUnbalanceLimit;
		mp_friendlyfire.BoolValue = friendlyfire;
		tf_avoidteammates.BoolValue = avoidteammates;
	}
}
