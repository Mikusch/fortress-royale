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
	
	Events_Add("player_spawn", EventHook_PlayerSpawn);
	Events_Add("player_death", EventHook_PlayerDeath);
	Events_Add("teamplay_round_start", EventHook_TeamplayRoundStart);
	Events_Add("teamplay_setup_finished", EventHook_TeamplaySetupFinished);
	Events_Add("teamplay_broadcast_audio", EventHook_TeamplayBroadcastAudio, EventHookMode_Pre);
}

void Events_Toggle(bool enable)
{
	for (int i = 0; i < g_Events.Length; i++)
	{
		EventData data;
		if (g_Events.GetArray(i, data) > 0)
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

static void Events_Add(const char[] name, EventHook callback, EventHookMode mode = EventHookMode_Post)
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
		int weapon = GenerateDefaultItem(client, TF_DEFINDEX_FISTS);
		if (IsValidEntity(weapon))
		{
			ItemGiveTo(client, weapon);
			TF2Util_SetPlayerActiveWeapon(client, weapon);
		}
		
		FRPlayer(client).m_nPlayerState = FRPlayerState_Parachuting;
		TF2_AddCondition(client, TFCond_Parachute, TFCondDuration_Infinite);
	}
}

static void EventHook_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int death_flags = event.GetInt("death_flags");
	
	if (!(death_flags & TF_DEATHFLAG_DEADRINGER))
	{
		for (int iLoadoutSlot = 0; iLoadoutSlot <= LOADOUT_POSITION_PDA2; ++iLoadoutSlot)
		{
			int entity = GetEntityForLoadoutSlot(client, iLoadoutSlot);
			
			if (!IsValidEntity(entity))
				continue;
			
			if (!ShouldDropItem(client, entity))
				continue;
			
			float vecOrigin[3], vecAngles[3];
			if (!SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(client, entity, vecOrigin, vecAngles))
				continue;
			
			char szWorldModel[PLATFORM_MAX_PATH];
			if (GetItemWorldModel(entity, szWorldModel, sizeof(szWorldModel)))
			{
				int droppedWeapon = CreateDroppedWeapon(vecOrigin, vecAngles, szWorldModel, GetEntityAddress(entity) + FindItemOffset(entity));
				if (IsValidEntity(droppedWeapon))
				{
					if (TF2Util_IsEntityWeapon(entity))
					{
						SDKCall_CTFDroppedWeapon_InitDroppedWeapon(droppedWeapon, client, entity, false);
					}
					else if (TF2Util_IsEntityWearable(entity))
					{
						InitDroppedWearable(droppedWeapon, client, entity, false);
					}
				}
			}
			
			TF2_RemovePlayerItem(client, entity);
		}
		
		FRPlayer(client).m_nPlayerState = FRPlayerState_Dead;
		TF2_ChangeClientTeam(client, TFTeam_Blue);
	}
}

static void EventHook_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	EmitGameSoundToAll("MatchMaking.MatchEndWinMusicCasual", _, SND_STOPLOOPING);
	EmitGameSoundToAll("MatchMaking.MatchEndLoseMusicCasual", _, SND_STOPLOOPING);
	
	// Should the game start?
	if (g_nRoundState == FRRoundState_Setup || g_nRoundState == FRRoundState_PlayerWin)
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
	Zone_OnSetupFinished();
}

static Action EventHook_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return Plugin_Continue;
	
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	
	if (strncmp(sound, "Game.TeamRoundStart", 19) == 0)
	{
		event.SetString("sound", "MatchMaking.RoundStartCasual");
		return Plugin_Changed;
	}
	else if (StrEqual(sound, "Game.YourTeamWon"))
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
