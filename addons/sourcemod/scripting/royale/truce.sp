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

#define MAX_SOUNDS_ON1MINREMAIN		6
#define MAX_SOUNDS_ON30SECREMAIN	6
#define MAX_SOUNDS_ON10SECREMAIN	1

#define SOUND_TRUCE_ON1MINREMAIN	"vo/announcer_dec_missionbegins60s%02i.mp3"
#define SOUND_TRUCE_ON30SECREMAIN	"vo/announcer_dec_missionbegins30s%02i.mp3"
#define SOUND_TRUCE_ON10SECREMAIN	"vo/announcer_dec_missionbegins10s%02i.mp3"

#define GAMESOUND_TRUCE_MUSIC		"MatchMaking.RoundStartCasual"
#define GAMESOUND_TRUCE_COUNTDOWN	"Announcer.CompGameBegins%02iSeconds"
#define GAMESOUND_TRUCE_FINISH		"Announcer.CompGameBeginsFight"
#define GAMESOUND_TRUCE_SIREN		"Ambient.Siren"

void Truce_Precache()
{
	PrecacheParameterizedSound(SOUND_TRUCE_ON1MINREMAIN, MAX_SOUNDS_ON1MINREMAIN);
	PrecacheParameterizedSound(SOUND_TRUCE_ON30SECREMAIN, MAX_SOUNDS_ON30SECREMAIN);
	PrecacheParameterizedSound(SOUND_TRUCE_ON10SECREMAIN, MAX_SOUNDS_ON10SECREMAIN);
}

void Truce_Start(float duration)
{
	//Start a truce to allow people to grab weapons in peace
	GameRules_SetProp("m_bTruceActive", true);
	TF2_SendHudNotification(HUD_NOTIFY_TRUCE_START, true);
	
	int timer = CreateEntityByName("team_round_timer");
	if (IsValidEntity(timer))
	{
		DispatchKeyValueFloat(timer, "timer_length", duration);
		DispatchKeyValue(timer, "show_in_hud", "1");
		DispatchKeyValue(timer, "auto_countdown", "0");
		
		if (DispatchSpawn(timer))
		{
			AcceptEntityInput(timer, "Enable");
			HookSingleEntityOutput(timer, "On1MinRemain", EntOutput_OnTruce1MinRemain, true);
			HookSingleEntityOutput(timer, "On30SecRemain", EntOutput_OnTruce30SecRemain, true);
			HookSingleEntityOutput(timer, "On10SecRemain", EntOutput_OnTruce10SecRemain, true);
			HookSingleEntityOutput(timer, "On5SecRemain", EntOutput_OnTruce5SecRemain, true);
			HookSingleEntityOutput(timer, "On4SecRemain", EntOutput_OnTruce4SecRemain, true);
			HookSingleEntityOutput(timer, "On3SecRemain", EntOutput_OnTruce3SecRemain, true);
			HookSingleEntityOutput(timer, "On2SecRemain", EntOutput_OnTruce2SecRemain, true);
			HookSingleEntityOutput(timer, "On1SecRemain", EntOutput_OnTruce1SecRemain, true);
			HookSingleEntityOutput(timer, "OnFinished", EntOutput_OnTruceFinished, true);
		}
	}
}

public Action EntOutput_OnTruce1MinRemain(const char[] output, int caller, int activator, float delay)
{
	PlayRandomParameterizedSound(SOUND_TRUCE_ON1MINREMAIN, MAX_SOUNDS_ON1MINREMAIN);
}

public Action EntOutput_OnTruce30SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayRandomParameterizedSound(SOUND_TRUCE_ON30SECREMAIN, MAX_SOUNDS_ON30SECREMAIN);
}

public Action EntOutput_OnTruce10SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayRandomParameterizedSound(SOUND_TRUCE_ON10SECREMAIN, MAX_SOUNDS_ON10SECREMAIN);
	EmitGameSoundToAll(GAMESOUND_TRUCE_MUSIC);
}

public Action EntOutput_OnTruce5SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayParameterizedGameSound(GAMESOUND_TRUCE_COUNTDOWN, 5);
}

public Action EntOutput_OnTruce4SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayParameterizedGameSound(GAMESOUND_TRUCE_COUNTDOWN, 4);
}

public Action EntOutput_OnTruce3SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayParameterizedGameSound(GAMESOUND_TRUCE_COUNTDOWN, 3);
}

public Action EntOutput_OnTruce2SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayParameterizedGameSound(GAMESOUND_TRUCE_COUNTDOWN, 2);
}

public Action EntOutput_OnTruce1SecRemain(const char[] output, int caller, int activator, float delay)
{
	PlayParameterizedGameSound(GAMESOUND_TRUCE_COUNTDOWN, 1);
}

public Action EntOutput_OnTruceFinished(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
	
	GameRules_SetProp("m_bTruceActive", false);
	TF2_SendHudNotification(HUD_NOTIFY_TRUCE_END, true);
	
	EmitGameSoundToAll(GAMESOUND_TRUCE_FINISH);
	EmitGameSoundToAll(GAMESOUND_TRUCE_SIREN);
}

void PrecacheParameterizedSound(const char[] format, int maxsounds)
{
	char sound[PLATFORM_MAX_PATH];
	for (int i = 1; i <= maxsounds; i++)
	{
		Format(sound, sizeof(sound), format, i);
		PrecacheSound(sound);
	}
}

void PlayRandomParameterizedSound(const char[] format, int maxsounds)
{
	char sound[PLATFORM_MAX_PATH];
	Format(sound, sizeof(sound), format, GetRandomInt(1, maxsounds));
	EmitSoundToAll(sound, _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

void PlayParameterizedGameSound(const char[] format, int num)
{
	char sound[PLATFORM_MAX_PATH];
	Format(sound, sizeof(sound), format, num);
	EmitGameSoundToAll(sound);
}
