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

#define SOUND_TRUCE_ON1MINREMAIN	"vo/announcer_dec_missionbegins60s01.mp3"
#define SOUND_TRUCE_ON30SECREMAIN	"vo/announcer_dec_missionbegins30s01.mp3"
#define SOUND_TRUCE_ON10SECREMAIN	"vo/announcer_dec_missionbegins10s01.mp3"
#define GAMESOUND_TRUCE_FINISH		"Announcer.CompGameBeginsFight"
#define GAMESOUND_TRUCE_SIREN		"Ambient.Siren"

void Truce_Precache()
{
	PrecacheSound(SOUND_TRUCE_ON1MINREMAIN);
	PrecacheSound(SOUND_TRUCE_ON30SECREMAIN);
	PrecacheSound(SOUND_TRUCE_ON10SECREMAIN);
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
			HookSingleEntityOutput(timer, "OnFinished", EntOutput_OnTruceFinished, true);
		}
	}
}

public Action EntOutput_OnTruce1MinRemain(const char[] output, int caller, int activator, float delay)
{
	EmitSoundToAll(SOUND_TRUCE_ON1MINREMAIN, _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

public Action EntOutput_OnTruce30SecRemain(const char[] output, int caller, int activator, float delay)
{
	EmitSoundToAll(SOUND_TRUCE_ON30SECREMAIN, _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

public Action EntOutput_OnTruce10SecRemain(const char[] output, int caller, int activator, float delay)
{
	SetVariantInt(1);
	AcceptEntityInput(caller, "AutoCountdown");
	
	EmitSoundToAll(SOUND_TRUCE_ON10SECREMAIN, _, SNDCHAN_VOICE_BASE, SNDLEVEL_NONE);
}

public Action EntOutput_OnTruceFinished(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
	
	GameRules_SetProp("m_bTruceActive", false);
	TF2_SendHudNotification(HUD_NOTIFY_TRUCE_END, true);
	
	EmitGameSoundToAll(GAMESOUND_TRUCE_FINISH);
	EmitGameSoundToAll(GAMESOUND_TRUCE_SIREN);
}
