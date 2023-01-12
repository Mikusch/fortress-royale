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
	int m_iIndex;
	int m_hClaimedBy;
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
		
		if (g_entityProperties.FindValue(entity, EntityProperties::m_iIndex) == -1)
		{
			// Fill basic properties
			EntityProperties properties;
			properties.m_iIndex = entity;
			properties.m_hClaimedBy = -1;
			
			g_entityProperties.PushArray(properties);
		}
		
		return view_as<FREntity>(CBaseEntity(entity));
	}
	
	// Similar naming to CBaseEntity.index
	property int reference
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int m_iListIndex
	{
		public get()
		{
			return g_entityProperties.FindValue(view_as<int>(this), EntityProperties::m_iIndex);
		}
	}
	
	public bool IsValidCrate()
	{
		char szClassname[64];
		if (!this.GetClassname(szClassname, sizeof(szClassname)) || strncmp(szClassname, "prop_dynamic", 12) != 0)
			return false;
		
		char szName[64];
		return this.GetPropString(Prop_Data, "m_iName", szName, sizeof(szName)) != 0 && Config_IsValidCrateName(szName);
	}
	
	public void Destroy()
	{
		if (this.m_iListIndex == -1)
			return;
		
		// Remove the entry from local storage
		g_entityProperties.Erase(this.m_iListIndex);
	}
}

methodmap FRCrate < FREntity
{
	public FRCrate(int entity)
	{
		return view_as<FRCrate>(FREntity(entity));
	}
	
	property int m_hClaimedBy
	{
		public get()
		{
			return g_entityProperties.Get(this.m_iListIndex, EntityProperties::m_hClaimedBy);
		}
		public set(int hClaimedBy)
		{
			g_entityProperties.Set(this.m_iListIndex, hClaimedBy, EntityProperties::m_hClaimedBy);
		}
	}
	
	public void SetText(const char[] szMessage)
	{
		// Existing point_worldtext, update the message
		int worldtext = -1;
		while ((worldtext = FindEntityByClassname(worldtext, "point_worldtext")) != -1)
		{
			if (GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(this.reference))
				continue;
			
			SetVariantString(szMessage);
			AcceptEntityInput(worldtext, "SetText");
			return;
		}
		
		float vecOrigin[3], vecAngles[3];
		this.GetAbsOrigin(vecOrigin);
		this.GetAbsAngles(vecAngles);
		
		// Make it sit at the top of the bounding box
		float vecMaxs[3];
		this.GetPropVector(Prop_Data, "m_vecMaxs", vecMaxs);
		vecOrigin[2] += vecMaxs[2] + 10.0;
		
		// Don't set a message yet, allow it to teleport first
		worldtext = CreateEntityByName("point_worldtext");
		DispatchKeyValue(worldtext, "orientation", "1");
		DispatchKeyValueVector(worldtext, "origin", vecOrigin);
		DispatchKeyValueVector(worldtext, "angles", vecAngles);
		
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
			if (GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(this.reference))
				continue;
			
			RemoveEntity(worldtext);
			return;
		}
	}
	
	public void StartOpen(int client)
	{
		this.m_hClaimedBy = client;
		EmitSoundToAll(")ui/item_open_crate.wav", this.index, SNDCHAN_STATIC);
	}
	
	public void CancelOpen()
	{
		this.m_hClaimedBy = -1;
		this.ClearText();
		StopSound(this.index, SNDCHAN_STATIC, ")ui/item_open_crate.wav");
	}
	
	public bool CanUse(int client)
	{
		return this.m_claimedBy == -1 || this.m_hClaimedBy == client;
	}
	
	public void DropItem(int client)
	{
		char szName[64];
		if (this.GetPropString(Prop_Data, "m_iName", szName, sizeof(szName)) == 0)
		{
			LogError("Failed to get targetname for entity '%d'", this.index);
			return;
		}
		
		// Grab a random crate config
		CrateConfig crate;
		if (Config_GetCrateByName(szName, crate))
		{
			crate.Open(this.index, client);
		}
	}
}
