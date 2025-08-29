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

#pragma newdecls required
#pragma semicolon 1

#define MAX_EVENT_NAME_LENGTH	32

static char g_aSoundPlayerKill[][] = 
{
	")vo/announcer_dec_kill01.mp3", 
	")vo/announcer_dec_kill02.mp3", 
	")vo/announcer_dec_kill03.mp3", 
	")vo/announcer_dec_kill04.mp3", 
	")vo/announcer_dec_kill05.mp3", 
	")vo/announcer_dec_kill06.mp3", 
	")vo/announcer_dec_kill07.mp3", 
	")vo/announcer_dec_kill08.mp3", 
	")vo/announcer_dec_kill09.mp3", 
	")vo/announcer_dec_kill10.mp3", 
	")vo/announcer_dec_kill11.mp3", 
	")vo/announcer_dec_kill12.mp3", 
	")vo/announcer_dec_kill13.mp3", 
	")vo/announcer_dec_kill14.mp3", 
	")vo/announcer_dec_kill15.mp3", 
};

void Events_Init()
{
	PSM_AddEventHook("player_spawn", OnGameEvent_player_spawn);
	PSM_AddEventHook("player_death", OnGameEvent_player_death, EventHookMode_Pre);
	PSM_AddEventHook("player_death", OnGameEventPost_player_death, EventHookMode_Post);
	PSM_AddEventHook("player_team", OnGameEvent_player_team, EventHookMode_Pre);
	PSM_AddEventHook("teamplay_round_start", OnGameEvent_teamplay_round_start);
	PSM_AddEventHook("teamplay_broadcast_audio", OnGameEvent_teamplay_broadcast_audio, EventHookMode_Pre);
}

void Events_Precache()
{
	for (int i = 0; i < sizeof(g_aSoundPlayerKill); i++)
	{
		PrecacheSound(g_aSoundPlayerKill[i]);
	}
}

static void OnGameEvent_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsPlayerAlive(client))
	{
		FRPlayer(client).SetPlayerState(FRPlayerState_Playing);
		
		// Create the starting fists
		int fists = GenerateDefaultItem(client, TF_DEFINDEX_FISTS);
		if (IsValidEntity(fists))
		{
			FRPlayer(client).EquipItem(fists);
			TF2Util_SetPlayerActiveWeapon(client, fists);
		}
		
		// Create the starting parachute
		int parachute = GenerateDefaultItem(client, TF_DEFINDEX_PARACHUTE);
		if (IsValidEntity(parachute))
		{
			FRPlayer(client).EquipItem(parachute);
			FRPlayer(client).m_bIsParachuting = true;
		}
		
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_TARGET_ID);
	}
}

static Action OnGameEvent_player_death(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	int userid = event.GetInt("userid");
	int victim = GetClientOfUserId(userid);
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	int death_flags = GetClientOfUserId(event.GetInt("death_flags"));
	bool silent_kill = event.GetBool("silent_kill");
	char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));
	
	// Fancier icon for medigun kills
	if (StrEqual(weapon, "medigun"))
	{
		strcopy(weapon, sizeof(weapon), "merasmus_zap");
		event.SetString("weapon", weapon);
	}
	
	// If our assister was using a medigun, do not actually make them the assister
	if (assister != 0)
	{
		int assisterWeapon = GetEntPropEnt(assister, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(assisterWeapon) && IsWeaponOfID(assisterWeapon, TF_WEAPON_MEDIGUN))
		{
			assister = -1;
			event.SetInt("assister", assister);
			event.SetString("assister_fallback", "");
		}
	}
	
	// Disable broadcasting to control who receives the event
	event.BroadcastDisabled = true;
	
	// Only send the event to players involved in the kill, everyone else gets a generic "death" notification
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (!IsValidClient(attacker) || client == victim || client == attacker || client == assister || !IsPlayerAlive(client))
		{
			event.FireToClient(client);
		}
		else if (!silent_kill)
		{
			Event hNewEvent = CreateEvent("player_death");
			if (hNewEvent)
			{
				hNewEvent.SetInt("userid", userid);
				hNewEvent.FireToClient(client);
			}
		}
	}
	
	if (!(death_flags & TF_DEATHFLAG_DEADRINGER))
	{
		SetEntProp(victim, Prop_Send, "m_iHideHUD", GetEntProp(victim, Prop_Send, "m_iHideHUD") & ~HIDEHUD_TARGET_ID);
	}
	
	return Plugin_Changed;
}

static void OnGameEventPost_player_death(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	int userid = event.GetInt("userid");
	int victim = GetClientOfUserId(userid);
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int death_flags = event.GetInt("death_flags");
	
	if (!(death_flags & TF_DEATHFLAG_DEADRINGER))
	{
		for (int iLoadoutSlot = 0; iLoadoutSlot <= LOADOUT_POSITION_PDA2; ++iLoadoutSlot)
		{
			int entity = GetEntityForLoadoutSlot(victim, iLoadoutSlot);
			
			if (!IsValidEntity(entity))
				continue;
			
			if (!ShouldDropItem(victim, entity))
				continue;
			
			float vecOrigin[3], vecAngles[3];
			if (!SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(victim, entity, vecOrigin, vecAngles))
				continue;
			
			char szWorldModel[PLATFORM_MAX_PATH];
			if (GetItemWorldModel(entity, szWorldModel, sizeof(szWorldModel)))
			{
				int droppedWeapon = CreateDroppedWeapon(vecOrigin, vecAngles, szWorldModel, GetEntityAddress(entity) + FindItemOffset(entity));
				if (IsValidEntity(droppedWeapon))
				{
					if (TF2Util_IsEntityWeapon(entity))
					{
						SDKCall_CTFDroppedWeapon_InitDroppedWeapon(droppedWeapon, victim, entity, false);
					}
					else if (TF2Util_IsEntityWearable(entity))
					{
						InitDroppedWearable(droppedWeapon, victim, entity, false);
					}
				}
			}
		}
		
		if (FRPlayer(victim).GetPlayerState() == FRPlayerState_Playing)
		{
			// Set player state to dead now
			FRPlayer(victim).SetPlayerState(FRPlayerState_Dying);
			
			// Delay team switch so ragdolls can appear as the correct team
			float flDelay = TF_DEATH_ANIMATION_TIME + spec_freeze_traveltime.FloatValue;
			CreateTimer(flDelay, Timer_MovePlayerToDeadTeam, userid);
		}
		
		float vecSrc[3];
		CBaseEntity(victim).WorldSpaceCenter(vecSrc);
		
		// Drop a medium health kit on death
		int medKit = CreateEntityByName("item_healthkit_medium");
		if (IsValidEntity(medKit))
		{
			DispatchKeyValueVector(medKit, "origin", vecSrc);
			
			if (DispatchSpawn(medKit))
			{
				float vecImpulse[3];
				vecImpulse[0] = GetRandomFloat(-1.0, 1.0);
				vecImpulse[1] = GetRandomFloat(-1.0, 1.0);
				vecImpulse[2] = 1.0;
				
				NormalizeVector(vecImpulse, vecImpulse);
				ScaleVector(vecImpulse, 250.0);
				
				SDKCall_CTFPowerup_DropSingleInstance(medKit, vecImpulse, victim, 0.0);
			}
		}
	}
	
	if (IsValidClient(attacker) && attacker != victim && BattleBus_IsActive())
	{
		EmitSoundToAll(g_aSoundPlayerKill[GetRandomInt(0, sizeof(g_aSoundPlayerKill) - 1)], BattleBus_GetEntity(), SNDCHAN_VOICE_BASE, 150);
	}
}

static void Timer_MovePlayerToDeadTeam(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return;
	
	if (IsPlayerAlive(client))
		return;
	
	if (FRPlayer(client).m_nPlayerState != FRPlayerState_Dying)
		return;
	
	if (TF2_GetClientTeam(client) != TFTeam_Red)
		return;
	
	FRPlayer(client).SetPlayerState(FRPlayerState_Waiting);
	TF2_ChangeClientTeam(client, TFTeam_Blue);
}

static Action OnGameEvent_player_team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (!IsInWaitingForPlayers() && team != TFTeam_Red)
	{
		FRPlayer(client).SetPlayerState(FRPlayerState_Waiting);
	}
	
	event.BroadcastDisabled = true;
	return Plugin_Changed;
}

static void OnGameEvent_teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	// Stop the round end sounds
	EmitGameSoundToAll("MatchMaking.MatchEndWinMusicCasual", _, SND_STOP | SND_STOPLOOPING);
	EmitGameSoundToAll("MatchMaking.MatchEndLoseMusicCasual", _, SND_STOP | SND_STOPLOOPING);
	
	// Should the game start?
	if (g_nRoundState == FRRoundState_Setup || g_nRoundState == FRRoundState_RoundEnd)
	{
		if (ShouldGoToSetup())
		{
			OnRoundStart();
		}
		else
		{
			g_nRoundState = FRRoundState_WaitingForPlayers;
		}
	}
}

static Action OnGameEvent_teamplay_broadcast_audio(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	
	if (StrEqual(sound, "Game.YourTeamWon"))
	{
		event.SetString("sound", "MatchMaking.MatchEndWinMusicCasual");
		return Plugin_Changed;
	}
	else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
	{
		event.SetString("sound", "MatchMaking.MatchEndLoseMusicCasual");
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
