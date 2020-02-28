void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("arena_win_panel", Event_ArenaWinPanel);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	BattleBus_NewPos();
}

public Action Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
//	g_IsRoundActive = true;
	BattleBus_SpawnProp();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
			BattleBus_SpectateBus(client);
	}
}

public Action Event_ArenaWinPanel(Event event, const char[] name, bool dontBroadcast)
{
//	g_IsRoundActive = false;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	TFTeam team = TF2_GetClientTeam(client);
	if (team <= TFTeam_Spectator)
		return;
	
	if (team == TFTeam_Dead)
	{
		SetEntProp(client, Prop_Send, "m_lifeState", LifeState_Dead);
		TF2_ChangeClientTeam(client, TFTeam_Alive);
		SetEntProp(client, Prop_Send, "m_lifeState", LifeState_Alive);
		TF2_RespawnPlayer(client);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetClientTeam(victim) <= TFTeam_Spectator)
		return;
	
	RequestFrame(Frame_SetClientDead, GetClientSerial(victim));
}

public void Frame_SetClientDead(int serial)
{
	int client = GetClientFromSerial(serial);
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || TF2_GetClientTeam(client) <= TFTeam_Spectator)
		return;
	
	TF2_ChangeClientTeam(client, TFTeam_Dead);
}