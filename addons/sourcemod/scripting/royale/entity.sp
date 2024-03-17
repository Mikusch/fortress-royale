/**
 * Copyright (C) 2023  Mikusch
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
	int ref;
	int claimed_by;
}

methodmap FREntity < CBaseEntity
{
	public FREntity(int entity)
	{
		if (!IsValidEntity(entity))
		{
			return view_as<FREntity>(INVALID_ENT_REFERENCE);
		}
		
		int ref = IsValidEdict(entity) ? EntIndexToEntRef(entity) : entity;
		
		if (!FREntity.IsReferenceTracked(ref))
		{
			EntityProperties properties;
			properties.ref = ref;
			properties.claimed_by = -1;
			
			g_entityProperties.PushArray(properties);
		}
		
		return view_as<FREntity>(ref);
	}
	
	property int Ref
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int m_listIndex
	{
		public get()
		{
			return g_entityProperties.FindValue(this, EntityProperties::ref);
		}
	}
	
	public bool IsValidCrate()
	{
		char classname[64];
		if (!this.GetClassname(classname, sizeof(classname)) || strncmp(classname, "prop_", 5) != 0)
			return false;
		
		CrateData data;
		return view_as<FRCrate>(this).GetData(data);
	}
	
	public void Destroy()
	{
		if (this.m_listIndex == -1)
			return;
		
		// Remove the entry from local storage
		g_entityProperties.Erase(this.m_listIndex);
	}
	
	public static bool IsEntityTracked(int entity)
	{
		int ref = IsValidEdict(entity) ? EntIndexToEntRef(entity) : entity;
		return FREntity.IsReferenceTracked(ref);
	}
	
	public static bool IsReferenceTracked(int ref)
	{
		return g_entityProperties.FindValue(ref, EntityProperties::ref) != -1;
	}
	
	public static void Init()
	{
		g_entityProperties = new ArrayList(sizeof(EntityProperties));
	}
}

methodmap FRCrate < FREntity
{
	public FRCrate(int entity)
	{
		return view_as<FRCrate>(FREntity(entity));
	}
	
	property int ClaimedBy
	{
		public get()
		{
			return g_entityProperties.Get(this.m_listIndex, EntityProperties::claimed_by);
		}
		public set(int claimedBy)
		{
			g_entityProperties.Set(this.m_listIndex, claimedBy, EntityProperties::claimed_by);
		}
	}
	
	public bool IsClaimedBy(int client)
	{
		return this.ClaimedBy == client;
	}
	
	public void SetText(const char[] szMessage)
	{
		// Existing point_worldtext, update the message
		int worldtext = -1;
		while ((worldtext = FindEntityByClassname(worldtext, "point_worldtext")) != -1)
		{
			if (GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(this.index))
				continue;
			
			SetVariantString(szMessage);
			AcceptEntityInput(worldtext, "SetText");
			return;
		}
		
		float vecOrigin[3], vecAngles[3];
		this.WorldSpaceCenter(vecOrigin);
		this.GetAbsAngles(vecAngles);
		
		// Make it sit at the top of the bounding box
		float vecMaxs[3];
		this.GetPropVector(Prop_Data, "m_vecMaxs", vecMaxs);
		vecOrigin[2] += vecMaxs[2];
		
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
			if (GetEntPropEnt(worldtext, Prop_Data, "m_hMoveParent") != EntRefToEntIndex(this.Ref))
				continue;
			
			RemoveEntity(worldtext);
			return;
		}
	}
	
	public void StartOpen(int client)
	{
		this.ClaimedBy = client;
		
		CrateData data;
		if (this.GetData(data) && data.open_sound[0])
		{
			EmitSoundToAll(data.open_sound, this.index, SNDCHAN_STATIC);
		}
	}
	
	public void CancelOpen()
	{
		this.ClaimedBy = -1;
		this.ClearText();
		
		CrateData data;
		if (this.GetData(data) && data.open_sound[0])
		{
			StopSound(this.index, SNDCHAN_STATIC, data.open_sound);
		}
	}
	
	public bool CanBeOpenedBy(int client)
	{
		return this.ClaimedBy == -1 || this.IsClaimedBy(client);
	}
	
	public void DropItem(int client)
	{
		CrateData data;
		if (this.GetData(data))
		{
			data.Open(this.index, client);
		}
	}
	
	public bool GetData(CrateData data)
	{
		char name[64];
		if (!this.GetPropString(Prop_Data, "m_iName", name, sizeof(name)))
			return false;
		
		return Config_GetCrateByName(name, data);
	}
}
