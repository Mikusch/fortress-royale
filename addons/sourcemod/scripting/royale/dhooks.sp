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

enum struct DetourData
{
	char name[64];
	DynamicDetour detour;
	DHookCallback callback_pre;
	DHookCallback callback_post;
}

static ArrayList g_dynamicDetours;
static ArrayList g_dynamicHookIds;

static DynamicHook g_DHook_CTFPlayer_GiveNamedItem;
static DynamicHook g_DHook_CBaseCombatCharacter_TakeHealth;
static DynamicHook g_DHook_CBasePlayer_ForceRespawn;
static DynamicHook g_DHook_CBaseCombatWeapon_PrimaryAttack;
static DynamicHook g_DHook_CBaseCombatWeapon_SecondaryAttack;

static int g_iHookIdGiveNamedItem[MAXPLAYERS + 1];

static TFClassType g_nPrevClass;

void DHooks_Init(GameData gamedata)
{
	g_dynamicDetours = new ArrayList(sizeof(DetourData));
	g_dynamicHookIds = new ArrayList();
	
	g_DHook_CTFPlayer_GiveNamedItem = DHooks_AddDynamicHook(gamedata, "CTFPlayer::GiveNamedItem");
	g_DHook_CBaseCombatCharacter_TakeHealth = DHooks_AddDynamicHook(gamedata, "CBaseCombatCharacter::TakeHealth");
	g_DHook_CBasePlayer_ForceRespawn = DHooks_AddDynamicHook(gamedata, "CBasePlayer::ForceRespawn");
	g_DHook_CBaseCombatWeapon_PrimaryAttack = DHooks_AddDynamicHook(gamedata, "CBaseCombatWeapon::PrimaryAttack");
	g_DHook_CBaseCombatWeapon_SecondaryAttack = DHooks_AddDynamicHook(gamedata, "CBaseCombatWeapon::SecondaryAttack");
	
	DHooks_AddDynamicDetour(gamedata, "CTFDroppedWeapon::Create", DHookCallback_CTFDroppedWeapon_Create_Pre);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", DHookCallback_CTFPlayer_PickupWeaponFromOther_Pre);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::CanPickupDroppedWeapon", DHookCallback_CTFPlayer_CanPickupDroppedWeapon_Pre);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::GetMaxAmmo", _, DHookCallback_CTFPlayer_GetMaxAmmo_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::GiveAmmo", DHookCallback_CTFPlayer_GiveAmmo_Pre, DHookCallback_CTFPlayer_GiveAmmo_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::GetMaxHealthForBuffing", _, DHookCallback_CTFPlayer_GetMaxHealthForBuffing_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::RegenThink", DHookCallback_CTFPlayer_RegenThink_Pre, DHookCallback_CTFPlayer_RegenThink_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::DoClassSpecialSkill", DHookCallback_CTFPlayer_DoClassSpecialSkill_Pre);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::CanRecieveMedigunChargeEffect", DHookCallback_CTFPlayerShared_CanRecieveMedigunChargeEffect_Pre);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::Heal", DHookCallback_CTFPlayerShared_Heal_Pre);
}

void DHooks_Toggle(bool enable)
{
	for (int i = 0; i < g_dynamicDetours.Length; i++)
	{
		DetourData data;
		if (g_dynamicDetours.GetArray(i, data))
		{
			DHooks_ToggleDetour(data, enable);
		}
	}
	
	if (!enable)
	{
		// Remove virtual hooks
		for (int i = g_dynamicHookIds.Length - 1; i >= 0; i--)
		{
			int hookid = g_dynamicHookIds.Get(i);
			DynamicHook.RemoveHook(hookid);
		}
		
		for (int client = 1; client <= MaxClients; client++)
		{
			DHooks_UnhookGiveNamedItem(client);
		}
	}
}

void DHooks_HookEntity(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		DHooks_HookGiveNamedItem(entity);
		DHooks_HookEntityInternal(g_DHook_CBaseCombatCharacter_TakeHealth, Hook_Pre, entity, DHookCallback_CBaseCombatCharacter_TakeHealth_Pre);
		DHooks_HookEntityInternal(g_DHook_CBasePlayer_ForceRespawn, Hook_Pre, entity, DHookCallback_CBasePlayer_ForceRespawn_Pre);
	}
	else if (StrEqual(classname, "tf_weapon_fists"))
	{
		DHooks_HookEntityInternal(g_DHook_CBaseCombatWeapon_PrimaryAttack, Hook_Post, entity, DHookCallback_CTFFists_PrimaryAttack_Post);
		DHooks_HookEntityInternal(g_DHook_CBaseCombatWeapon_SecondaryAttack, Hook_Post, entity, DHookCallback_CTFFists_SecondaryAttack_Post);
	}
}

void DHooks_HookGiveNamedItem(int client)
{
	if (!g_bTF2Items)
		g_iHookIdGiveNamedItem[client] = g_DHook_CTFPlayer_GiveNamedItem.HookEntity(Hook_Pre, client, DHookCallback_CTFPlayer_GiveNamedItem_Pre, DHookRemovalCB_OnHookRemoved);
}

void DHooks_UnhookGiveNamedItem(int client)
{
	if (g_iHookIdGiveNamedItem[client])
	{
		if (DynamicHook.RemoveHook(g_iHookIdGiveNamedItem[client]))
		{
			g_iHookIdGiveNamedItem[client] = 0;
		}
	}
}

static void DHooks_AddDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		DetourData data;
		strcopy(data.name, sizeof(data.name), name);
		data.detour = detour;
		data.callback_pre = callbackPre;
		data.callback_post = callbackPost;
		
		g_dynamicDetours.PushArray(data);
	}
	else
	{
		LogError("Failed to create detour setup handle: %s", name);
	}
}

static DynamicHook DHooks_AddDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

static void DHooks_HookEntityInternal(DynamicHook hook, HookMode mode, int entity, DHookCallback callback)
{
	if (!hook)
		return;
	
	int hookid = hook.HookEntity(mode, entity, callback, DHookRemovalCB_OnHookRemoved);
	if (hookid != INVALID_HOOK_ID)
		g_dynamicHookIds.Push(hookid);
}

static void DHooks_ToggleDetour(DetourData data, bool enable)
{
	if (data.callback_pre != INVALID_FUNCTION)
	{
		if (enable)
			data.detour.Enable(Hook_Pre, data.callback_pre);
		else
			data.detour.Disable(Hook_Pre, data.callback_pre);
	}
	
	if (data.callback_post != INVALID_FUNCTION)
	{
		if (enable)
			data.detour.Enable(Hook_Post, data.callback_post);
		else
			data.detour.Disable(Hook_Post, data.callback_post);
	}
}

static void DHookRemovalCB_OnHookRemoved(int hookid)
{
	int index = g_dynamicHookIds.FindValue(hookid);
	if (index != -1)
		g_dynamicHookIds.Erase(index);
}

static MRESReturn DHookCallback_CTFDroppedWeapon_Create_Pre(DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CTFPlayer_PickupWeaponFromOther_Pre(int player, DHookReturn ret, DHookParam params)
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
				SDKCall_CBaseCombatWeapon_SetSubType(newItem, TFObject_Sapper);
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

static MRESReturn DHookCallback_CTFPlayer_CanPickupDroppedWeapon_Pre(int player, DHookReturn ret, DHookParam params)
{
	int weapon = params.Get(1);
	
	if (!GetEntProp(weapon, Prop_Send, "m_bInitialized"))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	TFClassType nClass = TF2_GetPlayerClass(player);
	if (nClass == TFClass_Spy && (TF2_IsPlayerInCondition(player, TFCond_Disguised) || GetPercentInvisible(player) > 0.0))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (TF2_IsPlayerInCondition(player, TFCond_Taunting))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (!IsPlayerAlive(player))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	if (GetEntPropEnt(player, Prop_Send, "m_hActiveWeapon") == -1)
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	ret.Value = CanWeaponBeUsedByClass(weapon, nClass);
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CTFPlayer_GetMaxAmmo_Post(int player, DHookReturn ret, DHookParam params)
{
	if (g_bInGiveAmmo)
	{
		// Allow extra ammo from packs
		ret.Value = RoundToNearest(float(ret.Value) * sm_fr_max_ammo_boost.FloatValue);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_GiveNamedItem_Pre(int player, DHookReturn ret, DHookParam params)
{
	// If szName is NULL, don't generate an item
	if (params.IsNull(1))
	{
		ret.Value = -1;
		return MRES_Supercede;
	}
	
	// If pScriptItem is NULL, let it through
	if (params.IsNull(3))
	{
		return MRES_Ignored;
	}
	
	char szName[64];
	params.GetString(1, szName, sizeof(szName));
	
	// CEconItemView::m_iItemDefinitionIndex
	int iItemDefIndex = params.GetObjectVar(3, 0x4, ObjectValueType_Int) & 0xFFFF;
	
	if (FR_OnGiveNamedItem(player, szName, iItemDefIndex) >= Plugin_Handled)
	{
		ret.Value = -1;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseCombatCharacter_TakeHealth_Pre(int player, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CTFPlayer_GiveAmmo_Pre(int player, DHookReturn ret, DHookParam params)
{
	if (params.Get(4) == kAmmoSource_Pickup)
	{
		g_bInGiveAmmo = true;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_GiveAmmo_Post(int player, DHookReturn ret, DHookParam params)
{
	if (params.Get(4) == kAmmoSource_Pickup)
	{
		g_bInGiveAmmo = false;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBasePlayer_ForceRespawn_Pre(int player)
{
	if (IsInWaitingForPlayers())
		return MRES_Ignored;
	
	// Never allow respawning unless we explicitly request it
	if (g_bAllowForceRespawn)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CTFFists_PrimaryAttack_Post(int fists)
{
	int owner = GetEntPropEnt(fists, Prop_Send, "m_hOwner");
	if (IsValidClient(owner))
	{
		SDKCall_CTFPlayer_RemoveDisguise(owner);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFFists_SecondaryAttack_Post(int fists)
{
	int owner = GetEntPropEnt(fists, Prop_Send, "m_hOwner");
	if (IsValidClient(owner))
	{
		SDKCall_CTFPlayer_RemoveDisguise(owner);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
{
	TFClassType nClass = TF2_GetPlayerClass(player);
	if (nClass == TFClass_Unknown)
		return MRES_Ignored;
	
	// Increase class maximum health
	int iMaxHealth = ret.Value;
	ret.Value = RoundToFloor(iMaxHealth * sm_fr_health_multiplier[nClass].FloatValue);
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CTFPlayer_RegenThink_Pre(int player)
{
	// Disable passive health regen for Medic
	if (TF2_GetPlayerClass(player) == TFClass_Medic)
	{
		g_nPrevClass = TF2_GetPlayerClass(player);
		TF2_SetPlayerClass(player, TFClass_Unknown, false, false);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_RegenThink_Post(int player)
{
	if (g_nPrevClass == TFClass_Medic)
	{
		TF2_SetPlayerClass(player, g_nPrevClass, false, false);
		g_nPrevClass = TFClass_Unknown;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_DoClassSpecialSkill_Pre(int player, DHookReturn ret)
{
	// Don't allow using class special skills with fists
	if (IsWeaponFists(GetEntPropEnt(player, Prop_Send, "m_hActiveWeapon")))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_CanRecieveMedigunChargeEffect_Pre(Address pShared, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CTFPlayerShared_Heal_Pre(Address pShared, DHookParam params)
{
	int client = TF2Util_GetPlayerFromSharedAddress(pShared);
	int healer = params.Get(1);
	
	// Only allow self-healing, so mediguns can damage players
	if (client != healer && IsValidClient(healer))
		return MRES_Supercede;
	
	return MRES_Ignored;
}
