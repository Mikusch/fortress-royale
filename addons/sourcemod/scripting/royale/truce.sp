#pragma newdecls required
#pragma semicolon 1

char g_aSoundTruceOn1MinRemain[][] =
{
	"vo/announcer_dec_missionbegins60s01.mp3",
	"vo/announcer_dec_missionbegins60s02.mp3",
	"vo/announcer_dec_missionbegins60s03.mp3",
	"vo/announcer_dec_missionbegins60s04.mp3",
	"vo/announcer_dec_missionbegins60s05.mp3",
	"vo/announcer_dec_missionbegins60s06.mp3",
};

char g_aSoundTruceOn30SecRemain[][] =
{
	"vo/announcer_dec_missionbegins30s01.mp3",
	"vo/announcer_dec_missionbegins30s02.mp3",
	"vo/announcer_dec_missionbegins30s03.mp3",
	"vo/announcer_dec_missionbegins30s04.mp3",
	"vo/announcer_dec_missionbegins30s05.mp3",
	"vo/announcer_dec_missionbegins30s06.mp3",
};

char g_aSoundTruceOn10SecRemain[][] =
{
	"vo/announcer_dec_missionbegins10s01.mp3",
};

void Truce_Precache()
{
	for (int i = 0; i < sizeof(g_aSoundTruceOn1MinRemain); i++)
	{
		PrecacheSound(g_aSoundTruceOn1MinRemain[i]);
	}
	
	for (int i = 0; i < sizeof(g_aSoundTruceOn30SecRemain); i++)
	{
		PrecacheSound(g_aSoundTruceOn30SecRemain[i]);
	}
	
	for (int i = 0; i < sizeof(g_aSoundTruceOn10SecRemain); i++)
	{
		PrecacheSound(g_aSoundTruceOn10SecRemain[i]);
	}
}

void Truce_OnSetupFinished()
{
	// Start a truce to allow people to grab weapons in peace
	GameRules_SetProp("m_bTruceActive", true);
	SendHudNotification(HUD_NOTIFY_TRUCE_START, true);
	
	int timer = CreateEntityByName("team_round_timer");
	if (IsValidEntity(timer))
	{
		DispatchKeyValueFloat(timer, "timer_length", fr_truce_duration.FloatValue);
		DispatchKeyValue(timer, "show_in_hud", "1");
		DispatchKeyValue(timer, "auto_countdown", "0");
		
		if (DispatchSpawn(timer))
		{
			AcceptEntityInput(timer, "Enable");
			HookSingleEntityOutput(timer, "On1MinRemain", EntityOutput_OnTruce1MinRemain, true);
			HookSingleEntityOutput(timer, "On30SecRemain", EntityOutput_OnTruce30SecRemain, true);
			HookSingleEntityOutput(timer, "On10SecRemain", EntityOutput_OnTruce10SecRemain, true);
			HookSingleEntityOutput(timer, "On5SecRemain", EntityOutput_OnTruce5SecRemain, true);
			HookSingleEntityOutput(timer, "On4SecRemain", EntityOutput_OnTruce4SecRemain, true);
			HookSingleEntityOutput(timer, "On3SecRemain", EntityOutput_OnTruce3SecRemain, true);
			HookSingleEntityOutput(timer, "On2SecRemain", EntityOutput_OnTruce2SecRemain, true);
			HookSingleEntityOutput(timer, "On1SecRemain", EntityOutput_OnTruce1SecRemain, true);
			HookSingleEntityOutput(timer, "OnFinished", EntityOutput_OnTruceFinished, true);
		}
	}
}

static void EntityOutput_OnTruce1MinRemain(const char[] output, int caller, int activator, float delay)
{
	EmitSoundToAll(g_aSoundTruceOn1MinRemain[GetRandomInt(0, sizeof(g_aSoundTruceOn1MinRemain) - 1)], _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

static void EntityOutput_OnTruce30SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitSoundToAll(g_aSoundTruceOn30SecRemain[GetRandomInt(0, sizeof(g_aSoundTruceOn30SecRemain) - 1)], _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

static void EntityOutput_OnTruce10SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitGameSoundToAll("MatchMaking.RoundStartCasual");
	EmitSoundToAll(g_aSoundTruceOn10SecRemain[GetRandomInt(0, sizeof(g_aSoundTruceOn10SecRemain) - 1)], _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

static void EntityOutput_OnTruce5SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitGameSoundToAll("Announcer.CompGameBegins05Seconds");
}

static void EntityOutput_OnTruce4SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitGameSoundToAll("Announcer.CompGameBegins04Seconds");
}

static void EntityOutput_OnTruce3SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitGameSoundToAll("Announcer.CompGameBegins03Seconds");
}

static void EntityOutput_OnTruce2SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitGameSoundToAll("Announcer.CompGameBegins02Seconds");
}

static void EntityOutput_OnTruce1SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitGameSoundToAll("Announcer.CompGameBegins01Seconds");
}

static void EntityOutput_OnTruceFinished(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
	
	GameRules_SetProp("m_bTruceActive", false);
	SendHudNotification(HUD_NOTIFY_TRUCE_END, true);
	
	EmitGameSoundToAll("Ambient.Siren");
	EmitGameSoundToAll("Announcer.CompGameBeginsFight");
}
