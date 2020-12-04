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

void Editor_Start(int client)
{
	FRPlayer(client).EditorState = EditorState_View;
	Editor_FindItem(client);
	Editor_Display(client);
	
	SDKHook(client, SDKHook_PostThinkPost, Editor_ClientThink);
}

void Editor_ClientThink(int client)
{
	switch (FRPlayer(client).EditorState)
	{
		case EditorState_None:
		{
			SDKUnhook(client, SDKHook_PostThinkPost, Editor_ClientThink);
		}
		case EditorState_View:
		{
			int oldCrate = FRPlayer(client).EditorItemRef;
			Editor_FindItem(client);
			if (oldCrate != FRPlayer(client).EditorItemRef)
				Editor_Display(client);
		}
		case EditorState_Placing:
		{
			int mask = FRPlayer(client).EditorItem == EditorItem_Vehicle ? MASK_PLAYERSOLID|MASK_WATER : MASK_PLAYERSOLID;
			MoveEntityToClientEye(FRPlayer(client).EditorItemRef, client, mask);
		}
	}
}

void Editor_Display(int client)
{
	SetGlobalTransTarget(client);
	Menu menu = new Menu(Editor_MenuSelected, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	
	if (FRPlayer(client).EditorState == EditorState_View && FRPlayer(client).EditorItemRef == INVALID_ENT_REFERENCE)
	{
		menu.SetTitle("%t\n\n%t", "Editor_Title", "Editor_NotLookingAtAny");
		menu.AddItem("delete", "Editor_Delete", ITEMDRAW_DISABLED);
		menu.AddItem("move", "Editor_Move", ITEMDRAW_DISABLED);
		menu.AddItem("crate", "Editor_CreateCrate");
		menu.AddItem("vehicle", "Editor_CreateVehicle");
	}
	else
	{
		char name[CONFIG_MAXCHAR];
		Editor_GetItemPrefab(FRPlayer(client).EditorItemRef, name, sizeof(name));
		
		menu.SetTitle("%t\n\n%t", "Editor_Title", "Editor_Prefab", name);
		menu.AddItem("delete", "Editor_Delete");
		
		if (FRPlayer(client).EditorState == EditorState_View)
		{
			menu.AddItem("move", "Editor_Move");
			menu.AddItem("crate", "Editor_CreateCrate");
			menu.AddItem("vehicle", "Editor_CreateVehicle");
		}
		else if (FRPlayer(client).EditorState == EditorState_Placing)
		{
			menu.AddItem("place", "Editor_Place");
			menu.AddItem("crate", "Editor_CreateCrate", ITEMDRAW_DISABLED);
			menu.AddItem("vehicle", "Editor_CreateVehicle", ITEMDRAW_DISABLED);
		}
	}
	
	menu.AddItem("save", "Editor_Save");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Editor_MenuSelected(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char select[32];
			menu.GetItem(param2, select, sizeof(select));
			
			FRPlayer(param1).EditorItem = EditorItem_None;
			int entity = FRPlayer(param1).EditorItemRef;
			EditorItem itemType = Editor_GetItemType(entity);
			
			if (StrEqual(select, "delete"))
			{
				//Delete both entity item and config
				switch (itemType)
				{
					case EditorItem_Crate: LootConfig_DeleteCrateByEntity(entity);
					case EditorItem_Vehicle: VehiclesConfig_DeleteMapVehicleByEntity(entity);
				}
				
				RemoveEntity(entity);
				
				FRPlayer(param1).EditorState = EditorState_View;
				Editor_Display(param1);
			}
			else if (StrEqual(select, "save"))
			{
				Config_Save();
				Editor_Display(param1);
			}
			else if (StrEqual(select, "place"))
			{
				//Use ghost entity to get vector origin and angles, then convert to string so kv can set it, and spawn new item
				int ghost = entity;
				float origin[3], angles[3];
				GetEntPropVector(ghost, Prop_Data, "m_vecOrigin", origin);
				GetEntPropVector(ghost, Prop_Data, "m_angRotation", angles);
				
				switch (itemType)
				{
					case EditorItem_Crate:
					{
						LootCrate loot;
						int configIndex = LootConfig_GetCrateByEntity(ghost, loot);
						VectorToString(origin, loot.origin, sizeof(loot.origin));
						VectorToString(angles, loot.angles, sizeof(loot.angles));
						
						entity = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
						
						loot.entity = entity;
						LootConfig_SetCrate(configIndex, loot);
					}
					case EditorItem_Vehicle:
					{
						char targetname[CONFIG_MAXCHAR];
						GetEntPropString(ghost, Prop_Data, "m_iName", targetname, sizeof(targetname));
						
						VehicleConfig config;
						VehiclesConfig_GetPrefabByTargetname(targetname, config);
						VectorToString(origin, config.origin, sizeof(config.origin));
						VectorToString(angles, config.angles, sizeof(config.angles));
						
						entity = Vehicles_CreateEntity(config);
						config.entity = entity;
						VehiclesConfig_AddMapVehicle(config);
					}
				}
				
				//Delete ghost entity after actual entity created
				RemoveEntity(ghost);
				
				FRPlayer(param1).EditorItemRef = entity;
				FRPlayer(param1).EditorState = EditorState_View;
				Editor_Display(param1);
			}
			else if (StrEqual(select, "move"))
			{
				//Create ghost entity by current prefab name
				
				char name[CONFIG_MAXCHAR];
				Editor_GetItemPrefab(entity, name, sizeof(name));
				
				switch (itemType)
				{
					case EditorItem_Crate: LootConfig_DeleteCrateByEntity(entity);
					case EditorItem_Vehicle: VehiclesConfig_DeleteMapVehicleByEntity(entity);
				}
				
				FRPlayer(param1).EditorItemRef = Editor_CreateGhostEntity(itemType, name);
				FRPlayer(param1).EditorState = EditorState_Placing;
				FRPlayer(param1).EditorItem = itemType;
				Editor_Display(param1);
				
				//Delete old entity after ghost is created
				RemoveEntity(entity);
			}
			else if (StrEqual(select, "crate"))
			{
				FRPlayer(param1).EditorItem = EditorItem_Crate;
				Editor_DisplayPrefab(param1, EditorItem_Crate);
			}
			else if (StrEqual(select, "vehicle"))
			{
				FRPlayer(param1).EditorItem = EditorItem_Vehicle;
				Editor_DisplayPrefab(param1, EditorItem_Vehicle);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_Exit)
				FRPlayer(param1).EditorState = EditorState_None;
		}
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_DisplayItem:
		{
			char info[32];
			char display[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			Format(display, sizeof(display), "%T", display, LANG_SERVER);
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}

void Editor_DisplayPrefab(int client, EditorItem itemType)
{
	Menu menu = new Menu(Editor_MenuSelectedPrefab, MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	menu.SetTitle("%T", "Editor_Prefab_Title", LANG_SERVER);
	
	switch (itemType)
	{
		case EditorItem_Crate:
		{
			menu.AddItem("__default__", "Default");
			
			int pos;
			LootCrate lootPrefab;
			while (LootConfig_GetPrefab(pos, lootPrefab))
			{
				menu.AddItem(lootPrefab.name, lootPrefab.name);
				pos++;
			}
		}
		case EditorItem_Vehicle:
		{
			int pos;
			VehicleConfig config;
			while (VehiclesConfig_GetPrefab(pos, config))
			{
				menu.AddItem(config.name, config.name);
				pos++;
			}
		}
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Editor_MenuSelectedPrefab(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char select[32];
			menu.GetItem(param2, select, sizeof(select));
			
			FRPlayer(param1).EditorItemRef = Editor_CreateGhostEntity(FRPlayer(param1).EditorItem, select);
			FRPlayer(param1).EditorState = EditorState_Placing;
			Editor_Display(param1);
		}
		case MenuAction_Cancel:
		{
			switch (param2)
			{
				case MenuCancel_Exit:
				{
					if (FRPlayer(param1).EditorState == EditorState_Placing)
						RemoveEntity(FRPlayer(param1).EditorItemRef);
					
					FRPlayer(param1).EditorState = EditorState_None;
				}
				case MenuCancel_ExitBack:
				{
					Editor_Display(param1);
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

int Editor_CreateGhostEntity(EditorItem itemType, const char[] prefab)
{
	int ghost = INVALID_ENT_REFERENCE;
	
	switch (itemType)
	{
		case EditorItem_Crate:
		{
			LootCrate loot;
			if (!prefab[0] || StrEqual(prefab, "__default__"))
				LootCrate_GetDefault(loot);	//TODO this default crate still needed?
			else
				LootConfig_GetByName(prefab, loot);
			
			//Create new crate
			ghost = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
			loot.entity = ghost;
			LootConfig_AddCrate(loot);
		}
		case EditorItem_Vehicle:
		{
			VehicleConfig config;
			VehiclesConfig_GetPrefabByName(prefab, config);
			
			//Create new vehicle
			ghost = Vehicles_CreateEntity(config);
		}
	}
	
	SetEntProp(ghost, Prop_Send, "m_nSolidType", SOLID_NONE);
	SetEntityRenderMode(ghost, RENDER_TRANSCOLOR);
	SetEntityRenderColor(ghost, 255, 255, 255, 127);
	
	return ghost;
}

void Editor_FindItem(int client)
{
	FRPlayer(client).EditorItemRef = INVALID_ENT_REFERENCE;
	
	float posStart[3], posEnd[3], angles[3];
	GetClientEyePosition(client, posStart);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(posStart))
		return;
	
	//Create simple trace
	Handle trace = TR_TraceRayFilterEx(posStart, angles, MASK_PLAYERSOLID, RayType_Infinite, Trace_DontHitEntity, client);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return;
	}
	
	//Get whoever entity index found
	int ref = EntIndexToEntRef(TR_GetEntityIndex(trace));
	if (Editor_GetItemType(ref) != EditorItem_None)
	{
		FRPlayer(client).EditorItemRef = ref;
		delete trace;
		return;
	}
	
	//If not found, get end position and use hull instead
	TR_GetEndPosition(posEnd, trace);
	delete trace;
	
	float mins[3] =  { -48.0, -48.0, -48.0 };
	float maxs[3] =  { 48.0, 48.0, 48.0 };
	TR_EnumerateEntitiesHull(posStart, posEnd, mins, maxs, PARTITION_NON_STATIC_EDICTS, Editor_EnumeratorCrate, client);
}

public bool Editor_EnumeratorCrate(int entity, int client)
{
	int ref = EntIndexToEntRef(entity);
	if (Editor_GetItemType(ref) == EditorItem_None)
		return true;
	
	FRPlayer(client).EditorItemRef = ref;
	return false;
}

EditorItem Editor_GetItemType(int entity)
{
	if (Loot_IsCrate(entity))
		return EditorItem_Crate;
	else if (VehiclesConfig_IsMapVehicle(entity))
		return EditorItem_Vehicle;
	else
		return EditorItem_None;
}

void Editor_GetItemPrefab(int entity, char[] name, int length)
{
	switch (Editor_GetItemType(entity))
	{
		case EditorItem_Crate:
		{
			//Copy crate from target and delete
			LootCrate loot;
			LootConfig_GetCrateByEntity(entity, loot);
			strcopy(name, length, loot.name);
		}
		case EditorItem_Vehicle:
		{
			VehicleConfig config;
			VehiclesConfig_GetMapVehicleByEntity(entity, config);
			strcopy(name, length, config.name);
		}
	}
}