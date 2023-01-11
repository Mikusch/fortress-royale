/**
 * Copyright (C) 2022  Mikusch
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

enum struct EventData
{
	char name[MAX_EVENT_NAME_LENGTH];
	EventHook callback;
	EventHookMode mode;
}

ArrayList g_Events;

void Events_Init()
{
	g_Events = new ArrayList(sizeof(EventData));
	
	Events_AddEvent("player_spawn", EventHook_PlayerSpawn);
	Events_AddEvent("player_death", EventHook_PlayerDeath);
	Events_AddEvent("player_team", EventHook_PlayerTeam, EventHookMode_Pre);
	Events_AddEvent("teamplay_round_start", EventHook_TeamplayRoundStart);
	Events_AddEvent("teamplay_setup_finished", EventHook_TeamplaySetupFinished);
	Events_AddEvent("teamplay_broadcast_audio", EventHook_TeamplayBroadcastAudio, EventHookMode_Pre);
}

void Events_Toggle(bool enable)
{
	for (int i = 0; i < g_Events.Length; i++)
	{
		EventData data;
		if (g_Events.GetArray(i, data) != 0)
		{
			if (enable)
			{
				HookEvent(data.name, data.callback, data.mode);
			}
			else
			{
				UnhookEvent(data.name, data.callback, data.mode);
			}
		}
	}
}

static void Events_AddEvent(const char[] name, EventHook callback, EventHookMode mode = EventHookMode_Post)
{
	Event event = CreateEvent(name, true);
	if (event)
	{
		event.Cancel();
		
		EventData data;
		strcopy(data.name, sizeof(data.name), name);
		data.callback = callback;
		data.mode = mode;
		
		g_Events.PushArray(data);
	}
	else
	{
		LogError("Failed to create event with name %s", name);
	}
}

static void EventHook_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
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
			ItemGiveTo(client, fists);
			TF2Util_SetPlayerActiveWeapon(client, fists);
		}
		
		// Create the starting parachute
		int parachute = GenerateDefaultItem(client, TF_DEFINDEX_PARACHUTE);
		if (IsValidEntity(parachute))
		{
			ItemGiveTo(client, parachute);
			FRPlayer(client).m_bIsParachuting = true;
		}
	}
}

static void EventHook_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	int userid = event.GetInt("userid");
	int victim = GetClientOfUserId(userid);
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
			
			FRPlayer(victim).RemoveItem(entity);
		}
		
		if (FRPlayer(victim).GetPlayerState() == FRPlayerState_Playing)
		{
			// Set player state to dead now
			FRPlayer(victim).SetPlayerState(FRPlayerState_Dying);
			
			// Delay team switch so ragdolls can appear as the correct team
			float flDelay = TF_DEATH_ANIMATION_TIME + spec_freeze_traveltime.FloatValue;
			CreateTimer(flDelay, Timer_MovePlayerToDeadTeam, userid);
		}
	}
}

static Action Timer_MovePlayerToDeadTeam(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0)
		return Plugin_Continue;
	
	if (IsPlayerAlive(client))
		return Plugin_Continue;
	
	if (FRPlayer(client).m_nPlayerState != FRPlayerState_Dying)
		return Plugin_Continue;
	
	if (TF2_GetClientTeam(client) != TFTeam_Red)
		return Plugin_Continue;
	
	FRPlayer(client).SetPlayerState(FRPlayerState_Waiting);
	TF2_ChangeClientTeam(client, TFTeam_Blue);
	
	return Plugin_Continue;
}

static Action EventHook_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
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

static void EventHook_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	// Stop the round end sounds
	EmitGameSoundToAll("MatchMaking.MatchEndWinMusicCasual", _, SND_STOPLOOPING);
	EmitGameSoundToAll("MatchMaking.MatchEndLoseMusicCasual", _, SND_STOPLOOPING);
	
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

static void EventHook_TeamplaySetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	g_nRoundState = FRRoundState_RoundRunning;
	
	BattleBus_OnSetupFinished();
	Truce_OnSetupFinished();
	Zone_OnSetupFinished();
}

static Action EventHook_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
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
