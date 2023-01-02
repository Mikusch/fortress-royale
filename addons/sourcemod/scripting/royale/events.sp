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
	Events_Add("teamplay_round_active", EventHook_TeamplayRoundActive);
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
	
	int weapon = GenerateDefaultItem(client, TF_DEFINDEX_FISTS);
	if (IsValidEntity(weapon))
	{
		ItemGiveTo(client, weapon);
		TF2Util_SetPlayerActiveWeapon(client, weapon);
	}
}

static void EventHook_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
}

static void EventHook_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	Zone_OnRoundStart();
}


static void EventHook_TeamplayRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	TF2_CreateSetupTimer(10);
}


static void EventHook_TeamplaySetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	if (IsInWaitingForPlayers())
		return;
	
	// TODO
	/*if (g_RoundState != FRRoundState_Setup)
		//return;
	
	g_RoundState = FRRoundState_Active;
	
	BattleBus_SpawnPlayerBus();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
			BattleBus_SpectateBus(client);
	}
	
	g_PlayerCount = GetAlivePlayersCount();
	
	
	Loot_SetupFinished();
	Vehicles_SetupFinished();*/
	Zone_OnSetupFinished();
}
