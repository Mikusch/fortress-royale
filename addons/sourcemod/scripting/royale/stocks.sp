static bool g_SkipGiveNamedItem;

stock int GetOwnerLoop(int entity)
{
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner > 0 && owner != entity)
		return GetOwnerLoop(owner);
	else
		return entity;
}

stock int GetPlayerCount()
{
	int count = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
			count++;
	}
	
	return count;
}

stock int GetAlivePlayersCount()
{
	int count = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (FRPlayer(client).PlayerState == PlayerState_BattleBus || FRPlayer(client).PlayerState == PlayerState_Parachute || FRPlayer(client).PlayerState == PlayerState_Alive))
			count++;
	}
	
	return count;
}

stock void ModelIndexToString(int index, char[] model, int size)
{
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, index, model, size);
}

stock int GetClientFromPlayerShared(Address playershared)
{
	static int sharedOffset = -1;
	if (sharedOffset == -1)
	{
		sharedOffset = FindSendPropInfo("CTFPlayer", "m_Shared");
		if (sharedOffset <= -1)
			ThrowError("Failed to find CTFPlayer::m_Shared offset");
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetEntityAddress(client) + view_as<Address>(sharedOffset) == playershared)
			return client;
	}
	
	return 0;
}

stock bool TF2_CheckTeamClientCount()
{
	//Count red and blu players
	int countAlive = 0;
	int countDead = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			switch (TF2_GetClientTeam(client))
			{
				case TFTeam_Alive: countAlive++;
				case TFTeam_Dead: countDead++;
			}
		}
	}
	
	//If there atleast 1 player in alive team, nothing need to be done,
	// if there only 1 player total in red + blu, we cant fix it
	if (countAlive || countAlive + countDead < 2)
		return false;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
		{
			TF2_ChangeClientTeam(client, TFTeam_Alive);
			return true;
		}
	}
	
	return false;
}

stock void TF2_ChangeTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", view_as<int>(team));
}

stock TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

stock TFTeam TF2_GetEnemyTeam(int entity)
{
	TFTeam team = view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
	
	switch (team)
	{
		case TFTeam_Red: return TFTeam_Blue;
		case TFTeam_Blue: return TFTeam_Red;
		default: return team;
	}
}

stock bool TF2_IsObjectFriendly(int obj, int entity)
{
	if (0 < entity <= MaxClients)
	{
		if (GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == entity)
			return true;
		
		if (view_as<TFClassType>(GetEntProp(entity, Prop_Send, "m_nDisguiseClass")) == TFClass_Engineer)
			return true;
	}
	else if (entity > MaxClients)
	{
		if (GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == GetEntPropEnt(entity, Prop_Send, "m_hBuilder"))
			return true;
	}
	
	return false;
}

stock bool TF2_IsWearable(int weapon)
{
	char classname[256];
	GetEntityClassname(weapon, classname, sizeof(classname));
	return StrContains(classname, "tf_wearable") == 0;
}

stock float TF2_GetPercentInvisible(int client)
{
	int offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	return GetEntDataFloat(client, offset);
}

stock int TF2_CreateRune(TFRuneType type, const float origin[3] = NULL_VECTOR, const float angles[3] = NULL_VECTOR)
{
	int rune = CreateEntityByName("item_powerup_rune");
	if (IsValidEntity(rune))
	{
		Address address = GetEntityAddress(rune) + view_as<Address>(g_OffsetRuneType);
		StoreToAddress(address, view_as<int>(type), NumberType_Int8);
		DispatchSpawn(rune);
		TeleportEntity(rune, origin, angles, NULL_VECTOR);
		return rune;
	}
	
	return -1;
}

stock void TF2_CheckClientWeapons(int client)
{
	//Weapons
	for (int slot = WeaponSlot_Primary; slot <= WeaponSlot_BuilderEngie; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon > MaxClients)
		{
			char classname[256];
			GetEntityClassname(weapon, classname, sizeof(classname));
			int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			if (TF2_OnGiveNamedItem(client, classname, index) >= Plugin_Handled)
				TF2_RemoveItemInSlot(client, slot);
		}
	}
	
	//Cosmetics
	int wearable = MaxClients+1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity") == client || GetEntPropEnt(wearable, Prop_Send, "moveparent") == client)
		{
			char classname[256];
			GetEntityClassname(wearable, classname, sizeof(classname));
			int index = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
			if (TF2_OnGiveNamedItem(client, classname, index) >= Plugin_Handled)
				TF2_RemoveWearable(client, wearable);
		}
	}
	
	//MvM Canteen
	int powerupBottle = MaxClients+1;
	while ((powerupBottle = FindEntityByClassname(powerupBottle, "tf_powerup_bottle*")) > MaxClients)
	{
		if (GetEntPropEnt(powerupBottle, Prop_Send, "m_hOwnerEntity") == client || GetEntPropEnt(powerupBottle, Prop_Send, "moveparent") == client)
		{
			if (TF2_OnGiveNamedItem(client, "tf_powerup_bottle", GetEntProp(powerupBottle, Prop_Send, "m_iItemDefinitionIndex")) >= Plugin_Handled)
				TF2_RemoveWearable(client, powerupBottle);
		}
	}
}

stock bool TF2_ShouldDropWeapon(int client, int weapon)
{
	//Starting fists
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	if (defindex == INDEX_FISTS)
		return false;
	
	if (defindex == INDEX_BASEJUMPER)
	{
		//Starting parachute
		if (FRPlayer(client).PlayerState == PlayerState_Parachute)
			return false;
		
		//Crash if dropping parachute while in cond
		if (TF2_IsPlayerInCondition(client, TFCond_Parachute))
			return false;
	}
	
	return true;
}

stock Action TF2_OnGiveNamedItem(int client, const char[] classname, int index)
{
	if (g_SkipGiveNamedItem)
		return Plugin_Continue;
	
	int slot = TF2_GetItemSlot(index, TF2_GetPlayerClass(client));
	
	//Allow keep toolbox
	if (slot == WeaponSlot_BuilderEngie && StrEqual(classname, "tf_weapon_builder"))
		return Plugin_Continue;
	
	//Don't allow weapons and action items from client loadout slots
	if (WeaponSlot_Primary <= slot <= WeaponSlot_BuilderEngie || slot == WeaponSlot_Action)
		return Plugin_Handled;
	
	//Allow cosmetics
	return Plugin_Continue;
}

stock int TF2_GiveNamedItem(int client, Address item)
{
	char classname[256];
	TF2Econ_GetItemClassName(LoadFromAddress(item + view_as<Address>(g_OffsetItemDefinitionIndex), NumberType_Int16), classname, sizeof(classname));
	TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), TF2_GetPlayerClass(client));
	
	int subtype = 0;
	if ((StrEqual(classname, "tf_weapon_builder") || StrEqual(classname, "tf_weapon_sapper")) && TF2_GetPlayerClass(client) == TFClass_Spy)
		subtype = view_as<int>(TFObject_Sapper);
	
	g_SkipGiveNamedItem = true;
	int weapon = SDKCall_GiveNamedItem(client, classname, subtype, item, true);
	g_SkipGiveNamedItem = false;
	return weapon;
}

stock int TF2_CreateWeapon(int index, TFClassType class = TFClass_Unknown, const char[] classnameTemp = NULL_STRING)
{
	char classname[256];
	if (classnameTemp[0] != '\0')
	{
		strcopy(classname, sizeof(classname), classnameTemp);
	}
	else
	{
		TF2Econ_GetItemClassName(index, classname, sizeof(classname));
		
		if (class != TFClass_Unknown)
			TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), class);
	}
	
	bool sapper;
	if ((StrEqual(classname, "tf_weapon_builder") || StrEqual(classname, "tf_weapon_sapper")) && class == TFClass_Spy)
	{
		sapper = true;
		
		//tf_weapon_sapper is bad and give client crashes
		classname = "tf_weapon_builder";
	}
	
	int weapon = CreateEntityByName(classname);
	if (IsValidEntity(weapon))
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", index);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 1);
		
		if (sapper)
		{
			SetEntProp(weapon, Prop_Send, "m_iObjectType", TFObject_Sapper);
			SetEntProp(weapon, Prop_Data, "m_iSubType", TFObject_Sapper);
		}
		
		DispatchSpawn(weapon);
	}
	
	return weapon;
}

stock int TF2_CreateDroppedWeapon(int client, int fromWeapon, bool swap, const float origin[3] = { 0.0, 0.0, 0.0 }, const float angles[3] = { 0.0, 0.0, 0.0 })
{
	char classname[32];
	GetEntityNetClass(fromWeapon, classname, sizeof(classname));
	int itemOffset = FindSendPropInfo(classname, "m_Item");
	if (itemOffset <= -1)
	{
		LogError("Failed to find m_Item on: %s", classname);
		return -1;
	}
	
	int index = GetEntProp(fromWeapon, Prop_Send, "m_iItemDefinitionIndex");
	char defindex[12];
	IntToString(index, defindex, sizeof(defindex));
	
	//Attempt get custom model, otherwise use default model
	char model[PLATFORM_MAX_PATH];
	if (!g_PrecacheWeapon.GetString(defindex, model, sizeof(model)))
	{
		int modelIndex = -1;
		if (HasEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex"))
			modelIndex = GetEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex");
		else 
			modelIndex = GetEntProp(fromWeapon, Prop_Send, "m_nModelIndex");
		
		if (modelIndex < 0)
			return INVALID_ENT_REFERENCE;
		
		ModelIndexToString(modelIndex, model, sizeof(model));
	}
	
	// CTFDroppedWeapon::Create deletes tf_dropped_weapon if there too many in map, pretend entity is marking for deletion so it doesnt actually get deleted
	int entity = MaxClients + 1;
	while ((entity = FindEntityByClassname(entity, "tf_dropped_weapon")) > MaxClients)
	{
		int flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
		SetEntProp(entity, Prop_Data, "m_iEFlags", flags|EFL_KILLME);
	}
	
	//Pass client as NULL, only used for deleting existing dropped weapon which we do not want to happen
	int droppedWeapon = SDKCall_CreateDroppedWeapon(-1, origin, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
	
	while ((entity = FindEntityByClassname(entity, "tf_dropped_weapon")) > MaxClients)
	{
		int flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
		flags = flags &= ~EFL_KILLME;
		SetEntProp(entity, Prop_Data, "m_iEFlags", flags);
	}
	
	if (droppedWeapon == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
	
	DispatchSpawn(droppedWeapon);
	
	//Setup ammo, energy count etc
	if (TF2_IsWearable(fromWeapon))	//Pass non-wearable weapon just so it doesn't crash
		SDKCall_InitDroppedWeapon(droppedWeapon, client, TF2_GetItemInSlot(client, WeaponSlot_Melee), swap);
	else
		SDKCall_InitDroppedWeapon(droppedWeapon, client, fromWeapon, swap);
	
	return droppedWeapon;
}

stock void TF2_EquipWeapon(int client, int weapon)
{
	SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	
	char classname[256];
	GetEntityClassname(weapon, classname, sizeof(classname));
	
	if (StrContains(classname, "tf_weapon") == 0)
		EquipPlayerWeapon(client, weapon);
	else if (StrContains(classname, "tf_wearable") == 0)
		SDKCall_EquipWearable(client, weapon);
	else
		RemoveEntity(weapon);
}

stock void TF2_RefillWeaponAmmo(int client, int weapon)
{
	int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (ammotype > -1)
		GivePlayerAmmo(client, 9999, ammotype, true);
}

stock void TF2_SetWeaponAmmo(int client, int weapon, int ammo)
{
	int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (ammotype > -1)
		SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
}

stock int TF2_GetWeaponAmmo(int client, int weapon)
{
	int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (ammotype > -1)
		return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammotype);
	
	return -1;
}

stock int TF2_GetItemSlot(int defindex, TFClassType class)
{
	int slot = TF2Econ_GetItemSlot(defindex, class);
	if (WeaponSlot_Primary <= slot)
	{
		// Econ reports wrong slots for Engineer and Spy
		switch (class)
		{
			case TFClass_Spy:
			{
				switch (slot)
				{
					case 1: slot = WeaponSlot_Primary; // Revolver
					case 4: slot = WeaponSlot_Secondary; // Sapper
					case 5: slot = WeaponSlot_PDADisguise; // Disguise Kit
					case 6: slot = WeaponSlot_InvisWatch; // Invis Watch
				}
			}
			
			case TFClass_Engineer:
			{
				switch (slot)
				{
					case 4: slot = WeaponSlot_BuilderEngie; // Toolbox
					case 5: slot = WeaponSlot_PDABuild; // Construction PDA
					case 6: slot = WeaponSlot_PDADestroy; // Destruction PDA
				}
			}
		}
	}
	
	return slot;
}

stock int TF2_GetItemInSlot(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (weapon > MaxClients)
		return weapon;
	
	//If weapon not found in slot, check if it a wearable
	return SDKCall_GetEquippedWearableForLoadoutSlot(client, slot);
}

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);

	int wearable = SDKCall_GetEquippedWearableForLoadoutSlot(client, slot);
	if (wearable > MaxClients)
		TF2_RemoveWearable(client, wearable);
}

stock void TF2_ShowGameMessage(const char[] message, const char[] icon, int displayToTeam = 0, int teamColor = 0)
{
	int msg = CreateEntityByName("game_text_tf");
	if (IsValidEntity(msg))
	{
		DispatchKeyValue(msg, "message", message);
		switch (displayToTeam)
		{
			case 2: DispatchKeyValue(msg, "display_to_team", "2");
			case 3: DispatchKeyValue(msg, "display_to_team", "3");
			default: DispatchKeyValue(msg, "display_to_team", "0");
		}
		switch (teamColor)
		{
			case 2: DispatchKeyValue(msg, "background", "2");
			case 3: DispatchKeyValue(msg, "background", "3");
			default: DispatchKeyValue(msg, "background", "0");
		}
		
		DispatchKeyValue(msg, "icon", icon);
		
		if (DispatchSpawn(msg))
			AcceptEntityInput(msg, "Display");
	}
}
