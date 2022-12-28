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

static ArrayList g_entityProperties;

/**
 * Property storage struct for Entity.
 */
enum struct EntityProperties
{
	int m_index;
	int m_claimedBy;
}

methodmap FREntity < CBaseEntity
{
	public FREntity(int entity)
	{
		if (!IsValidEntity(entity))
		{
			return view_as<FREntity>(INVALID_ENT_REFERENCE);
		}
		
		if (!g_entityProperties)
		{
			g_entityProperties = new ArrayList(sizeof(EntityProperties));
		}
		
		// Convert it twice to ensure we store it as an entity reference
		entity = EntIndexToEntRef(EntRefToEntIndex(entity));
		
		if (g_entityProperties.FindValue(entity, EntityProperties::m_index) == -1)
		{
			// Fill basic properties
			EntityProperties properties;
			properties.m_index = entity;
			properties.m_claimedBy = -1;
			
			g_entityProperties.PushArray(properties);
		}
		
		return view_as<FREntity>(entity);
	}
	
	property int ref
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int _listIndex
	{
		public get()
		{
			return g_entityProperties.FindValue(view_as<int>(this), EntityProperties::m_index);
		}
	}
	
	public bool IsValidCrate()
	{
		char classname[64];
		if (!this.GetClassname(classname, sizeof(classname)) || !StrEqual(classname, "prop_dynamic"))
			return false;
		
		char name[64];
		return this.GetPropString(Prop_Data, "m_iName", name, sizeof(name)) && Config_IsValidCrateName(name);
	}
	
	public void Destroy()
	{
		if (this._listIndex == -1)
			return;
		
		// Remove the entry from local storage
		g_entityProperties.Erase(this._listIndex);
	}
}

methodmap FRCrate < FREntity
{
	public FRCrate(int entity)
	{
		return view_as<FRCrate>(FREntity(entity));
	}
	
	property int m_claimedBy
	{
		public get()
		{
			return g_entityProperties.Get(this._listIndex, EntityProperties::m_claimedBy);
		}
		public set(int claimedBy)
		{
			g_entityProperties.Set(this._listIndex, claimedBy, EntityProperties::m_claimedBy);
		}
	}
	
	public void SetText(const char[] message)
	{
		// Existing point_worldtext, update the message
		int worldtext = -1;
		while ((worldtext = FindEntityByClassname(worldtext, "point_worldtext")) != -1)
		{
			if (GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(this.ref))
				continue;
			
			SetVariantString(message);
			AcceptEntityInput(worldtext, "SetText");
			return;
		}
		
		float origin[3], angles[3];
		this.GetAbsOrigin(origin);
		this.GetAbsAngles(angles);
		
		// Make it sit at the top of the bounding box
		float maxs[3];
		this.GetPropVector(Prop_Data, "m_vecMaxs", maxs);
		origin[2] += maxs[2] + 10.0;
		
		// Don't set a message yet, allow it to teleport first
		worldtext = CreateEntityByName("point_worldtext");
		DispatchKeyValue(worldtext, "orientation", "1");
		DispatchKeyValueVector(worldtext, "origin", origin);
		DispatchKeyValueVector(worldtext, "angles", angles);
		
		if (DispatchSpawn(worldtext))
		{
			SetVariantString("!activator");
			AcceptEntityInput(worldtext, "SetParent", this.index);
		}
	}
	
	public void ClearText()
	{
		int worldtext = -1;
		while ((worldtext = FindEntityByClassname(worldtext, "point_worldtext")) != -1)
		{
			if (GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(this.ref))
				continue;
			
			RemoveEntity(worldtext);
			return;
		}
	}
	
	public void CancelOpen()
	{
		this.m_claimedBy = -1;
		this.ClearText();
		StopSound(this.index, SNDCHAN_AUTO, ")ui/item_open_crate.wav");
	}
	
	public bool CanUse(int client)
	{
		return this.m_claimedBy == -1 || this.m_claimedBy == client;
	}
	
	public void DropItem(int client)
	{
		char name[64];
		if (this.GetPropString(Prop_Data, "m_iName", name, sizeof(name)) == 0)
		{
			LogError("Failed to get targetname for entity '%d'", this.index);
			return;
		}
		
		// Grab a random crate config
		CrateConfig crate;
		if (Config_GetRandomCrateByName(name, crate))
		{
			// Normal crate drops (guaranteed)
			for (int i = 0; i < crate.max_drops; i++)
			{
				CrateContentConfig content;
				if (crate.GetRandomContent(content))
				{
					ItemConfig item;
					if (Config_GetRandomItemByType(client, content.type, content.subtype, item))
					{
						Config_CreateItem(client, this.index, item);
					}
				}
			}
			
			// Extra drops (random)
			for (int i = 0; i < crate.max_extra_drops; i++)
			{
				CrateContentConfig extra_content;
				if (crate.GetRandomExtraContent(extra_content))
				{
					ItemConfig item;
					if (Config_GetRandomItemByType(client, extra_content.type, extra_content.subtype, item))
					{
						Config_CreateItem(client, this.index, item);
					}
				}
			}
		}
	}
}
