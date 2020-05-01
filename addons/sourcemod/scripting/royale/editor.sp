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
	
	LootCrateConfig lootCrate;
	int configIndex = Loot_GetCrateConfig(FRPlayer(client).EditorCrateRef, lootCrate);
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
			"Editor_Prefab", LANG_SERVER, lootCrate.namePrefab, 
			"Editor_Health", LANG_SERVER, lootCrate.health);
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
			
			LootCrateConfig lootCrate;
			int configIndex = Loot_GetCrateConfig(crate, lootCrate);
			
			if (StrEqual(select, "delete"))
			{
				//Delete both entity crate and config
				Loot_DeleteCrate(crate);
				Config_DeleteCrate(configIndex);
				
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
				GetEntPropVector(crate, Prop_Data, "m_vecOrigin", lootCrate.origin);
				GetEntPropVector(crate, Prop_Data, "m_angRotation", lootCrate.angles);
				Config_SetLootCrate(configIndex, lootCrate);
				
				Loot_DeleteCrate(crate);
				
				crate = Loot_SpawnCrateInWorld(lootCrate, configIndex, true);
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
				configIndex = Config_CreateDefault(lootCrate);
			}
			else if (StrEqual(select, "save"))
			{
				Config_SaveLootCrates();
				Editor_Display(param1);
			}
			
			if (StrEqual(select, "move") || StrEqual(select, "create"))
			{
				crate = Loot_SpawnCrateInWorld(lootCrate, configIndex, true);
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
	
	LootCrateConfig lootCrate;
	if (Loot_GetCrateConfig(FRPlayer(client).EditorCrateRef, lootCrate) < 0)
		return;
	
	menu.SetTitle("%T\n\n%T", "Editor_Prefab_Title", LANG_SERVER, "Editor_Prefab_CurrentCrate", LANG_SERVER, lootCrate.namePrefab[0] == '\0' ? "Default" : lootCrate.namePrefab);
	
	menu.AddItem("__default__", "Default", lootCrate.namePrefab[0] == '\0' ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	int prefabIndex;
	LootCrateConfig lootPrefab;
	while (Config_GetLootPrefab(prefabIndex, lootPrefab))
	{
		menu.AddItem(lootPrefab.namePrefab, lootPrefab.namePrefab, StrEqual(lootPrefab.namePrefab, lootCrate.namePrefab) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		prefabIndex++;
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
			
			LootCrateConfig lootPrefab;
			if (StrEqual(select, "__default__") || Config_FindPrefab(select, lootPrefab) >= 0)
			{
				if (!lootPrefab.load)
					Config_GetDefault(lootPrefab);
				
				LootCrateConfig lootCrate;
				int configIndex = Loot_GetCrateConfig(crate, lootCrate);
				if (configIndex >= 0)
				{
					//Copy everything from prefab to crate, but keep origin and angles
					float origin[3], angles[3];
					origin = lootCrate.origin;
					angles = lootCrate.angles;
					
					lootCrate = lootPrefab;
					
					lootCrate.origin = origin;
					lootCrate.angles = angles;
					
					Loot_SetCratePrefab(crate, lootPrefab);
					Config_SetLootCrate(configIndex, lootCrate);
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
	float posStart[3], posEnd[3], angles[3];
	float mins[3] =  { -32.0, -32.0, -16.0 };
	float maxs[3] =  { 32.0, 32.0, 48.0 };
	
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
