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

#define GAMESOUND_WIN_MUSIC		"MatchMaking.MatchEndWinMusicCasual"
#define GAMESOUND_LOSE_MUSIC	"MatchMaking.MatchEndLoseMusicCasual"

enum struct EventInfo
{
	char name[64];
	EventHook callback;
	EventHookMode mode;
	bool force;
	bool hooked;
}

static ArrayList g_EventInfo;

void Event_Init()
{
	g_EventInfo = new ArrayList(sizeof(EventInfo));
	
	Event_Add("teamplay_round_start", Event_RoundStart);
	Event_Add("teamplay_setup_finished", Event_SetupFinished);
	Event_Add("teamplay_broadcast_audio", Event_BroadcastAudio, EventHookMode_Pre);
	Event_Add("player_team", Event_PlayerTeam, EventHookMode_Pre);
	Event_Add("player_spawn", Event_PlayerSpawn);
	Event_Add("fish_notice", Event_FishNotice, EventHookMode_Pre);
	Event_Add("fish_notice__arm", Event_FishNotice, EventHookMode_Pre);
	Event_Add("slap_notice", Event_FishNotice, EventHookMode_Pre, false);
	Event_Add("player_death", Event_PlayerDeath, EventHookMode_Pre);
	Event_Add("object_destroyed", Event_ObjectDestroyed, EventHookMode_Pre);
}

void Event_Add(const char[] name, EventHook callback, EventHookMode mode = EventHookMode_Post, bool force = true)
{
	EventInfo info;
	strcopy(info.name, sizeof(info.name), name);
	info.callback = callback;
	info.mode = mode;
	info.force = force;
	g_EventInfo.PushArray(info);
}

void Event_Enable()
{
	int length = g_EventInfo.Length;
	for (int i = 0; i < length; i++)
	{
		EventInfo info;
		g_EventInfo.GetArray(i, info);
		
		if (info.force)
		{
			HookEvent(info.name, info.callback, info.mode);
			info.hooked = true;
		}
		else
		{
			info.hooked = HookEventEx(info.name, info.callback, info.mode);
		}
		
		g_EventInfo.SetArray(i, info);
	}
}

void Event_Disable()
{
	int length = g_EventInfo.Length;
	for (int i = 0; i < length; i++)
	{
		EventInfo info;
		g_EventInfo.GetArray(i, info);
		
		if (info.hooked)
		{
			UnhookEvent(info.name, info.callback, info.mode);
			info.hooked = false;
			g_EventInfo.SetArray(i, info);
		}
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_RoundState = FRRoundState_Waiting;
	
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
	//Create player destruction logic for Demoman beer mechanic
	int logic = CreateEntityByName("tf_logic_player_destruction");
	if (IsValidEntity(logic))
	{
		DispatchKeyValue(logic, "prop_model_name", BOTTLE_PICKUP_MODEL);
		DispatchKeyValue(logic, "prop_drop_sound", BOTTLE_DROP_SOUND);
		DispatchKeyValue(logic, "prop_pickup_sound", BOTTLE_PICKUP_SOUND);
		DispatchKeyValue(logic, "min_points", "32");
		DispatchKeyValue(logic, "flag_reset_delay", "30");
		DispatchSpawn(logic);
	}
	
	//Stop previous round end music
	EmitGameSoundToAll(GAMESOUND_WIN_MUSIC, _, SND_STOPLOOPING);
	EmitGameSoundToAll(GAMESOUND_LOSE_MUSIC, _, SND_STOPLOOPING);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		FRPlayer(client).PlayerState = PlayerState_Waiting;
		FRPlayer(client).Killstreak = 0;
		
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
		{
			if (IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Send, "m_lifeState", LIFE_DEAD);
				TF2_ChangeClientTeamSilent(client, TFTeam_Spectator);	// Just to make client actually dead
			}
			
			//Move all non-spectators to dead team
			TF2_ChangeClientTeamSilent(client, TFTeam_Dead);
		}
	}
	
	Zone_RoundStart();	//Reset zone pos
	BattleBus_NewPos();	//Calculate pos from zone's restarted pos
}

public Action Event_SetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	if (fr_truce_duration.FloatValue > 0.0)
		Truce_Start(fr_truce_duration.FloatValue);
}

public Action Event_BroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	
	if (StrEqual(sound, "Game.YourTeamWon"))
	{
		event.SetString("sound", GAMESOUND_WIN_MUSIC);
		return Plugin_Changed;
	}
	else if (StrEqual(sound, "Game.YourTeamLost"))
	{
		event.SetString("sound", GAMESOUND_LOSE_MUSIC);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (g_ChangeTeamSilent)
		event.BroadcastDisabled = true;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(client) <= TFTeam_Spectator)
		return;
	
	TF2_CreateGlow(client);
	TF2_CheckClientWeapons(client);
	TFClassType class = TF2_GetPlayerClass(client);
	
	//Create starting fists weapon
	int fists = TF2_CreateWeapon(INDEX_FISTS, g_FistsClassnames[class]);
	if (fists > MaxClients)
	{
		TF2_EquipWeapon(client, fists);
		TF2_SwitchActiveWeapon(client, fists);
	}
	
	//Create spellbook if player dont have one equipped
	if (TF2_GetItemByClassname(client, "tf_weapon_spellbook") == -1)
	{
		int spellbook = TF2_CreateWeapon(INDEX_SPELLBOOK);
		if (spellbook > MaxClients)
			TF2_EquipWeapon(client, spellbook);
	}
	
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
	
	//Nerf all powerups this player picks up
	TF2_AddCondition(client, TFCond_PowerupModeDominant, TFCondDuration_Infinite);
}

public Action Event_FishNotice(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
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
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	int deathflags = event.GetInt("death_flags");
	bool silentkill = event.GetBool("silent_kill");
	
	//Remove silent kill stuff
	bool deadringer = !!(deathflags & TF_DEATHFLAG_DEADRINGER);
	if (deadringer)
		event.SetInt("death_flags", deathflags &= ~TF_DEATHFLAG_DEADRINGER);
	
	if (silentkill)
		event.SetBool("silent_kill", false);
	
	if (attacker != victim && event.GetInt("weapon_def_index") == INDEX_FISTS && attacker == event.GetInt("inflictor_entindex"))
	{
		//Custom fists reports it incorrectly
		//TODO fix buildings kill aswell, those dont have 'weapon_def_index'
		event.SetString("weapon_logclassname", "fists");
		event.SetString("weapon", "fists");
		event.SetInt("weaponid", TF_WEAPON_FISTS);
	}
	
	if (event.GetInt("damagebits") & DMG_VEHICLE)	//choo choo
		event.SetString("weapon", "vehicle");
	
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
	}
	else
	{
		//No valid attacker, lets use that to display victim's killstreak
		event.SetInt("kill_streak_total", FRPlayer(victim).Killstreak);
		event.SetInt("kill_streak_wep", FRPlayer(victim).Killstreak);
	}
	
	//Override events so we can display to whoever clients
	event.BroadcastDisabled = true;
	
	Event unknown = CreateEvent("player_death", true);
	unknown.SetInt("userid", GetClientUserId(victim));
	unknown.SetInt("kill_streak_victim", FRPlayer(victim).Killstreak);
	unknown.SetInt("kill_streak_total", FRPlayer(victim).Killstreak);
	unknown.SetInt("kill_streak_wep", FRPlayer(victim).Killstreak);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (attacker <= 0 || client == victim || client == attacker || client == assister || !IsPlayerAlive(client))
			{
				//If deadringer, dont show any killfeed to victim and dead players
				if (!deadringer || (client != victim && IsPlayerAlive(client)))
					event.FireToClient(client);		//Allow see full killfeed
			}
			else if (!silentkill)
			{
				unknown.FireToClient(client);	//Only show who victim died
			}
		}
	}
	
	unknown.Cancel();
	
	//Drop all weapons
	int weapon, pos;
	while (TF2_GetItem(victim, weapon, pos))
	{
		if (TF2_ShouldDropWeapon(victim, weapon))
		{
			float origin[3], angles[3];
			if (SDKCall_CalculateAmmoPackPositionAndAngles(victim, weapon, origin, angles))
				TF2_CreateDroppedWeapon(victim, weapon, false, origin, angles);
		}
	}
	
	if (!deadringer)
	{
		//Drop small health kit
		TF2_DropItem(victim, "item_healthkit_small");
		
		FRPlayer(victim).PlayerState = PlayerState_Dead;
		CreateTimer(0.5, Timer_SetClientDead, GetClientSerial(victim));
	}
}

public Action Event_ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
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
		TF2_ChangeClientTeamSilent(client, TFTeam_Dead);
}
