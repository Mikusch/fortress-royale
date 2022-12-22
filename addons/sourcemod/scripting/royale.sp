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
#include <tf2utils>
#include <tf_econ_data>
#include <tf2items>
#include <cbasenpc>

ConVar fr_crate_open_time;

#include "royale/shareddefs.sp"

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
}

public Action OnPlayerRunCmd(int client, int & buttons, int & impulse, float vel[3], float angles[3], int & weapon, int & subtype, int & cmdnum, int & tickcount, int & seed, int mouse[2])
{
	// TODO: Use an actual trace
	int entity = GetClientAimTarget(client, false);
	if (entity != -1)
	{
		char classname[64];
		if (GetEntityClassname(entity, classname, sizeof(classname)) && StrEqual(classname, "prop_dynamic"))
		{
			if (buttons & IN_RELOAD)
			{
				// Crate is already claimed by another player
				if (!FRCrate(entity).CanUse(client))
				{
					return Plugin_Continue;
				}
				
				// Claim and start opening this crate
				if (FRPlayer(client).m_flCrateOpenTime == 0.0)
				{
					FRPlayer(client).m_flCrateOpenTime = GetGameTime();
					
					FRCrate(entity).m_claimedBy = client;
					SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
					EmitSoundToAll(")ui/item_open_crate.wav", entity, SNDCHAN_STATIC, SNDLEVEL_NONE);
				}
				
				// Process crate opening
				if (FRPlayer(client).m_flCrateOpenTime + fr_crate_open_time.FloatValue > GetGameTime())
				{
					char szMessage[64];
					Format(szMessage, sizeof(szMessage), "%T", "Crate_Opening", client, client);
					
					int iSeconds = RoundToCeil(GetGameTime() - FRPlayer(client).m_flCrateOpenTime);
					for (int i = 0; i < iSeconds; i++)
					{
						Format(szMessage, sizeof(szMessage), "%s%s", szMessage, ".");
					}
					
					FRCrate(entity).SetText(szMessage);
				}
				else
				{
					// Pow!
					SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
					
					EmitSoundToAll(")ui/itemcrate_smash_ultrarare_short.wav", entity, SNDCHAN_STATIC);
					StopSound(entity, SNDCHAN_STATIC, ")ui/item_open_crate.wav");
					RemoveEntity(entity);
				}
			}
			else
			{
				if (FRCrate(entity).m_claimedBy != -1)
				{
					FRPlayer(client).m_flCrateOpenTime = 0.0;
					SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
					
					FRCrate(entity).m_claimedBy = -1;
					FRCrate(entity).ClearText();
					StopSound(entity, SNDCHAN_STATIC, ")ui/item_open_crate.wav");
				}
			}
		}
	}
	else 
	{
		// If we hit this, the crate we were opening is now invalid (out of range, destroyed, etc.)
		if (FRPlayer(client).m_flCrateOpenTime)
		{
			FRPlayer(client).m_flCrateOpenTime = 0.0;
			SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
			
			// Find crates still claimed by us and reset them
			int worldtext = -1;
			while ((worldtext = FindEntityByClassname(worldtext, "point_worldtext")) != -1)
			{
				int hMoveParent = GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent");
				
				if (hMoveParent == -1)
					continue;
				
				if (FRCrate(hMoveParent).m_claimedBy != client)
					continue;
				
				FRCrate(hMoveParent).m_claimedBy = -1;
				StopSound(hMoveParent, SNDCHAN_STATIC, ")ui/item_open_crate.wav");
				RemoveEntity(worldtext);
			}
		}
	}
	
	return Plugin_Continue;
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
