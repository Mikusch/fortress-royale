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

static DynamicHook g_DHook_CBaseCombatCharacter_TakeHealth;
static DynamicHook g_DHook_CBasePlayer_ForceRespawn;
static DynamicHook g_DHook_CBaseCombatWeapon_PrimaryAttack;
static DynamicHook g_DHook_CBaseCombatWeapon_SecondaryAttack;

static TFClassType g_nPrevClass;

void DHooks_Init()
{
	g_DHook_CBaseCombatCharacter_TakeHealth = PSM_AddDynamicHookFromConf("CBaseCombatCharacter::TakeHealth");
	g_DHook_CBasePlayer_ForceRespawn = PSM_AddDynamicHookFromConf("CBasePlayer::ForceRespawn");
	g_DHook_CBaseCombatWeapon_PrimaryAttack = PSM_AddDynamicHookFromConf("CBaseCombatWeapon::PrimaryAttack");
	g_DHook_CBaseCombatWeapon_SecondaryAttack = PSM_AddDynamicHookFromConf("CBaseCombatWeapon::SecondaryAttack");
	
	PSM_AddDynamicDetourFromConf("CTFDroppedWeapon::Create", CTFDroppedWeapon_Create_Pre);
	PSM_AddDynamicDetourFromConf("CTFPlayer::PickupWeaponFromOther", CTFPlayer_PickupWeaponFromOther_Pre);
	PSM_AddDynamicDetourFromConf("CTFPlayer::GetMaxAmmo", _, CTFPlayer_GetMaxAmmo_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::GiveAmmo", CTFPlayer_GiveAmmo_Pre, CTFPlayer_GiveAmmo_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::GetMaxHealthForBuffing", _, CTFPlayer_GetMaxHealthForBuffing_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::RegenThink", CTFPlayer_RegenThink_Pre, CTFPlayer_RegenThink_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::DoClassSpecialSkill", CTFPlayer_DoClassSpecialSkill_Pre);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::CanRecieveMedigunChargeEffect", CTFPlayerShared_CanRecieveMedigunChargeEffect_Pre);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::Heal", CTFPlayerShared_Heal_Pre);
}

void DHooks_HookEntity(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		PSM_DHookEntity(g_DHook_CBaseCombatCharacter_TakeHealth, Hook_Pre, entity, CBaseCombatCharacter_TakeHealth_Pre);
		PSM_DHookEntity(g_DHook_CBasePlayer_ForceRespawn, Hook_Pre, entity, CBasePlayer_ForceRespawn_Pre);
	}
	else if (StrEqual(classname, "tf_weapon_fists"))
	{
		PSM_DHookEntity(g_DHook_CBaseCombatWeapon_PrimaryAttack, Hook_Post, entity, CTFFists_PrimaryAttack_Post);
		PSM_DHookEntity(g_DHook_CBaseCombatWeapon_SecondaryAttack, Hook_Post, entity, CTFFists_SecondaryAttack_Post);
	}
}

static MRESReturn CTFDroppedWeapon_Create_Pre(DHookReturn ret, DHookParam params)
{
	if (IsInWaitingForPlayers())
		return MRES_Ignored;
	
	// Prevent dropped weapon creation from TF2 itself by setting pLastOwner to NULL
	if (!params.IsNull(1))
	{
		ret.Value = -1;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_PickupWeaponFromOther_Pre(int player, DHookReturn ret, DHookParam params)
{
	int droppedWeapon = params.Get(1);
	
	Address pItem = GetEntityAddress(droppedWeapon) + FindItemOffset(droppedWeapon);
	if (!LoadFromAddress(pItem, NumberType_Int32))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (GetEntProp(droppedWeapon, Prop_Send, "m_bInitialized"))
	{
		int iItemDefIndex = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		TFClassType nClass = TF2_GetPlayerClass(player);
		int iItemSlot = TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass);
		int weapon = GetEntityForLoadoutSlot(player, iItemSlot);
		
		// we need to force translating the name here.
		// GiveNamedItem will not translate if we force creating the item
		char szTranslatedWeaponName[64];
		TF2Econ_GetItemClassName(iItemDefIndex, szTranslatedWeaponName, sizeof(szTranslatedWeaponName));
		TF2Econ_TranslateWeaponEntForClass(szTranslatedWeaponName, sizeof(szTranslatedWeaponName), nClass);
		
		int newItem = SDKCall_CTFPlayer_GiveNamedItem(player, szTranslatedWeaponName, 0, pItem, true);
		if (IsValidEntity(newItem))
		{
			if (nClass == TFClass_Spy && IsWeaponOfID(newItem, TF_WEAPON_BUILDER))
			{
				RunScriptCode(newItem, -1, -1, "self.SetSubType(%d)", TFObject_Sapper);
			}
			
			// make sure we removed our current weapon
			if (IsValidEntity(weapon))
			{
				if (ShouldDropItem(player, weapon))
				{
					// drop current weapon
					float vecPackOrigin[3], vecPackAngles[3];
					SDKCall_CTFPlayer_CalculateAmmoPackPositionAndAngles(player, weapon, vecPackOrigin, vecPackAngles);
					
					char szWorldModel[PLATFORM_MAX_PATH];
					if (GetItemWorldModel(weapon, szWorldModel, sizeof(szWorldModel)))
					{
						int newDroppedWeapon = CreateDroppedWeapon(vecPackOrigin, vecPackAngles, szWorldModel, GetEntityAddress(weapon) + FindItemOffset(weapon));
						if (IsValidEntity(newDroppedWeapon))
						{
							if (TF2Util_IsEntityWeapon(weapon))
							{
								SDKCall_CTFDroppedWeapon_InitDroppedWeapon(newDroppedWeapon, player, weapon, true);
							}
							else if (TF2Util_IsEntityWearable(weapon))
							{
								InitDroppedWearable(newDroppedWeapon, player, weapon, true);
							}
						}
					}
				}
				
				FRPlayer(player).RemoveItem(weapon);
			}
			
			int lastWeapon = GetEntPropEnt(player, Prop_Send, "m_hLastWeapon");
			SetEntProp(newItem, Prop_Send, "m_bValidatedAttachedEntity", true);
			FRPlayer(player).EquipItem(newItem);
			SetEntPropEnt(player, Prop_Send, "m_hLastWeapon", lastWeapon);
			
			if (TF2Util_IsEntityWeapon(newItem))
			{
				SDKCall_CTFDroppedWeapon_InitPickedUpWeapon(droppedWeapon, player, newItem);
				
				// can't use the weapon we just picked up?
				if (!SDKCall_CBaseCombatCharacter_Weapon_CanSwitchTo(player, newItem))
				{
					// try next best thing we can use
					SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(player, newItem);
				}
			}
			else if (TF2Util_IsEntityWearable(newItem))
			{
				// switch to the next best weapon
				if (GetEntPropEnt(player, Prop_Send, "m_hActiveWeapon") == -1)
				{
					SDKCall_CBaseCombatCharacter_SwitchToNextBestWeapon(player, -1);
				}
			}
			
			// delay pickup weapon message
			FRPlayer(player).m_flSendPickupWeaponMessageTime = GetGameTime() + 0.1;
			
			SDKCall_CTFPlayer_PostInventoryApplication(player);
			
			ret.Value = true;
			return MRES_Supercede;
		}
	}
	
	ret.Value = false;
	return MRES_Supercede;
}

static MRESReturn CTFPlayer_GetMaxAmmo_Post(int player, DHookReturn ret, DHookParam params)
{
	if (g_bInGiveAmmo)
	{
		// Allow extra ammo from packs
		ret.Value = RoundToNearest(float(ret.Value) * fr_max_ammo_boost.FloatValue);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn CBaseCombatCharacter_TakeHealth_Pre(int player, DHookReturn ret, DHookParam params)
{
	if (g_bInHealthKitTouch)
	{
		// The health kit will not call its post-hook, so we'll have to do this here
		g_bInHealthKitTouch = false;
		
		int bitsDamageType = params.Get(2);
		params.Set(2, bitsDamageType | DMG_IGNORE_MAXHEALTH);
		
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_GiveAmmo_Pre(int player, DHookReturn ret, DHookParam params)
{
	if (params.Get(4) == kAmmoSource_Pickup)
	{
		g_bInGiveAmmo = true;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_GiveAmmo_Post(int player, DHookReturn ret, DHookParam params)
{
	if (params.Get(4) == kAmmoSource_Pickup)
	{
		g_bInGiveAmmo = false;
	}
	
	return MRES_Ignored;
}

static MRESReturn CBasePlayer_ForceRespawn_Pre(int player)
{
	if (IsInWaitingForPlayers())
		return MRES_Ignored;
	
	// Never allow respawning unless we explicitly request it
	if (g_bAllowForceRespawn)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

static MRESReturn CTFFists_PrimaryAttack_Post(int fists)
{
	int owner = GetEntPropEnt(fists, Prop_Send, "m_hOwner");
	if (IsValidClient(owner))
	{
		SDKCall_CTFPlayer_RemoveDisguise(owner);
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFFists_SecondaryAttack_Post(int fists)
{
	int owner = GetEntPropEnt(fists, Prop_Send, "m_hOwner");
	if (IsValidClient(owner))
	{
		SDKCall_CTFPlayer_RemoveDisguise(owner);
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
{
	TFClassType nClass = TF2_GetPlayerClass(player);
	if (nClass == TFClass_Unknown)
		return MRES_Ignored;
	
	// Increase class maximum health
	int iMaxHealth = ret.Value;
	ret.Value = RoundToFloor(iMaxHealth * fr_health_multiplier[nClass].FloatValue);
	return MRES_Supercede;
}

static MRESReturn CTFPlayer_RegenThink_Pre(int player)
{
	// Disable passive health regen for Medic
	if (TF2_GetPlayerClass(player) == TFClass_Medic)
	{
		g_nPrevClass = TF2_GetPlayerClass(player);
		TF2_SetPlayerClass(player, TFClass_Unknown, false, false);
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_RegenThink_Post(int player)
{
	if (g_nPrevClass == TFClass_Medic)
	{
		TF2_SetPlayerClass(player, g_nPrevClass, false, false);
		g_nPrevClass = TFClass_Unknown;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_DoClassSpecialSkill_Pre(int player, DHookReturn ret)
{
	// Don't allow using class special skills with fists
	if (IsWeaponFists(GetEntPropEnt(player, Prop_Send, "m_hActiveWeapon")))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayerShared_CanRecieveMedigunChargeEffect_Pre(Address pShared, DHookReturn ret, DHookParam params)
{
	int client = TF2Util_GetPlayerFromSharedAddress(pShared);
	
	// Don't receive charge effects while being healed by a medigun
	int medigun = -1;
	while ((medigun = FindEntityByClassname(medigun, "tf_weapon_medigun")) != -1)
	{
		if (GetEntPropEnt(medigun, Prop_Send, "m_hOwner") == client)
			continue;
		
		if (GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget") == client)
		{
			ret.Value = false;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayerShared_Heal_Pre(Address pShared, DHookParam params)
{
	int client = TF2Util_GetPlayerFromSharedAddress(pShared);
	int healer = params.Get(1);
	
	// Only allow self-healing, so mediguns can damage players
	if (client != healer && IsValidClient(healer))
		return MRES_Supercede;
	
	return MRES_Ignored;
}
