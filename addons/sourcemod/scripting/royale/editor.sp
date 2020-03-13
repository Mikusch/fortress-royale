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
	Menu menu = new Menu(Editor_MenuSelected);
	
	LootCrateConfig lootCrate;
	int configIndex = Loot_GetCrateConfig(FRPlayer(client).EditorCrateRef, lootCrate);
	if (FRPlayer(client).EditorState == EditorState_View && configIndex < 0)
	{
		menu.SetTitle("Editor Menu \n \nYou are not looking at any crates");
		menu.AddItem("delete", "Delete this Crate", ITEMDRAW_DISABLED);
		menu.AddItem("move", "Move this Crate", ITEMDRAW_DISABLED);
		menu.AddItem("create", "Create New Crate");
	}
	else
	{
		char title[512];
		Format(title, sizeof(title), "Prefab: %s", lootCrate.namePrefab);
		Format(title, sizeof(title), "%s\nHealth: %d", title, lootCrate.health);
		Format(title, sizeof(title), "%s\nChance: %.2f", title, lootCrate.chance);
		
		menu.SetTitle("Editor Menu \n \n%s", title);
		menu.AddItem("delete", "Delete this Crate");
		
		if (FRPlayer(client).EditorState == EditorState_View)
		{
			menu.AddItem("move", "Move this Crate");
			menu.AddItem("create", "Create New Crate");
		}
		else if (FRPlayer(client).EditorState == EditorState_Placing)
		{
			menu.AddItem("place", "Place this Crate");
			menu.AddItem("create", "Create New Crate", ITEMDRAW_DISABLED);
		}
	}
	
	menu.AddItem("save", "Save to KeyValues File");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Editor_MenuSelected(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel && param2 == MenuCancel_Exit)
	{
		if (FRPlayer(param1).EditorState == EditorState_Placing)
			Loot_DeleteCrate(FRPlayer(param1).EditorCrateRef);
		
		FRPlayer(param1).EditorState = EditorState_None;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char select[32];
		menu.GetItem(param2, select, sizeof(select));
		
		int crate = FRPlayer(param1).EditorCrateRef;
		
		if (StrEqual(select, "delete"))
		{
			int configIndex = Loot_DeleteCrate(crate);
			if (configIndex >= 0)
				Config_DeleteCrate(configIndex);
			
			FRPlayer(param1).EditorState = EditorState_View;
			Editor_Display(param1);
		}
		else if (StrEqual(select, "place"))
		{
			SetEntityRenderMode(crate, RENDER_NORMAL);
			SetEntityRenderColor(crate, 255, 255, 255, 255);
			
			LootCrateConfig lootCrate;
			int configIndex = Loot_GetCrateConfig(crate, lootCrate);
			
			GetEntPropVector(crate, Prop_Data, "m_vecOrigin", lootCrate.origin);
			GetEntPropVector(crate, Prop_Data, "m_angRotation", lootCrate.angles);
			Config_SetLootCrate(configIndex, lootCrate);
			
			FRPlayer(param1).EditorState = EditorState_View;
			Editor_Display(param1);
		}
		else if (StrEqual(select, "create"))
		{
			LootCrateConfig lootCrate;
			int configIndex = Config_CreateDefault(lootCrate);
			
			crate = Loot_SpawnCrateInWorld(lootCrate, configIndex, true);
			FRPlayer(param1).EditorCrateRef = crate;
		}
		else if (StrEqual(select, "save"))
		{
			Config_SaveLootCrates();
			Editor_Display(param1);
		}
		
		if (StrEqual(select, "move") || StrEqual(select, "create"))
		{
			SetEntityRenderMode(crate, RENDER_TRANSCOLOR);
			SetEntityRenderColor(crate, 255, 255, 255, 127);
			
			FRPlayer(param1).EditorState = EditorState_Placing;
			Editor_Display(param1);
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
	
	float mins[3] = { -48.0, -48.0, -48.0 };
	float maxs[3] = { 48.0, 48.0, 48.0 };
	TR_EnumerateEntitiesHull(posStart, posEnd, mins, maxs, PARTITION_NON_STATIC_EDICTS, Editor_EnumeratorCrate, client);
}

void Editor_MoveCrateToEye(int client, int crate)
{
	float posStart[3], posEnd[3], angles[3];
	float mins[3] = { -32.0, -32.0, -16.0 };
	float maxs[3] = { 32.0, 32.0, 48.0 };
	
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