enum EditorItem
{
	EditorItem_None,
	EditorItem_Crate,
	EditorItem_Vehicle
}

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
			MoveEntityToClientEye(FRPlayer(client).EditorItemRef, client);
		}
	}
}

void Editor_Display(int client)
{
	Menu menu = new Menu(Editor_MenuSelected, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	
	LootCrate loot;
	LootConfig_GetCrateByEntity(FRPlayer(client).EditorItemRef, loot);
	if (FRPlayer(client).EditorState == EditorState_View && FRPlayer(client).EditorItemRef == INVALID_ENT_REFERENCE)
	{
		menu.SetTitle("%T\n\n%T", "Editor_Title", LANG_SERVER, "Editor_NotLookingAtAny", LANG_SERVER);
		menu.AddItem("delete", "Editor_Delete", ITEMDRAW_DISABLED);
		menu.AddItem("prefab", "Editor_EditPrefab", ITEMDRAW_DISABLED);
		menu.AddItem("move", "Editor_Move", ITEMDRAW_DISABLED);
		menu.AddItem("crate", "Editor_CreateCrate");
		menu.AddItem("vehicle", "Editor_CreateVehicle");
	}
	else
	{
		menu.SetTitle("%T\n\n%T\n%T", 
			"Editor_Title", LANG_SERVER, 
			"Editor_Prefab", LANG_SERVER, loot.namePrefab, 
			"Editor_Health", LANG_SERVER, loot.health);
		menu.AddItem("delete", "Editor_Delete");
		menu.AddItem("prefab", "Editor_EditPrefab");
		
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
			
			int entity = FRPlayer(param1).EditorItemRef;
			EditorItem itemType = Editor_GetItemType(entity);
			
			if (StrEqual(select, "delete"))
			{
				//Delete both entity item and config
				switch (itemType)
				{
					case EditorItem_Crate:
					{
						LootConfig_DeleteCrateByEntity(entity);
					}
					case EditorItem_Vehicle:
					{
						//TODO remove in config aswell
					}
				}
				
				RemoveEntity(entity);
				
				FRPlayer(param1).EditorState = EditorState_View;
				Editor_Display(param1);
			}
			else if (StrEqual(select, "prefab"))
			{
				Editor_DisplayPrefab(param1);
			}
			else if (StrEqual(select, "save"))
			{
				Config_Save();
				Editor_Display(param1);
			}
			else if (StrEqual(select, "place"))
			{
				//Use ghost entity to get origin and angles to set, and spawn new crate
				float origin[3], angles[3];
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
				GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);
				
				switch (itemType)
				{
					case EditorItem_Crate:
					{
						LootCrate loot;
						int configIndex = LootConfig_GetCrateByEntity(entity, loot);
						loot.origin = origin;
						loot.angles = angles;
						
						RemoveEntity(entity);
						entity = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
						
						loot.entity = entity;
						LootConfig_SetCrate(configIndex, loot);
					}
					case EditorItem_Vehicle:
					{
						Vehicle vehicle;
						Vehicles_GetByEntity(entity, vehicle);
						vehicle.origin = origin;
						vehicle.angles = angles;
						
						RemoveEntity(entity);
						entity = Vehicles_CreateEntity(vehicle);
						
						//TODO set config
					}
				}
				
				FRPlayer(param1).EditorItemRef = entity;
				FRPlayer(param1).EditorState = EditorState_View;
				Editor_Display(param1);
			}
			else if (StrEqual(select, "move") || StrEqual(select, "crate") || StrEqual(select, "vehicle"))
			{
				//Create ghost entity
				int ghost = INVALID_ENT_REFERENCE;
				bool move = StrEqual(select, "move");
				
				if (StrEqual(select, "crate"))
					itemType = EditorItem_Crate;
				else if (StrEqual(select, "vehicle"))
					itemType = EditorItem_Vehicle;
				
				switch (itemType)
				{
					case EditorItem_Crate:
					{
						LootCrate loot;
						int configIndex;
						
						if (move)
						{
							//Copy crate from target and delete
							configIndex = LootConfig_GetCrateByEntity(entity, loot);
						}
						else
						{
							//Create new crate
							LootCrate_GetDefault(loot);
							configIndex = LootConfig_AddCrate(loot);
						}
						
						//Create new crate
						ghost = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
						loot.entity = ghost;
						LootConfig_SetCrate(configIndex, loot);
					}
					case EditorItem_Vehicle:
					{
						Vehicle vehicle;
						//int configIndex;
						
						if (move)
						{
							//Copy vehicle from target and delete
							Vehicles_GetByEntity(entity, vehicle);
						}
						else
						{
							//Create new vehicle
							//TODO
						}
						
						//Create new vehicle
						ghost = Vehicles_CreateEntity(vehicle);
					}
				}
				
				if (IsValidEntity(entity))	//Delete old entity after ghost is created
					RemoveEntity(entity);
				
				SetEntProp(ghost, Prop_Send, "m_nSolidType", SOLID_NONE);
				SetEntityRenderMode(ghost, RENDER_TRANSCOLOR);
				SetEntityRenderColor(ghost, 255, 255, 255, 127);
				
				FRPlayer(param1).EditorItemRef = ghost;
				FRPlayer(param1).EditorState = EditorState_Placing;
				Editor_Display(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_Exit)
			{
				if (FRPlayer(param1).EditorState == EditorState_Placing)
				{
					RemoveEntity(FRPlayer(param1).EditorItemRef);
					FRPlayer(param1).EditorItemRef = INVALID_ENT_REFERENCE;
				}
				
				FRPlayer(param1).EditorState = EditorState_None;
			}
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

void Editor_DisplayPrefab(int client)
{
	Menu menu = new Menu(Editor_MenuSelectedPrefab, MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	
	LootCrate loot;
	if (LootConfig_GetCrateByEntity(FRPlayer(client).EditorItemRef, loot) < 0)
		return;
	
	menu.SetTitle("%T\n\n%T", "Editor_Prefab_Title", LANG_SERVER, "Editor_Prefab_Current", LANG_SERVER, loot.namePrefab[0] == '\0' ? "Default" : loot.namePrefab);
	
	menu.AddItem("__default__", "Default", loot.namePrefab[0] == '\0' ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	int pos;
	LootCrate lootPrefab;
	while (LootConfig_GetPrefab(pos, lootPrefab))
	{
		menu.AddItem(lootPrefab.namePrefab, lootPrefab.namePrefab, StrEqual(lootPrefab.namePrefab, loot.namePrefab) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		pos++;
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
			
			int crate = FRPlayer(param1).EditorItemRef;
			
			LootCrate lootPrefab;
			if (StrEqual(select, "__default__") || LootConfig_GetPrefabByName(select, lootPrefab))
			{
				LootCrate loot;
				int configIndex = LootConfig_GetCrateByEntity(crate, loot);
				if (configIndex >= 0)
				{
					//Copy everything from prefab to crate, but keep origin and angles
					float origin[3], angles[3];
					origin = loot.origin;
					angles = loot.angles;
					
					loot = lootPrefab;
					
					loot.origin = origin;
					loot.angles = angles;
					
					Loot_SetCratePrefab(crate, lootPrefab);
					LootConfig_SetCrate(configIndex, loot);
				}
			}
			
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
	else if (Vehicles_IsVehicle(entity))
		return EditorItem_Vehicle;
	else
		return EditorItem_None;
}