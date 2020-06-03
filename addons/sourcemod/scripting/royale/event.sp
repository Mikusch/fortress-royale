void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_dropobject", Event_DropObject);
	HookEvent("object_destroyed", Event_ObjectDestroyed, EventHookMode_Pre);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//Check if there players in red and blu
	if (TF2_RebalanceTeams())
		return;
	
	for (int client = 1; client <= MaxClients; client++)
	{
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
	
	BattleBus_NewPos();
	Zone_RoundStart();
}

public Action Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	BattleBus_SpawnProp();
	Zone_RoundArenaStart();
	Loot_SpawnCratesInWorld();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
			BattleBus_SpectateBus(client);
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetClientTeam(client) <= TFTeam_Spectator)
		return;
	
	TF2_CheckClientWeapons(client);
	
	//Create starting fists weapon
	int fists = TF2_CreateWeapon(INDEX_FISTS, _, g_fistsClassname[TF2_GetPlayerClass(client)]);
	if (fists > MaxClients)
	{
		TF2_EquipWeapon(client, fists);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", fists);
	}
	
	//Create spellbook so spells can actually be created
	int spellbook = TF2_CreateWeapon(INDEX_SPELLBOOK);
	if (spellbook > MaxClients)
		TF2_EquipWeapon(client, spellbook);
	
	//Create starting parachute
	int parachute = TF2_CreateWeapon(INDEX_BASEJUMPER, _, "tf_weapon_parachute_secondary");
	if (parachute > MaxClients)
		TF2_EquipWeapon(client, parachute);
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
		FRPlayer(victim).PlayerState = PlayerState_Dead;
		CreateTimer(0.1, Timer_SetClientDead, GetClientSerial(victim));
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