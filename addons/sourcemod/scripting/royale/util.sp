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

void ItemGiveTo(int client, int item)
{
	if (TF2Util_IsEntityWearable(item))
	{
		TF2Util_EquipPlayerWearable(client, item);
	}
	else
	{
		EquipPlayerWeapon(client, item);
	}
}

bool ModelIndexToString(int stringidx, char[] str, int maxlength)
{
	int tableidx = FindStringTable("modelprecache");
	if (tableidx == INVALID_STRING_INDEX)
		return false;
	
	return ReadStringTable(tableidx, stringidx, str, maxlength) != 0;
}

any FindItemOffset(int entity)
{
	char clsname[32];
	if (!GetEntityNetClass(entity, clsname, sizeof(clsname)))
		return -1;
	
	return FindSendPropInfo(clsname, "m_Item");
}

bool GetItemWorldModel(int item, char[] model, int size)
{
	int iItemDefIndex = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
	
	// Check if the weapon config has a model set
	WeaponData data;
	if (Config_GetWeaponDataByDefIndex(iItemDefIndex, data) && data.world_model[0])
	{
		PrecacheModel(data.world_model);
		return strcopy(model, size, data.world_model) != 0;
	}
	
	int nModelIndex = 0;
	if (HasEntProp(item, Prop_Send, "m_iWorldModelIndex"))
		nModelIndex = GetEntProp(item, Prop_Send, "m_iWorldModelIndex");
	else
		nModelIndex = GetEntProp(item, Prop_Send, "m_nModelIndex");
	
	if (nModelIndex == 0)
		return false;
	
	return ModelIndexToString(nModelIndex, model, size);
}

float GetPercentInvisible(int client)
{
	static int offset = -1;
	if (offset == -1)
		offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	
	return GetEntDataFloat(client, offset);
}

void SendHudNotificationCustom(int client, const char[] text, const char[] icon, TFTeam team = TFTeam_Unassigned)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("HudNotifyCustom", client));
	bf.WriteString(text);
	bf.WriteString(icon);
	bf.WriteByte(view_as<int>(team));
	EndMessage();
}

void SendHudNotification(HudNotification_t type, bool forceShow = false)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageAll("HudNotify"));
	bf.WriteByte(view_as<int>(type));
	bf.WriteBool(forceShow);	// Display in cl_hud_minmode
	EndMessage();
}

void TF2_RemovePlayerItem(int client, int item)
{
	if (TF2Util_IsEntityWeapon(item))
	{
		// Remove any extra wearables associated with the weapon
		int extraWearable = GetEntPropEnt(item, Prop_Send, "m_hExtraWearable");
		if (extraWearable != -1)
		{
			TF2_RemoveWearable(client, extraWearable);
		}
		
		// And their viewmodel too
		extraWearable = GetEntPropEnt(item, Prop_Send, "m_hExtraWearableViewModel");
		if (extraWearable != -1)
		{
			TF2_RemoveWearable(client, extraWearable);
		}
		
		RemovePlayerItem(client, item);
	}
	else if (TF2Util_IsEntityWearable(item))
	{
		TF2_RemoveWearable(client, item);
	}
	
	RemoveEntity(item);
}

bool ShouldUseCustomViewModel(int client, int weapon)
{
	return IsWeaponFists(weapon) && TF2_GetPlayerClass(client) != TFClass_Heavy;
}

int CreateViewModelWearable(int client, int weapon)
{
	int wearable = CreateEntityByName("tf_wearable_vm");
	
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(client, Prop_Send, "m_angRotation", vecAngles);
	TeleportEntity(wearable, vecOrigin, vecAngles);
	
	SetEntProp(wearable, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(wearable, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(wearable, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
	SetEntProp(wearable, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_WEAPON);
	SetEntProp(wearable, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL);
	
	if (IsValidEntity(weapon))
	{
		SetEntPropEnt(wearable, Prop_Send, "m_hWeaponAssociatedWith", weapon);
		SetEntPropEnt(weapon, Prop_Send, "m_hExtraWearableViewModel", wearable);
	}
	
	DispatchSpawn(wearable);
	ItemGiveTo(client, wearable);
	
	SetVariantString("!activator");
	AcceptEntityInput(wearable, "SetParent", GetEntPropEnt(client, Prop_Send, "m_hViewModel"));
	
	return wearable;
}

int GetEntityForLoadoutSlot(int client, int loadoutSlot)
{
	int entity = TF2Util_GetPlayerLoadoutEntity(client, loadoutSlot);
	if (entity != -1)
		return entity;
	
	// TF2Util_GetPlayerLoadoutEntity does not find weapons equipped by the wrong classes.
	// Iterate all classes and check their weapons.
	for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		for (int i = 0; i < MAX_WEAPONS; i++)
		{
			int myWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if (myWeapon != -1)
			{
				int itemdef = GetEntProp(myWeapon, Prop_Send, "m_iItemDefinitionIndex");
				if (itemdef == INVALID_ITEM_DEF_INDEX)
					continue;
				
				if (TF2Econ_GetItemLoadoutSlot(itemdef, class) == loadoutSlot)
					return myWeapon;
			}
		}
	}
	
	return -1;
}

bool IsWeaponFists(int weapon)
{
	if (!IsValidEntity(weapon))
		return false;
	
	if (!TF2Util_IsEntityWeapon(weapon))
		return false;
	
	int iItemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	return (iItemDefIndex == TF_DEFINDEX_FISTS || iItemDefIndex == TF_DEFINDEX_UPGRADEABLE_FISTS);
}

void InitDroppedWearable(int droppedWeapon, int client, int wearable, bool bSwap)
{
	// No physics object, don't apply any velocity
	Address pPhysicsObject = view_as<Address>(GetEntData(droppedWeapon, FindDataMapInfo(droppedWeapon, "m_pPhysicsObject")));
	if (pPhysicsObject == Address_Null)
		return;
	
	float vecImpulse[3];
	float flImpulseScale = 0.0;
	if (bSwap && IsValidEntity(client))
	{
		float vecEyeAngles[3];
		GetClientEyeAngles(client, vecEyeAngles);
		
		float vecForward[3], vecUp[3];
		GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, vecUp);
		AddVectors(vecImpulse, { 0.0, 0.0, 1.5 }, vecImpulse);
		AddVectors(vecUp, vecForward, vecImpulse);
		flImpulseScale = 250.0;
	}
	else
	{
		float vecAngles[3];
		GetEntPropVector(droppedWeapon, Prop_Data, "m_angAbsRotation", vecAngles);
		
		float vecRight[3], vecUp[3];
		GetAngleVectors(vecAngles, NULL_VECTOR, vecRight, vecUp);
		ScaleVector(vecUp, GetRandomFloat(-0.25, 0.25));
		ScaleVector(vecRight, GetRandomFloat(-0.25, 0.25));
		flImpulseScale = GetRandomFloat(100.0, 150.0);
	}
	
	NormalizeVector(vecImpulse, vecImpulse);
	ScaleVector(vecImpulse, flImpulseScale);
	
	float vecVelocity[3];
	GetEntPropVector(droppedWeapon, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	AddVectors(vecImpulse, vecVelocity, vecImpulse);
	
	TeleportEntity(droppedWeapon, .velocity = vecImpulse);
}

bool ShouldDropWeapon(int client, int weapon)
{
	if (TF2_GetPlayerClass(client) == TFClass_Engineer && TF2Util_GetWeaponID(weapon) == TF_WEAPON_BUILDER)
		return false;
	
	if (IsWeaponFists(weapon))
		return false;
	
	return true;
}

int GenerateDefaultItem(int client, int defindex)
{
	Handle item = TF2Items_CreateItem(FORCE_GENERATION | PRESERVE_ATTRIBUTES);
	
	char classname[64];
	TF2Econ_GetItemClassName(defindex, classname, sizeof(classname));
	TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), TF2_GetPlayerClass(client));
	
	TF2Items_SetItemIndex(item, defindex);
	TF2Items_SetClassname(item, classname);
	
	int weapon = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	// Fake global id
	static int s_nFakeID = 1;
	SetItemID(weapon, s_nFakeID++);
	
	SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
	SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	
	return weapon;
}

void SetItemID(int weapon, int iIdx)
{
	char clsname[64];
	if (GetEntityNetClass(weapon, clsname, sizeof(clsname)))
	{
		SetEntData(weapon, FindSendPropInfo(clsname, "m_iItemIDHigh") - 4, iIdx);	// m_iItemID
		SetEntProp(weapon, Prop_Send, "m_iItemIDHigh", iIdx >> 32);
		SetEntProp(weapon, Prop_Send, "m_iItemIDLow", iIdx & 0xFFFFFFFF);
	}
}

bool CanWeaponBeUsedByClass(int weapon, TFClassType class)
{
	int iItemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	return TF2Econ_GetItemLoadoutSlot(iItemDefIndex, class) != -1;
}

void TE_TFParticleEffect(const char[] name, const float vecOrigin[3] = NULL_VECTOR,
	const float vecStart[3] = NULL_VECTOR, const float vecAngles[3] = NULL_VECTOR,
	int entity = -1, ParticleAttachment_t attachType = PATTACH_ABSORIGIN,
	int attachPoint = -1, bool bResetParticles = false)
{
	int particleTable, particleIndex;
	
	if ((particleTable = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
	{
		ThrowError("Could not find string table: ParticleEffectNames");
	}
	
	if ((particleIndex = FindStringIndex(particleTable, name)) == INVALID_STRING_INDEX)
	{
		ThrowError("Could not find particle index: %s", name);
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vecOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vecOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vecOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vecStart[0]);
	TE_WriteFloat("m_vecStart[1]", vecStart[1]);
	TE_WriteFloat("m_vecStart[2]", vecStart[2]);
	TE_WriteVector("m_vecAngles", vecAngles);
	TE_WriteNum("m_iParticleSystemIndex", particleIndex);
	
	if (entity != -1)
	{
		TE_WriteNum("entindex", entity);
	}
	
	if (attachType != PATTACH_ABSORIGIN)
	{
		TE_WriteNum("m_iAttachType", view_as<int>(attachType));
	}
	
	if (attachPoint != -1)
	{
		TE_WriteNum("m_iAttachmentPointIndex", attachPoint);
	}
	
	TE_WriteNum("m_bResetParticles", bResetParticles ? 1 : 0);
	
	TE_SendToAll();
}

int Compare(any val1, any val2)
{
	if (val1 > val2)
	{
		return 1;
	}
	else if (val1 < val2)
	{
		return -1;
	}
	
	return 0;
}

int SortFuncADTArray_SortCrateContentsRandom(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);
	
	CrateContentConfig content1, content2;
	list.GetArray(index1, content1);
	list.GetArray(index2, content2);
	
	float rand = GetRandomFloat();
	
	// Compare each element against a random number
	int c1 = FloatCompare(rand, content1.chance);
	int c2 = FloatCompare(rand, content2.chance);
	
	// If both are the same, pick a random one
	return (c1 == c2) ? GetRandomInt(-1, 1) : Compare(c1, c2);
}

int CreateDroppedWeapon(int lastOwner, const float vecOrigin[3], const float vecAngles[3], char[] szModelName, Address pItem)
{
	ArrayList droppedWeapons = new ArrayList();
	
	// CTFDroppedWeapon::Create starts deleting old weapons if there are too many in the world.
	// Add EFL_KILLME flag to all dropped weapons to bypass this.
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_dropped_weapon")) != -1)
	{
		int flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
		if (!(flags & EFL_KILLME))
		{
			SetEntProp(entity, Prop_Data, "m_iEFlags", flags | EFL_KILLME);
			droppedWeapons.Push(entity);
		}
	}
	
	int droppedWeapon = SDKCall_CTFDroppedWeapon_Create(lastOwner, vecOrigin, vecAngles, szModelName, pItem);
	
	for (int i = 0; i < droppedWeapons.Length; i++)
	{
		int flags = GetEntProp(droppedWeapons.Get(i), Prop_Data, "m_iEFlags");
		flags = flags &= ~EFL_KILLME;
		SetEntProp(droppedWeapons.Get(i), Prop_Data, "m_iEFlags", flags);
	}
	
	delete droppedWeapons;
	return droppedWeapon;
}

int CountCharInString(const char[] str, char c) 
{
	int i = 0, count = 0;
	
	while (str[i] != '\0') 
	{
		if (str[i++] == c)
		{
			count++;
		}
	}
	
	return count;
}

// TODO: Make this less bad
void TF2_CreateSetupTimer(int duration, EntityOutput callback)
{
	int timer = CreateEntityByName("team_round_timer");
	
	char string[12];
	IntToString(duration, string, sizeof(string));
	DispatchKeyValue(timer, "setup_length", string);
	
	DispatchKeyValue(timer, "show_in_hud", "1");
	DispatchKeyValue(timer, "start_paused", "0");
	DispatchSpawn(timer);
	HookSingleEntityOutput(timer, "OnSetupFinished", callback, true);
	
	AcceptEntityInput(timer, "Enable");
	
	Event event = CreateEvent("teamplay_update_timer", true);
	event.Fire();
}

// TODO: Make this less bad
int GetAlivePlayersCount()
{
	int count = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).IsAlive())
			count++;
	}
	
	return count;
}
