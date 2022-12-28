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

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sdkhooks>
#include <regex>
#include <tf2utils>
#include <tf_econ_data>
#include <tf2items>
#include <cbasenpc>

ConVar fr_crate_open_time;
ConVar fr_crate_open_range;
ConVar fr_crate_max_drops;
ConVar fr_crate_max_extra_drops;

ArrayList g_itemModelIndexes;

#include "royale/shareddefs.sp"

#include "royale/callbacks.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convars.sp"
#include "royale/data.sp"
#include "royale/dhooks.sp"
#include "royale/entity.sp"
#include "royale/events.sp"
#include "royale/sdkcalls.sp"
#include "royale/sdkhooks.sp"
#include "royale/util.sp"
#include "royale/zone.sp"

public Plugin myinfo =
{
	name = "Fortress Royale",
	author = "Mikusch",
	description = "FFA Battle Royale gamemode in Team Fortress 2.",
	version = "2.0.0",
	url = "https://github.com/Mikusch/fortress-royale"
}

public void OnPluginStart()
{
	g_itemModelIndexes = new ArrayList();
	
	LoadTranslations("royale.phrases");
	
	Console_Init();
	ConVars_Init();
	Events_Init();
	
	GameData gamedata = new GameData("royale");
	if (gamedata)
	{
		DHooks_Init(gamedata);
		SDKCalls_Init(gamedata);
		
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find royale gamedata");
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnMapStart()
{
	PrecacheSound(")ui/item_open_crate.wav");
	PrecacheSound(")ui/itemcrate_smash_ultrarare_short.wav");
	
	Config_Parse();
	Config_Precache();
}

public void OnMapEnd()
{
	Config_Delete();
}

public Action OnPlayerRunCmd(int client, int & buttons, int & impulse, float vel[3], float angles[3], int & weapon, int & subtype, int & cmdnum, int & tickcount, int & seed, int mouse[2])
{
	ProcessCrateOpening(client, buttons);
	
	return Plugin_Continue;
}

static bool ProcessCrateOpening(int client, int buttons)
{
	if (IsPlayerAlive(client) && buttons & IN_RELOAD)
	{
		float vecEyePosition[3], vecEyeAngles[3];
		GetClientEyePosition(client, vecEyePosition);
		GetClientEyeAngles(client, vecEyeAngles);
		
		float vecForward[3];
		GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
		
		ScaleVector(vecForward, fr_crate_open_range.FloatValue);
		AddVectors(vecForward, vecEyePosition, vecForward);
		
		TR_TraceRayFilter(vecEyePosition, vecForward, MASK_SOLID, RayType_EndPoint, TraceEntityFilter_HitCrates, client, TRACE_ENTITIES_ONLY);
		
		if (TR_GetFraction() != 1.0 && TR_DidHit())
		{
			return FRPlayer(client).TryToOpenCrate(TR_GetEntityIndex());
		}
	}
	
	FRPlayer(client).StopOpeningCrate();
	return false;
}

static bool TraceEntityFilter_HitCrates(int entity, int mask, int client)
{
	return FREntity(entity).IsValidCrate() && FRCrate(entity).CanUse(client);
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &item)
{
	if (TF2Econ_GetItemLoadoutSlot(itemDefIndex, TF2_GetPlayerClass(client)) == LOADOUT_POSITION_MELEE)
	{
		//CreateFists(client);
		//return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	FRPlayer(client).Init();
	
	SDKHooks_OnClientPutInServer(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	SDKHooks_OnEntityCreated(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	FREntity(entity).Destroy();
}
