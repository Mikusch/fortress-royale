void Event_Init()
{
	HookEvent("teamplay_broadcast_audio", Event_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("fish_notice", Event_FishNotice, EventHookMode_Pre);
	HookEvent("fish_notice__arm", Event_FishNotice, EventHookMode_Pre);
	HookEvent("slap_notice", Event_FishNotice, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_dropobject", Event_DropObject);
	HookEvent("object_destroyed", Event_ObjectDestroyed, EventHookMode_Pre);
}

public Action Event_Broadcast_Audio(Event event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	
	if (StrEqual(sound, "Game.YourTeamWon") || StrEqual(sound, "Game.YourTeamLost"))
	{
		event.SetString("sound", GetRandomInt(0, 1) ? "MatchMaking.MatchEndBlueWinMusic" : "MatchMaking.MatchEndRedWinMusic");
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		//Clear round win music
		StopSound(client, SNDCHAN_STATIC, "ui/mm_match_end_blue_win_music.wav");
		StopSound(client, SNDCHAN_STATIC, "ui/mm_match_end_red_win_music.wav");
		
		FRPlayer(client).PlayerState = PlayerState_Waiting;
		FRPlayer(client).Killstreak = 0;
		
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
		{
			if (IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Send, "m_lifeState", LIFE_DEAD);
				TF2_ChangeClientTeam(client, TFTeam_Spectator);	// Just to make client actually dead
			}
			
			//Move all non-spectators to dead team
			TF2_ChangeClientTeam(client, TFTeam_Dead);
		}
	}
	
	Zone_RoundStart();	//Reset zone pos
	BattleBus_NewPos();	//Calculate pos from zone's restarted pos
	Vehicles_SpawnVehiclesInWorld();
	
	g_RoundState = FRRoundState_NeedPlayers;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(client) <= TFTeam_Spectator)
		return;
	
	TF2_CheckClientWeapons(client);
	TFClassType class = TF2_GetPlayerClass(client);
	
	//Create starting fists weapon
	int fists = TF2_CreateWeapon(INDEX_FISTS, g_fistsClassname[class]);
	if (fists > MaxClients)
	{
		TF2_EquipWeapon(client, fists);
		TF2_SwitchActiveWeapon(client, fists);
	}
	
	//Create spellbook so spells can actually be created
	int spellbook = TF2_CreateWeapon(INDEX_SPELLBOOK);
	if (spellbook > MaxClients)
		TF2_EquipWeapon(client, spellbook);
	
	//Create starting parachute
	int parachute = TF2_CreateWeapon(INDEX_BASEJUMPER, "tf_weapon_parachute_secondary");
	if (parachute > MaxClients)
		TF2_EquipWeapon(client, parachute);
	
	if (!fr_classfilter.BoolValue && class != TFClass_Engineer)
	{
		//Give toolbox to non-engineer if class filter is off
		Address item = SDKCall_GetLoadoutItem(client, TFClass_Engineer, 4);	//Uses econ slot, 4 for toolbox
		if (item)
		{
			int weapon = TF2_GiveNamedItem(client, item, TFClass_Engineer);
			
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Dispenser));
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Teleporter));
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Sentry));
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", false, _, view_as<int>(TFObject_Sapper));
			
			TF2_EquipWeapon(client, weapon);
		}
	}
}

public Action Event_FishNotice(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
	//Only show event to some players
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (client == victim || client == attacker || client == assister || !IsPlayerAlive(client)))
			event.FireToClient(client);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	bool deadringer = !!(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER);
	
	if (attacker != victim && event.GetInt("weapon_def_index") == INDEX_FISTS && attacker == event.GetInt("inflictor_entindex"))
	{
		//Custom fists reports it incorrectly
		//TODO fix buildings kill aswell, those dont have 'weapon_def_index'
		event.SetString("weapon_logclassname", "fists");
		event.SetString("weapon", "fists");
		event.SetInt("weaponid", TF_WEAPON_FISTS);
	}
	
	event.SetInt("kill_streak_victim", FRPlayer(victim).Killstreak);
	
	if (0 < assister <= MaxClients)
		event.SetInt("kill_streak_assist", FRPlayer(assister).Killstreak);
	
	if (0 < attacker <= MaxClients && victim != attacker)
	{
		if (!deadringer)
		{
			FRPlayer(attacker).Killstreak++;
			event.SetInt("kill_streak_total", FRPlayer(attacker).Killstreak);
			event.SetInt("kill_streak_wep", FRPlayer(attacker).Killstreak);
		}
		else
		{
			//Dead Ringer, make killer think a killstreak is done but without actually increasing killstreak
			event.SetInt("kill_streak_total", FRPlayer(attacker).Killstreak + 1);
			event.SetInt("kill_streak_wep", FRPlayer(attacker).Killstreak + 1);
		}
		
		event.BroadcastDisabled = true;
		
		//Create event for some clients to only show victim
		Event unknown = CreateEvent("player_death", true);
		unknown.SetInt("userid", GetClientUserId(victim));
		unknown.SetInt("kill_streak_victim", FRPlayer(victim).Killstreak);
		unknown.SetInt("kill_streak_total", FRPlayer(victim).Killstreak);
		unknown.SetInt("kill_streak_wep", FRPlayer(victim).Killstreak);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				if (client == victim || client == attacker || client == assister || !IsPlayerAlive(client))
					event.FireToClient(client);		//Allow see full killfeed
				else
					unknown.FireToClient(client);	//Only show who victim died
			}
		}
		
		unknown.Cancel();
	}
	else
	{
		//No valid attacker, lets use that to display victim's killstreak
		event.SetInt("kill_streak_total", FRPlayer(victim).Killstreak);
		event.SetInt("kill_streak_wep", FRPlayer(victim).Killstreak);
	}
	
	if (!deadringer)
	{
		float origin[3], angles[3];
		GetClientEyePosition(victim, origin);
		GetClientEyeAngles(victim, angles);
		
		origin[2] -= 20.0;
		
		//Drop all weapons
		int weapon, pos;
		while (TF2_GetItem(victim, weapon, pos))
		{
			if (TF2_ShouldDropWeapon(victim, weapon))
				TF2_CreateDroppedWeapon(victim, weapon, false, origin, angles);
		}
		
		//Drop medium health kit
		TF2_DropItem(victim, "item_healthkit_medium");
		
		Vehicles_ExitVehicle(victim);
		FRPlayer(victim).PlayerState = PlayerState_Dead;
		CreateTimer(0.5, Timer_SetClientDead, GetClientSerial(victim));
	}
}

public Action Event_DropObject(Event event, const char[] name, bool dontBroadcast)
{
	//One of the hook caused building to be switched to spectator team, switch back to correct team
	int client = GetClientOfUserId(event.GetInt("userid"));
	int building = event.GetInt("index");
	if (0 < client <= MaxClients && IsClientInGame(client))
	{
		TF2_ChangeTeam(building, FRPlayer(client).Team);
		SetEntProp(building, Prop_Send, "m_nSkin", view_as<int>(FRPlayer(client).Team) - 2);
	}
}

public Action Event_ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
	event.BroadcastDisabled = true;
	
	//Only show killfeed to clients whos part of this or spectators
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (client == victim || client == attacker || client == assister || !IsPlayerAlive(client)))
			event.FireToClient(client);
	}
}

public Action Timer_SetClientDead(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (0 < client <=  MaxClients && IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator && FRPlayer(client).PlayerState == PlayerState_Dead)
		TF2_ChangeClientTeam(client, TFTeam_Dead);
}