ConVar mp_friendlyfire;
ConVar tf_avoidteammates;

void ConVar_Init()
{
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	tf_avoidteammates = FindConVar("tf_avoidteammates");
}

void ConVar_Toggle(bool enable)
{
	static bool toggled = false;
	
	static bool friendlyfire;
	static bool avoidteammates;
	
	if (enable && !toggled)
	{
		toggled = true;
		
		friendlyfire = mp_friendlyfire.BoolValue;
		mp_friendlyfire.BoolValue = true;
		
		avoidteammates = tf_avoidteammates.BoolValue;
		tf_avoidteammates.BoolValue = false;
	}
	else if (!enable && toggled)
	{
		toggled = false;
		
		mp_friendlyfire.BoolValue = friendlyfire;
		tf_avoidteammates.BoolValue = avoidteammates;
	}
}