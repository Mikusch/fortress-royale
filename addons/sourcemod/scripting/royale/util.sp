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
	// TODO: Custom config model support
	int modelIndex = 0;
	if (HasEntProp(item, Prop_Send, "m_iWorldModelIndex"))
		modelIndex = GetEntProp(item, Prop_Send, "m_iWorldModelIndex");
	else
		modelIndex = GetEntProp(item, Prop_Send, "m_nModelIndex");
	
	if (modelIndex == 0)
		return false;
	
	return ModelIndexToString(modelIndex, model, size);
}

float TF2_GetPercentInvisible(int client)
{
	static int offset = -1;
	if (offset == -1)
		offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	
	return GetEntDataFloat(client, offset);
}

void ShowGameMessage(const char[] message, const char[] icon, int displayToTeam = 0, int teamColor = 0)
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

void TF2_RemovePlayerItem(int client, int item)
{
	if (TF2Util_IsEntityWearable(item))
	{
		TF2_RemoveWearable(client, item);
	}
	else if (TF2Util_IsEntityWeapon(item))
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
	TF2Util_EquipPlayerWearable(client, wearable);
	
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

int GivePlayerFists(int client)
{
	Handle item = TF2Items_CreateItem(FORCE_GENERATION | OVERRIDE_ALL);
	
	TF2Items_SetItemIndex(item, TF_DEFINDEX_FISTS);
	TF2Items_SetLevel(item, 1);
	
	char classname[64];
	TF2Econ_GetItemClassName(TF_DEFINDEX_FISTS, classname, sizeof(classname));
	TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), TF2_GetPlayerClass(client));
	TF2Items_SetClassname(item, classname);
	
	int weapon = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	EquipPlayerWeapon(client, weapon);
	TF2Util_SetPlayerActiveWeapon(client, weapon);
	
	return weapon;
}

bool CanWeaponBeUsedByClass(int weapon, TFClassType class)
{
	int iItemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	return TF2Econ_GetItemLoadoutSlot(iItemDefIndex, class) != -1;
}