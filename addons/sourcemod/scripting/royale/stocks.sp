static bool g_SkipGiveNamedItem;

stock int min(int a, int b)
{
	return a < b ? a : b;
}

stock int max(int a, int b)
{
	return a > b ? a : b;
}

stock float fMin(float a, float b)
{
	return a < b ? a : b;
}

stock float fMax(float a, float b)
{
	return a > b ? a : b;
}

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

stock void AnglesToVelocity(const float angles[3], float velocity[3], float speed = 1.0)
{
	velocity[0] = Cosine(DegToRad(angles[1]));
	velocity[1] = Sine(DegToRad(angles[1]));
	velocity[2] = Sine(DegToRad(angles[0])) * -1.0;
	
	NormalizeVector(velocity, velocity);
	
	ScaleVector(velocity, speed);
}

stock void StringToVector(const char[] string, float vector[3])
{
	char buffer[3][16];
	ExplodeString(string, " ", buffer, sizeof(buffer), sizeof(buffer[]));
	
	for (int i = 0; i < sizeof(vector); i++)
		vector[i] = StringToFloat(buffer[i]);
}

stock void VectorToString(const float vector[3], char[] string, int length)
{
	Format(string, length, "%f %f %f", vector[0], vector[1], vector[2]);
}

stock bool IsEntityStuck(int entity)
{
	float mins[3], maxs[3], origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	
	TR_TraceHullFilter(origin, origin, mins, maxs, MASK_SOLID, Trace_DontHitEntity, entity);
	return TR_DidHit();
}

stock bool UnstuckEntity(int entity)
{
	if (!IsEntityStuck(entity))
		return true;
	
	float mins[3], maxs[3], origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	
	float oldOrigin[3];
	oldOrigin = origin;
	
	do
	{
		float test[3];
		float direction[3];
		for (int x = -1; x <= 1; x+= 2)
		{
			test[0] = origin[0] + (x == -1 ? mins[0] : maxs[0]);
			
			for (int y = -1; y <= 1; y+= 2)
			{
				test[1] = origin[1] + (y == -1 ? mins[1] : maxs[1]);
				
				for (int z = -1; z <= 1; z+= 2)
				{
					test[2] = origin[2] + (z == -1 ? mins[2] : maxs[2]);
					
					if (TR_GetPointContents(test) & MASK_SOLID)
					{
						direction[0] -= float(x);
						direction[1] -= float(y);
						direction[2] -= float(z);
					}
				}
			}
		}
		
		if (!direction[0] && !direction[1] && !direction[2])
		{
			//Should be unstuck now
			return true;
		}
		
		float newOrigin[3];
		AddVectors(origin, direction, newOrigin);
		
		//Teleporting in infinite loop, escape
		if (oldOrigin[0] == newOrigin[0] && oldOrigin[1] == newOrigin[1] && oldOrigin[2] == newOrigin[2])
			return false;
		
		oldOrigin = origin;
		origin = newOrigin;
		TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
	}
	while (IsEntityStuck(entity));
	
	return true;
}

stock int GetClientPointVisible(int client, float distance)
{
	float origin[3], angles[3], end[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	
	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, Trace_DontHitEntity, client);
	TR_GetEndPosition(end, trace);
	
	int val = -1;
	int entity = TR_GetEntityIndex(trace);
	
	if (TR_DidHit(trace) && entity != client && GetVectorDistance(origin, end) < distance)
		val = entity;
	
	delete trace;
	return val;
}

stock bool GetWaterHeightFromEntity(int entity, float &height)
{
	float origin[3], angles[3], end[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	
	//Get highest point from above entity
	angles = view_as<float>({ -90.0, 0.0, 0.0 });
	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, Trace_OnlyHitWorld);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return false;
	}
	
	TR_GetEndPosition(end, trace);
	delete trace;
	
	//Use point to find highest water point below
	angles = view_as<float>({ 90.0, 0.0, 0.0 });
	trace = TR_TraceRayEx(end, angles, MASK_WATER, RayType_Infinite);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return false;
	}
	
	TR_GetEndPosition(end, trace);
	delete trace;
	
	//Calculate distance between highest water point to entity
	height = end[2] - origin[2];
	return true;
}

stock void CreateFade(int client, int duration = 1000, int r = 255, int g = 255, int b = 255, int a = 255)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("Fade", client));
	bf.WriteShort(duration);	//Fade duration
	bf.WriteShort(0);
	bf.WriteShort(0x0001);
	bf.WriteByte(r);			//Red
	bf.WriteByte(g);			//Green
	bf.WriteByte(b);			//Blue
	bf.WriteByte(a);			//Alpha
	EndMessage();
}

stock void WorldSpaceCenter(int entity, float[3] buffer)
{
	float origin[3], mins[3], maxs[3], offset[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
	AddVectors(mins, maxs, offset);
	ScaleVector(offset, 0.5);
	AddVectors(origin, offset, buffer);
}

stock bool MoveEntityToClientEye(int entity, int client, int mask = MASK_PLAYERSOLID)
{
	float posStart[3], posEnd[3], angles[3], mins[3], maxs[3];
	
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
	
	GetClientEyePosition(client, posStart);
	GetClientEyeAngles(client, angles);
	
	if (TR_PointOutsideWorld(posStart))
		return false;
	
	//Get end position for hull
	Handle trace = TR_TraceRayFilterEx(posStart, angles, mask, RayType_Infinite, Trace_DontHitEntity, client);
	TR_GetEndPosition(posEnd, trace);
	delete trace;
	
	//Get new end position
	trace = TR_TraceHullFilterEx(posStart, posEnd, mins, maxs, mask, Trace_DontHitEntity, client);
	TR_GetEndPosition(posEnd, trace);
	delete trace;
	
	//Don't want entity angle consider up/down eye
	angles[0] = 0.0;
	TeleportEntity(entity, posEnd, angles, NULL_VECTOR);
	return true;
}

public bool Trace_DontHitEntity(int entity, int mask, any data)
{
	return entity != data;
}

public bool Trace_OnlyHitWorld(int entity, int mask)
{
	return entity == 0;	// 0 as worldspawn
}

stock void TF2_ChangeTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", view_as<int>(team));
}

stock TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

stock TFTeam TF2_GetEnemyTeam(TFTeam team)
{
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
		
		if (TF2_GetPlayerClass(entity) == TFClass_Spy)
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

stock void TF2_SwitchActiveWeapon(int client, int weapon)
{
	char classname[256];
	GetEntityClassname(weapon, classname, sizeof(classname));
	FakeClientCommand(client, "use %s", classname);
}

stock float TF2_GetPercentInvisible(int client)
{
	static int offset = -1;
	if (offset == -1)
		offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	
	return GetEntDataFloat(client, offset);
}

stock int TF2_CreateRune(TFRuneType type, const float origin[3] = NULL_VECTOR, const float angles[3] = NULL_VECTOR)
{
	int rune = CreateEntityByName("item_powerup_rune");
	if (IsValidEntity(rune))
	{
		Address address = GetEntityAddress(rune) + view_as<Address>(g_OffsetRuneType);
		StoreToAddress(address, view_as<int>(type), NumberType_Int8);
		TeleportEntity(rune, origin, angles, NULL_VECTOR);
		DispatchSpawn(rune);
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

stock bool TF2_TryToPickupDroppedWeapon(int client)
{
	if (FRPlayer(client).LastWeaponPickupTime > GetGameTime() - 1.0 || FRPlayer(client).PlayerState != PlayerState_Alive || TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return false;
	
	float origin[3], angles[3], endPos[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	
	GetAngleVectors(angles, endPos, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(endPos, TF_WEAPON_PICKUP_RANGE);
	AddVectors(endPos, origin, endPos);
	
	TR_TraceRayFilter(origin, endPos, MASK_SOLID|CONTENTS_DEBRIS, RayType_EndPoint, Trace_DontHitEntity, client);
	if (!TR_DidHit())
		return false;
	
	int droppedWeapon = TR_GetEntityIndex();
	
	char classname[256];
	GetEntityClassname(droppedWeapon, classname, sizeof(classname));
	if (!StrEqual(classname, "tf_dropped_weapon"))
		return false;
	
	int defindex = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType class = TFClass_Unknown;
	int slot = -1;
	
	if (fr_classfilter.BoolValue)
	{
		//Only allow pickup weapon if class can normally use
		slot = TF2_GetItemSlot(defindex, TF2_GetPlayerClass(client));
		if (slot < WeaponSlot_Primary)
			return false;
	}
	else
	{
		//Find best class and slot to translate classname
		for (TFClassType classTemp = TFClass_Scout; classTemp <= TFClass_Engineer; classTemp++)
		{
			int slotTemp = TF2_GetItemSlot(defindex, classTemp);
			if (slotTemp < WeaponSlot_Primary)
				continue;
			
			class = classTemp;
			slot = slotTemp;
			
			//If client dont have any weapons in slot, perfect class to use so break out the search. Otherwise keep searching for possible better class/slot
			if (TF2_GetItemInSlot(client, slot) == -1)
				break;
		}
	}
	
	//Check if client already has weapon in given slot, remove and create dropped weapon if so
	int weaponOld, pos;
	while (TF2_GetItem(client, weaponOld, pos))
	{
		if (slot == TF2_GetSlot(weaponOld) && TF2_ShouldDropWeapon(client, weaponOld))
		{
			TF2_CreateDroppedWeapon(client, weaponOld, true, origin, angles);
			TF2_RemoveItem(client, weaponOld);
		}
		else if (slot == WeaponSlot_Melee && GetEntProp(weaponOld, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
		{
			TF2_RemoveItem(client, weaponOld);
		}
	}
	
	static int itemOffset = -1;
	if (itemOffset == -1)
		itemOffset = FindSendPropInfo("CTFDroppedWeapon", "m_Item");
	
	//Create and equip new weapon
	int weapon = TF2_GiveNamedItem(client, GetEntityAddress(droppedWeapon) + view_as<Address>(itemOffset), class);
	if (weapon == INVALID_ENT_REFERENCE)
		return false;
	
	TF2_EquipWeapon(client, weapon);
	
	//Restore ammo, energy etc from picked up weapon
	if (!TF2_IsWearable(weapon))
		SDKCall_InitPickedUpWeapon(droppedWeapon, client, weapon);
	
	//If max ammo not calculated yet (-1), do it now
	if (!TF2_IsWearable(weapon) && TF2_GetWeaponAmmo(client, weapon) < 0)
	{
		TF2_SetWeaponAmmo(client, weapon, 0);
		TF2_RefillWeaponAmmo(client, weapon);
		SetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", SDKCall_GetDefaultItemChargeMeterValue(weapon), slot);
	}
	
	//Fix active weapon, incase was switched to wearable
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") <= MaxClients)
		TF2_SwitchActiveWeapon(client, TF2_GetItemInSlot(client, WeaponSlot_Melee));
	
	//Remove dropped weapon
	RemoveEntity(droppedWeapon);
	
	CreateTimer(0.1, Timer_UpdateClientHud, GetClientSerial(client));
	FRPlayer(client).LastWeaponPickupTime = GetGameTime();
	return true;
}

stock bool TF2_ShouldDropWeapon(int client, int weapon)
{
	//Starting fists and spellbook
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	if (defindex == INDEX_FISTS || defindex == INDEX_SPELLBOOK)
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
	
	//Toolbox
	if (TF2_GetItemSlot(defindex, TF2_GetPlayerClass(client)) == WeaponSlot_BuilderEngie)
	{
		char classname[256];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, "tf_weapon_builder"))
			return false;
	}
	
	return true;
}

stock Action TF2_OnGiveNamedItem(int client, const char[] classname, int index)
{
	if (g_SkipGiveNamedItem)
		return Plugin_Continue;
	
	TFClassType class = TF2_GetPlayerClass(client);
	
	//Allow keep toolbox
	if (class == TFClass_Engineer && StrEqual(classname, "tf_weapon_builder"))
		return Plugin_Continue;
	
	int slot = TF2_GetItemSlot(index, class);
	
	//Don't allow weapons from client loadout slots
	if (WeaponSlot_Primary <= slot <= WeaponSlot_BuilderEngie)
		return Plugin_Handled;
	
	//Allow cosmetics
	return Plugin_Continue;
}

stock int TF2_GiveNamedItem(int client, Address item, TFClassType class = TFClass_Unknown)
{
	char classname[256];
	TF2Econ_GetItemClassName(LoadFromAddress(item + view_as<Address>(g_OffsetItemDefinitionIndex), NumberType_Int16), classname, sizeof(classname));
	
	if (class == TFClass_Unknown)
		class = TF2_GetPlayerClass(client);
	
	TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), class);
	
	int subtype = 0;
	if ((StrEqual(classname, "tf_weapon_builder") || StrEqual(classname, "tf_weapon_sapper")) && class == TFClass_Spy)
		subtype = view_as<int>(TFObject_Sapper);
	
	g_SkipGiveNamedItem = true;
	int weapon = SDKCall_GiveNamedItem(client, classname, subtype, item, true);
	g_SkipGiveNamedItem = false;
	return weapon;
}

stock int TF2_CreateWeapon(int defindex, const char[] classnameTemp = NULL_STRING)
{
	TFClassType class = TFClass_Unknown;
	
	char classname[256];
	if (classnameTemp[0])
	{
		strcopy(classname, sizeof(classname), classnameTemp);
	}
	else
	{
		TF2Econ_GetItemClassName(defindex, classname, sizeof(classname));
		
		for (class = TFClass_Scout; class <= TFClass_Engineer; class++)
		{
			if (TF2_GetItemSlot(defindex, class) >= WeaponSlot_Primary)
			{
				TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), class);
				break;
			}
		}
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
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", defindex);
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

stock int TF2_CreateDroppedWeapon(int client, int fromWeapon, bool swap, const float origin[3], const float angles[3] = { 0.0, 0.0, 0.0 })
{
	char classname[32];
	GetEntityNetClass(fromWeapon, classname, sizeof(classname));
	int itemOffset = FindSendPropInfo(classname, "m_Item");
	if (itemOffset <= -1)
	{
		LogError("Failed to find m_Item on: %s", classname);
		return INVALID_ENT_REFERENCE;
	}
	
	int index = GetEntProp(fromWeapon, Prop_Send, "m_iItemDefinitionIndex");
	char defindex[12];
	IntToString(index, defindex, sizeof(defindex));
	
	//Attempt get custom model, otherwise use default model
	char model[PLATFORM_MAX_PATH];
	if (!g_PrecacheWeapon.GetString(defindex, model, sizeof(model)))
	{
		int modelIndex;
		if (HasEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex"))
			modelIndex = GetEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex");
		else 
			modelIndex = GetEntProp(fromWeapon, Prop_Send, "m_nModelIndex");
		
		if (modelIndex <= 0)
		{
			LogError("Unable to find model for dropped weapon with def index '%d'", index);
			return INVALID_ENT_REFERENCE;
		}
		
		ModelIndexToString(modelIndex, model, sizeof(model));
	}
	
	//Dropped weapon doesn't like being spawn high in air, create on ground then teleport back after DispatchSpawn
	TR_TraceRayFilter(origin, view_as<float>({ 90.0, 0.0, 0.0 }), MASK_SOLID, RayType_Infinite, Trace_OnlyHitWorld);
	if (!TR_DidHit())	//Outside of map
		return INVALID_ENT_REFERENCE;
	
	float originSpawn[3];
	TR_GetEndPosition(originSpawn);
	
	// CTFDroppedWeapon::Create deletes tf_dropped_weapon if there too many in map, pretend entity is marking for deletion so it doesnt actually get deleted
	ArrayList droppedWeapons = new ArrayList();
	int entity = MaxClients + 1;
	while ((entity = FindEntityByClassname(entity, "tf_dropped_weapon")) > MaxClients)
	{
		int flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
		if (!(flags & EFL_KILLME))
		{
			SetEntProp(entity, Prop_Data, "m_iEFlags", flags|EFL_KILLME);
			droppedWeapons.Push(entity);
		}
	}
	
	//Pass client as NULL, only used for deleting existing dropped weapon which we do not want to happen
	int droppedWeapon = SDKCall_CreateDroppedWeapon(-1, originSpawn, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
	
	int length = droppedWeapons.Length;
	for (int i = 0; i < length; i++)
	{
		entity = droppedWeapons.Get(i);
		int flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
		flags = flags &= ~EFL_KILLME;
		SetEntProp(entity, Prop_Data, "m_iEFlags", flags);
	}
	
	delete droppedWeapons;
	
	if (droppedWeapon == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
	
	DispatchSpawn(droppedWeapon);
	
	//Check if weapon is not marked for deletion after spawn, otherwise we may get bad physics model leading to a crash
	if (GetEntProp(droppedWeapon, Prop_Data, "m_iEFlags") & EFL_KILLME)
	{
		LogError("Unable to create dropped weapon with model '%s' and def index '%d'", model, index);
		return INVALID_ENT_REFERENCE;
	}
	
	//Setup ammo, energy count etc
	if (TF2_IsWearable(fromWeapon))	//Pass non-wearable weapon just so it doesn't crash
		SDKCall_InitDroppedWeapon(droppedWeapon, client, TF2_GetItemInSlot(client, WeaponSlot_Melee), swap);
	else
		SDKCall_InitDroppedWeapon(droppedWeapon, client, fromWeapon, swap);
	
	TeleportEntity(droppedWeapon, origin, NULL_VECTOR, NULL_VECTOR);
	if (!UnstuckEntity(droppedWeapon))
	{
		LogError("Unable to unstuck dropped weapon at origin '%.0f %.0f %.0f'", droppedWeapon, origin[0], origin[1], origin[2]);
		RemoveEntity(droppedWeapon);
		return INVALID_ENT_REFERENCE;
	}
	
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

stock int TF2_GetSlot(int weapon)
{
	if (TF2_IsWearable(weapon))
	{
		int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
		{
			int slot = TF2_GetItemSlot(index, view_as<TFClassType>(class));
			if (0 <= slot <= WeaponSlot_BuilderEngie)
				return slot;
		}
	}
	else
	{
		return SDKCall_GetSlot(weapon);
	}
	
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
		
		// Action weapons share toolbox slot
		if (slot == WeaponSlot_Action)
			slot = WeaponSlot_BuilderEngie;
	}
	
	return slot;
}

stock bool TF2_GetItem(int client, int &weapon, int &pos)
{
	//Could be looped through client slots, but would cause issues with >1 weapons in same slot
	
	static int maxWeapons;
	if (!maxWeapons)
		maxWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	
	//Loop though all weapons (non-wearables)
	while (pos < maxWeapons)
	{
		weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", pos);
		pos++;
		
		if (weapon > MaxClients)
			return true;
		
		//Reset weapon for wearable loop below
		if (pos == maxWeapons)
			weapon = MaxClients+1;
	}
	
	//Loop through all weapon wearables (don't allow cosmetics)
	while ((weapon = FindEntityByClassname(weapon, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == client || GetEntPropEnt(weapon, Prop_Send, "moveparent") == client)
		{
			if (0 <= TF2_GetSlot(weapon) <= WeaponSlot_BuilderEngie)
				return true;
		}
	}
	
	return false;
}

stock int TF2_GetItemByClassname(int client, const char[] classname)
{
	int weapon, pos;
	while (TF2_GetItem(client, weapon, pos))
	{
		char buffer[256];
		GetEntityClassname(weapon, buffer, sizeof(buffer));
		if (StrEqual(classname, buffer))
			return weapon;
	}
	
	return INVALID_ENT_REFERENCE;
}

stock int TF2_GetItemInSlot(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (weapon > MaxClients)
		return weapon;
	
	//If weapon not found in slot, check if it a wearable
	return SDKCall_GetEquippedWearableForLoadoutSlot(client, slot);
}

stock void TF2_RemoveItem(int client, int weapon)
{
	if (TF2_IsWearable(weapon))
	{
		//If wearable, just simply use TF2_RemoveWearable
		TF2_RemoveWearable(client, weapon);
		return;
	}
	
	//Below similar to TF2_RemoveWeaponSlot, but only removes 1 weapon instead of all weapons in 1 slot
	
	int iExtraWearable = GetEntPropEnt(weapon, Prop_Send, "m_hExtraWearable");
	if (iExtraWearable != -1)
		TF2_RemoveWearable(client, iExtraWearable);
	
	iExtraWearable = GetEntPropEnt(weapon, Prop_Send, "m_hExtraWearableViewModel");
	if (iExtraWearable != -1)
		TF2_RemoveWearable(client, iExtraWearable);
	
	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);
}

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);

	int wearable = SDKCall_GetEquippedWearableForLoadoutSlot(client, slot);
	if (wearable > MaxClients)
		TF2_RemoveWearable(client, wearable);
}

stock void TF2_CreateSetupTimer(int duration, EntityOutput callback)
{
	int timer = CreateEntityByName("team_round_timer");
	
	char string[12];
	IntToString(duration, string, sizeof(string));
	DispatchKeyValue(timer, "setup_length", string);
	
	DispatchKeyValue(timer, "show_in_hud", "1");
	DispatchSpawn(timer);
	HookSingleEntityOutput(timer, "OnSetupFinished", callback);
	
	AcceptEntityInput(timer, "Enable");
	AcceptEntityInput(timer, "Resume");
	
	Event event = CreateEvent("teamplay_update_timer");
	event.Fire();
}

stock void TF2_ForceRoundWin(TFTeam team)
{
	int roundwin = CreateEntityByName("game_round_win"); 
	DispatchSpawn(roundwin);

	SetVariantString("force_map_reset 1");
	AcceptEntityInput(roundwin, "AddOutput");
	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(roundwin, "SetTeam");
	AcceptEntityInput(roundwin, "RoundWin");
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
		{
			AcceptEntityInput(msg, "Display");
			RemoveEntity(msg);
		}
	}
}

stock int TF2_DropItem(int client, const char[] classname, float lifeTime = 30.0)
{
	int item = CreateEntityByName(classname);
	
	if (IsValidEntity(item))
	{
		DispatchKeyValue(item, "OnPlayerTouch", "!self,Kill,,0,-1");
		
		if (DispatchSpawn(item))
		{
			DispatchKeyValue(item, "nextthink", "0.1");
			
			SetEntityMoveType(item, MOVETYPE_FLYGRAVITY);
			SetEntProp(item, Prop_Data, "m_MoveCollide", MOVECOLLIDE_FLY_BOUNCE);
			SetEntProp(item, Prop_Data, "m_nSolidType", SOLID_BBOX);
			SetEntPropEnt(item, Prop_Data, "m_hOwnerEntity", client);
			
			float origin[3];
			WorldSpaceCenter(client, origin);
			
			float impulse[3];
			impulse[0] = GetRandomFloat(-1.0);
			impulse[1] = GetRandomFloat(-1.0);
			impulse[2] = 1.0;
			NormalizeVector(impulse, impulse);
			ScaleVector(impulse, 250.0);
			
			TeleportEntity(item, origin, NULL_VECTOR, impulse);
			
			int ref = EntIndexToEntRef(item);
			
			if (lifeTime > 0.0)
				CreateTimer(lifeTime, Timer_DestroyItem, ref);
			
			return ref;
		}
	}
	
	return INVALID_ENT_REFERENCE;
}

stock int TF2_GetMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

public Action Timer_UpdateClientHud(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (0 < client <= MaxClients)
	{
		//Call client to reset HUD meter
		Event event = CreateEvent("localplayer_pickup_weapon", true);
		event.FireToClient(client);
		event.Cancel();
	}
}

public Action Timer_DestroyItem(Handle timer, int ref)
{
	if (IsValidEntity(ref))
		RemoveEntity(ref);
}