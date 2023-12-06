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

bool IsValidClient(int client)
{
	return (0 < client <= MaxClients) && IsValidEntity(client) && IsClientInGame(client);
}

any Min(any a, any b)
{
	return (a <= b) ? a : b;
}

any Max(any a, any b)
{
	return (a >= b) ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
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

bool GetItemWorldModel(int item, char[] szWorldModel, int iMaxLength)
{
	int iItemDefIndex = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
	
	// Check if the weapon config has a model set
	WeaponData data;
	if (Config_GetWeaponDataByDefIndex(iItemDefIndex, data) && data.world_model[0])
	{
		PrecacheModel(data.world_model);
		return strcopy(szWorldModel, iMaxLength, data.world_model) != 0;
	}
	
	if (TF2Util_IsEntityWeapon(item))
	{
		SDKCall_CBaseCombatWeapon_GetWorldModel(item, szWorldModel, iMaxLength);
		return szWorldModel[0];
	}
	else
	{
		if (HasEntProp(item, Prop_Send, "m_nWorldModelIndex"))
		{
			int nWorldModelIndex = GetEntProp(item, Prop_Send, "m_nWorldModelIndex");
			if (nWorldModelIndex != 0)
			{
				return ModelIndexToString(nWorldModelIndex, szWorldModel, iMaxLength);
			}
		}
		
		int nModelIndex = GetEntProp(item, Prop_Send, "m_nModelIndex");
		if (nModelIndex != 0)
		{
			return ModelIndexToString(nModelIndex, szWorldModel, iMaxLength);
		}
	}
	
	return false;
}

float GetPercentInvisible(int client)
{
	static int iOffset = -1;
	if (iOffset == -1)
		iOffset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	
	return GetEntDataFloat(client, iOffset);
}

void SendHudNotificationCustom(int client, const char[] szText, const char[] szIcon, TFTeam nTeam = TFTeam_Unassigned)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("HudNotifyCustom", client));
	bf.WriteString(szText);
	bf.WriteString(szIcon);
	bf.WriteByte(view_as<int>(nTeam));
	EndMessage();
}

void SendHudNotification(HudNotification_t iType, bool bForceShow = false)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageAll("HudNotify"));
	bf.WriteByte(view_as<int>(iType));
	bf.WriteBool(bForceShow);	// Display in cl_hud_minmode
	EndMessage();
}

void RemoveExtraWearables(int item)
{
	int hExtraWearable = GetEntPropEnt(item, Prop_Send, "m_hExtraWearable");
	if (hExtraWearable != -1)
	{
		TF2_RemoveWearable(GetEntPropEnt(hExtraWearable, Prop_Send, "m_hOwnerEntity"), hExtraWearable);
		SetEntPropEnt(item, Prop_Send, "m_hExtraWearable", -1);
	}
	
	int hExtraWearableViewModel = GetEntPropEnt(item, Prop_Send, "m_hExtraWearableViewModel");
	if (hExtraWearableViewModel != -1)
	{
		TF2_RemoveWearable(GetEntPropEnt(hExtraWearableViewModel, Prop_Send, "m_hOwnerEntity"), hExtraWearableViewModel);
		SetEntPropEnt(item, Prop_Send, "m_hExtraWearableViewModel", -1);
	}
}

bool ShouldUseCustomViewModel(int client, int weapon)
{
	return IsWeaponFists(weapon) && TF2_GetPlayerClass(client) != TFClass_Heavy;
}

int CreateViewModelWearable(int client, int weapon)
{
	int wearable = CreateEntityByName("tf_wearable_vm");
	
	float vecOrigin[3], vecAngles[3];
	CBaseEntity(client).GetAbsOrigin(vecOrigin);
	CBaseEntity(client).GetAbsAngles(vecAngles);
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
	FRPlayer(client).EquipItem(wearable);
	
	SetVariantString("!activator");
	AcceptEntityInput(wearable, "SetParent", GetEntPropEnt(client, Prop_Send, "m_hViewModel"));
	
	return wearable;
}

int GetEntityForLoadoutSlot(int client, int iLoadoutSlot)
{
	int entity = TF2Util_GetPlayerLoadoutEntity(client, iLoadoutSlot);
	if (entity != -1)
		return entity;
	
	// TF2Util_GetPlayerLoadoutEntity does not find weapons equipped by the wrong classes.
	// Iterate all classes and check their weapons.
	for (TFClassType nClass = TFClass_Scout; nClass <= TFClass_Engineer; nClass++)
	{
		for (int i = 0; i < MAX_WEAPONS; i++)
		{
			int myWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if (myWeapon != -1)
			{
				int iItemDefIndex = GetEntProp(myWeapon, Prop_Send, "m_iItemDefinitionIndex");
				if (iItemDefIndex == INVALID_ITEM_DEF_INDEX)
					continue;
				
				// Only if our class does not have a matching loadout slot for this weapon
				if (TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass) == iLoadoutSlot && TF2Econ_GetItemLoadoutSlot(iItemDefIndex, TF2_GetPlayerClass(client)) == -1)
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
	CBaseEntity(droppedWeapon).GetAbsVelocity(vecVelocity);
	AddVectors(vecImpulse, vecVelocity, vecImpulse);
	
	TeleportEntity(droppedWeapon, .velocity = vecImpulse);
}

bool ShouldDropItem(int client, int weapon)
{
	// Don't drop engineer's toolbox
	if (TF2_GetPlayerClass(client) == TFClass_Engineer && IsWeaponOfID(weapon, TF_WEAPON_BUILDER))
		return false;
	
	// Don't allow dropping our starting parachute
	if (FRPlayer(client).m_bIsParachuting && IsWeaponOfID(weapon, TF_WEAPON_PARACHUTE))
		return false;
	
	if (IsWeaponFists(weapon))
		return false;
	
	return true;
}

int GenerateDefaultItem(int client, int iItemDefIndex)
{
	char szWeaponName[64];
	if (!TF2Econ_GetItemClassName(iItemDefIndex, szWeaponName, sizeof(szWeaponName)))
		return -1;
	
	TFClassType nClass = TF2_GetPlayerClass(client);
	TF2Econ_TranslateWeaponEntForClass(szWeaponName, sizeof(szWeaponName), nClass);
	
	int weapon = CreateEntityByName(szWeaponName);
	
	if (!IsValidEntity(weapon))
		return -1;
	
	SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", iItemDefIndex);
	SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
	
	// Fake global id
	static int s_nFakeID = 1;
	SetItemID(weapon, s_nFakeID++);
	
	SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
	SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	
	if (nClass == TFClass_Spy && IsWeaponOfID(weapon, TF_WEAPON_BUILDER))
	{
		SDKCall_CBaseCombatWeapon_SetSubType(weapon, TFObject_Sapper);
	}
	
	DispatchSpawn(weapon);
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

void TE_TFParticleEffect(const char[] szName, const float vecOrigin[3] = NULL_VECTOR,
	const float vecStart[3] = NULL_VECTOR, const float vecAngles[3] = NULL_VECTOR,
	int entindex = -1, ParticleAttachment_t iAttachType = PATTACH_ABSORIGIN,
	int iAttachmentPointIndex = -1, bool bResetParticles = false)
{
	int iParticleTable, iParticleSystemIndex;
	
	if ((iParticleTable = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
	{
		ThrowError("Could not find string table: ParticleEffectNames");
	}
	
	if ((iParticleSystemIndex = FindStringIndex(iParticleTable, szName)) == INVALID_STRING_INDEX)
	{
		ThrowError("Could not find particle index: %s", szName);
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vecOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vecOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vecOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vecStart[0]);
	TE_WriteFloat("m_vecStart[1]", vecStart[1]);
	TE_WriteFloat("m_vecStart[2]", vecStart[2]);
	TE_WriteVector("m_vecAngles", vecAngles);
	TE_WriteNum("m_iParticleSystemIndex", iParticleSystemIndex);
	TE_WriteNum("entindex", entindex);
	TE_WriteNum("m_iAttachType", view_as<int>(iAttachType));
	TE_WriteNum("m_iAttachmentPointIndex", iAttachmentPointIndex);
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

/**
 * NOTE: This function shuffles in reverse order.
 */
int SortFuncADTArray_ShuffleCrateContentsWeighted(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);
	
	CrateContentData content1, content2;
	list.GetArray(index1, content1);
	list.GetArray(index2, content2);
	
	float flRand = GetRandomFloat();
	
	// Compare each element against a random number
	int c1 = FloatCompare(flRand, content2.chance);
	int c2 = FloatCompare(flRand, content1.chance);
	
	// If both are the same, pick a random one
	return (c1 == c2) ? GetRandomInt(-1, 1) : Compare(c1, c2);
}

int CreateDroppedWeapon(const float vecOrigin[3], const float vecAngles[3], char[] szModelName, Address pItem)
{
	ArrayList droppedWeapons = new ArrayList();
	
	// CTFDroppedWeapon::Create starts deleting old weapons if there are too many in the world.
	// Add EFL_KILLME flag to all dropped weapons to bypass this.
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_dropped_weapon")) != -1)
	{
		int iEFlags = GetEntProp(entity, Prop_Data, "m_iEFlags");
		if (!(iEFlags & EFL_KILLME))
		{
			SetEntProp(entity, Prop_Data, "m_iEFlags", iEFlags | EFL_KILLME);
			droppedWeapons.Push(entity);
		}
	}
	
	// Pass NULL for pLastOwner to avoid old weapons getting deleted
	int droppedWeapon = SDKCall_CTFDroppedWeapon_Create(-1, vecOrigin, vecAngles, szModelName, pItem);
	
	for (int i = 0; i < droppedWeapons.Length; i++)
	{
		int iEFlags = GetEntProp(droppedWeapons.Get(i), Prop_Data, "m_iEFlags");
		iEFlags = iEFlags &= ~EFL_KILLME;
		SetEntProp(droppedWeapons.Get(i), Prop_Data, "m_iEFlags", iEFlags);
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

bool ShouldGoToSetup()
{
	return GetActivePlayerCount() > 1;
}

bool ShouldTryToEndMatch()
{
	return GetAlivePlayerCount() <= 1;
}

int GetActivePlayerCount()
{
	int iCount = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (TF2_GetClientTeam(client) > TFTeam_Spectator)
			iCount++;
	}
	
	return iCount;
}

int GetAlivePlayerCount()
{
	int iCount = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (FRPlayer(client).IsAlive())
			iCount++;
	}
	
	return iCount;
}

void SuperPrecacheModel(const char[] szModel)
{
	char szBase[PLATFORM_MAX_PATH], szPath[PLATFORM_MAX_PATH];
	strcopy(szBase, sizeof(szBase), szModel);
	SplitString(szBase, ".mdl", szBase, sizeof(szBase));
	
	AddFileToDownloadsTable(szModel);
	PrecacheModel(szModel);
	
	Format(szPath, sizeof(szPath), "%s.phy", szBase);
	if (FileExists(szPath))
	{
		AddFileToDownloadsTable(szPath);
	}
	
	Format(szPath, sizeof(szPath), "%s.vvd", szBase);
	if (FileExists(szPath))
	{
		AddFileToDownloadsTable(szPath);
	}
	
	Format(szPath, sizeof(szPath), "%s.dx80.vtx", szBase);
	if (FileExists(szPath))
	{
		AddFileToDownloadsTable(szPath);
	}
	
	Format(szPath, sizeof(szPath), "%s.dx90.vtx", szBase);
	if (FileExists(szPath))
	{
		AddFileToDownloadsTable(szPath);
	}
	
	Format(szPath, sizeof(szPath), "%s.sw.vtx", szBase);
	if (FileExists(szPath))
	{
		AddFileToDownloadsTable(szPath);
	}
}

bool IsInWaitingForPlayers()
{
	return GameRules_GetProp("m_bInWaitingForPlayers") || g_nRoundState == FRRoundState_WaitingForPlayers;
}

void SetWinningTeam(TFTeam team = TFTeam_Unassigned)
{
	int round_win = CreateEntityByName("game_round_win");
	if (round_win != -1)
	{
		DispatchKeyValue(round_win, "force_map_reset", "1");
		SetEntProp(round_win, Prop_Data, "m_iTeamNum", team);
		
		AcceptEntityInput(round_win, "RoundWin");
		RemoveEntity(round_win);
	}
}

void DissolveEntity(int entity)
{
	int dissolver = CreateEntityByName("env_entity_dissolver");
	if (IsValidEntity(dissolver) && DispatchSpawn(dissolver))
	{
		SetVariantString("!activator");
		AcceptEntityInput(dissolver, "SetParent", entity);
		
		SetVariantString("!activator");
		AcceptEntityInput(dissolver, "Dissolve", entity);
	}
}

void ScreenFade(int client, int r, int g, int b, int a, int duration, int holdTime, int fadeFlags)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("Fade", client));
	bf.WriteShort(duration);	// fade lasts this long
	bf.WriteShort(holdTime);	// fade lasts this long
	bf.WriteShort(fadeFlags);	// fade type (in / out)
	bf.WriteByte(r);			// fade red
	bf.WriteByte(g);			// fade green
	bf.WriteByte(b);			// fade blue
	bf.WriteByte(a);			// fade alpha
	EndMessage();
}

bool IsWeaponOfID(int weapon, int weaponID)
{
	return TF2Util_IsEntityWeapon(weapon) && TF2Util_GetWeaponID(weapon) == weaponID;
}

bool TraceEntityFilter_HitWorld(int entity, int mask)
{
	return entity == 0;
}
