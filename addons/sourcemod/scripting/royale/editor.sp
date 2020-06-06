void Editor_Start(int client)
{
	FRPlayer(client).EditorState = EditorState_View;
	Editor_FindCrate(client);
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
			int oldCrate = FRPlayer(client).EditorCrateRef;
			Editor_FindCrate(client);
			if (oldCrate != FRPlayer(client).EditorCrateRef)
				Editor_Display(client);
		}
		case EditorState_Placing:
		{
			Editor_MoveCrateToEye(client, FRPlayer(client).EditorCrateRef);
		}
	}
}

void Editor_Display(int client)
{
	Menu menu = new Menu(Editor_MenuSelected, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	
	LootCrate loot;
	int configIndex = LootConfig_GetCrateByEntity(FRPlayer(client).EditorCrateRef, loot);
	if (FRPlayer(client).EditorState == EditorState_View && configIndex < 0)
	{
		menu.SetTitle("%T\n\n%T", "Editor_Title", LANG_SERVER, "Editor_NotLookingAtAnyCrates", LANG_SERVER);
		menu.AddItem("delete", "Editor_Delete", ITEMDRAW_DISABLED);
		menu.AddItem("prefab", "Editor_EditPrefab", ITEMDRAW_DISABLED);
		menu.AddItem("move", "Editor_Move", ITEMDRAW_DISABLED);
		menu.AddItem("create", "Editor_Create");
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
			menu.AddItem("create", "Editor_Create");
		}
		else if (FRPlayer(client).EditorState == EditorState_Placing)
		{
			menu.AddItem("place", "Editor_Place");
			menu.AddItem("create", "Editor_Create", ITEMDRAW_DISABLED);
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
			
			int crate = FRPlayer(param1).EditorCrateRef;
			
			LootCrate loot;
			int configIndex = LootConfig_GetCrateByEntity(crate, loot);
			
			if (StrEqual(select, "delete"))
			{
				//Delete both entity crate and config
				LootConfig_DeleteCrateByEntity(crate);
				Loot_DeleteCrate(crate);
				
				FRPlayer(param1).EditorState = EditorState_View;
				Editor_Display(param1);
			}
			else if (StrEqual(select, "move"))
			{
				//Only just delete entity crate to create new below 
				Loot_DeleteCrate(crate);
			}
			else if (StrEqual(select, "place"))
			{
				//Set origin and angles, and spawn new crate
				GetEntPropVector(crate, Prop_Data, "m_vecOrigin", loot.origin);
				GetEntPropVector(crate, Prop_Data, "m_angRotation", loot.angles);
				LootConfig_SetCrate(configIndex, loot);
				
				Loot_DeleteCrate(crate);
				
				crate = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
				FRPlayer(param1).EditorCrateRef = crate;
				
				FRPlayer(param1).EditorState = EditorState_View;
				Editor_Display(param1);
			}
			else if (StrEqual(select, "prefab"))
			{
				Editor_DisplayPrefab(param1);
			}
			else if (StrEqual(select, "create"))
			{
				//Create default in config to use to create new entity crate below
				LootCrate_GetDefault(loot);
				configIndex = LootConfig_AddCrate(loot);
			}
			else if (StrEqual(select, "save"))
			{
				LootConfig_Save();
				Editor_Display(param1);
			}
			
			if (StrEqual(select, "move") || StrEqual(select, "create"))
			{
				crate = Loot_SpawnCrateInWorld(loot, EntityOutput_OnBreakCrateConfig);
				LootConfig_SetCrate(configIndex, loot);
				FRPlayer(param1).EditorCrateRef = crate;
				
				SetEntProp(crate, Prop_Send, "m_nSolidType", SOLID_NONE);
				SetEntityRenderMode(crate, RENDER_TRANSCOLOR);
				SetEntityRenderColor(crate, 255, 255, 255, 127);
				
				FRPlayer(param1).EditorState = EditorState_Placing;
				Editor_Display(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_Exit)
			{
				if (FRPlayer(param1).EditorState == EditorState_Placing)
					Loot_DeleteCrate(FRPlayer(param1).EditorCrateRef);
				
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
	if (LootConfig_GetCrateByEntity(FRPlayer(client).EditorCrateRef, loot) < 0)
		return;
	
	menu.SetTitle("%T\n\n%T", "Editor_Prefab_Title", LANG_SERVER, "Editor_Prefab_CurrentCrate", LANG_SERVER, loot.namePrefab[0] == '\0' ? "Default" : loot.namePrefab);
	
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
			
			int crate = FRPlayer(param1).EditorCrateRef;
			
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
						Loot_DeleteCrate(FRPlayer(param1).EditorCrateRef);
					
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

void Editor_FindCrate(int client)
{
	FRPlayer(client).EditorCrateRef = INVALID_ENT_REFERENCE;
	
	float posStart[3], posEnd[3], angles[3];
	GetClientEyePosition(client, posStart);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(posStart))
		return;
	
	//Create simple trace
	Handle trace = TR_TraceRayFilterEx(posStart, angles, MASK_PLAYERSOLID, RayType_Infinite, Editor_FilterClient, client);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return;
	}
	
	//Get whoever entity index found
	int ref = EntIndexToEntRef(TR_GetEntityIndex(trace));
	if (Loot_IsCrate(ref))
	{
		FRPlayer(client).EditorCrateRef = ref;
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

void Editor_MoveCrateToEye(int client, int crate)
{
	float posStart[3], posEnd[3], angles[3], mins[3], maxs[3];
	
	GetEntPropVector(crate, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(crate, Prop_Data, "m_vecMaxs", maxs);
	
	GetClientEyePosition(client, posStart);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(posStart))
		return;
	
	//Get end position for hull
	Handle trace = TR_TraceRayFilterEx(posStart, angles, MASK_PLAYERSOLID, RayType_Infinite, Editor_FilterClient, client);
	TR_GetEndPosition(posEnd, trace);
	delete trace;
	
	//Get new end position
	trace = TR_TraceHullFilterEx(posStart, posEnd, mins, maxs, MASK_PLAYERSOLID, Editor_FilterClient, client);
	TR_GetEndPosition(posEnd, trace);
	delete trace;
	
	//Don't want crate angle consider up/down eye
	angles[0] = 0.0;
	TeleportEntity(crate, posEnd, angles, NULL_VECTOR);
}

public bool Editor_FilterClient(int entity, int contentsMask, any client)
{
	return entity != client;
}

public bool Editor_EnumeratorCrate(int entity, int client)
{
	if (!Loot_IsCrate(EntIndexToEntRef(entity)))
		return true;
	
	FRPlayer(client).EditorCrateRef = EntIndexToEntRef(entity);
	return false;
}
