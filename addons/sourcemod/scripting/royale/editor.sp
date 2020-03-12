void Editor_Start(int client)
{
	FRPlayer(client).Editor = true;
	Editor_FindCrate(client);
	Editor_Display(client);
	
	SDKHook(client, SDKHook_PostThinkPost, Editor_ClientThink);
}

void Editor_ClientThink(int client)
{
	if (!FRPlayer(client).Editor)
	{
		SDKUnhook(client, SDKHook_PostThinkPost, Editor_ClientThink);
		return;
	}
	
	int oldCrate = FRPlayer(client).EditorCrate;
	Editor_FindCrate(client);
	if (oldCrate != FRPlayer(client).EditorCrate)
		Editor_Display(client);
}

void Editor_Display(int client)
{
	Menu menu = new Menu(Editor_MenuSelected);
	
	LootCrateConfig lootCrate;
	if (FRPlayer(client).EditorCrate == INVALID_ENT_REFERENCE || !Loot_GetCrateConfig(FRPlayer(client).EditorCrate, lootCrate))
	{
		menu.SetTitle("Editor Menu\n\nYou are not looking at any crates");
		menu.AddItem("yes", "yes");
	}
	else
	{
		char title[512];
		Format(title, sizeof(title), "Prefab: %s", lootCrate.namePrefab);
		Format(title, sizeof(title), "%s\nHealth: %d", title, lootCrate.health);
		Format(title, sizeof(title), "%s\nChance: %.2f", title, lootCrate.chance);
		menu.SetTitle("Editor Menu\n\n%s", title);
		menu.AddItem("yes", "yes");
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Editor_MenuSelected(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel && param2 == MenuCancel_Exit)
	{
		FRPlayer(param1).Editor = false;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void Editor_FindCrate(int client)
{
	FRPlayer(client).EditorCrate = INVALID_ENT_REFERENCE;
	
	float posStart[3], posEnd[3], angles[3];
	GetClientEyePosition(client, posStart);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(posStart))
		return;
	
	//Get end position
	Handle trace = TR_TraceRayFilterEx(posStart, angles, MASK_PLAYERSOLID, RayType_Infinite, Editor_FilterClient, client);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return;
	}
	
	int ref = EntIndexToEntRef(TR_GetEntityIndex(trace));
	if (Loot_IsCrate(ref))
	{
		FRPlayer(client).EditorCrate = ref;
		delete trace;
		return;
	}
	
	TR_GetEndPosition(posEnd, trace);
	delete trace;
	
	float mins[3] = { -48.0, -48.0, -48.0 };
	float maxs[3] = { 48.0, 48.0, 48.0 };
	TR_EnumerateEntitiesHull(posStart, posEnd, mins, maxs, PARTITION_NON_STATIC_EDICTS, Editor_EnumeratorCrate, client);
}

public bool Editor_FilterClient(int entity, int contentsMask, any client)
{
	return entity != client;
}

public bool Editor_EnumeratorCrate(int entity, int client)
{
	if (!Loot_IsCrate(EntIndexToEntRef(entity)))
		return true;
	
	FRPlayer(client).EditorCrate = EntIndexToEntRef(entity);
	return false;
}