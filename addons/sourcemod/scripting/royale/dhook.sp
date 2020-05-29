static Handle g_DHookForceRespawn;
static Handle g_DHookGiveNamedItem;
static Handle g_DHookSetWinningTeam;
static Handle g_DHookPrimaryAttack;
static Handle g_DHookFireProjectile;
static Handle g_DHookSmack;
static Handle g_DHookExplode;
static Handle g_DHookTossJarThink;
static Handle g_DHookWantsLagCompensationOnEntity;

static int g_HookIdGiveNamedItem[TF_MAXPLAYERS + 1];

void DHook_Init(GameData gamedata)
{
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeamPre, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::FindTarget", DHook_FindTargetPre, DHook_FindTargetPost);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetPlayer", DHook_ValidTargetPre, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetObject", DHook_ValidTargetPre, _);
	DHook_CreateDetour(gamedata, "CObjectDispenser::CouldHealTarget", DHook_CouldHealTargetPre, _);
	DHook_CreateDetour(gamedata, "CTFPlayer::CanPickupDroppedWeapon", DHook_CanPickupDroppedWeaponPre, _);
	DHook_CreateDetour(gamedata, "CTFPlayer::DropAmmoPack", DHook_DropAmmoPackPre, _);
	DHook_CreateDetour(gamedata, "CTFPlayer::SaveMe", DHook_SaveMePre, _);
	DHook_CreateDetour(gamedata, "CTFPlayerShared::SetChargeEffect", DHook_SetChargeEffectPre, _);
	DHook_CreateDetour(gamedata, "CTFPlayerShared::PulseRageBuff", DHook_PulseRageBuffPre, DHook_PulseRageBuffPost);
	DHook_CreateDetour(gamedata, "CEyeballBoss::FindClosestVisibleVictim", DHook_FindClosestVisibleVictimPre, DHook_FindClosestVisibleVictimPost);
	
	g_DHookSetWinningTeam = DHook_CreateVirtual(gamedata, "CTFGameRules::SetWinningTeam");
	g_DHookForceRespawn = DHook_CreateVirtual(gamedata, "CTFPlayer::ForceRespawn");
	g_DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	g_DHookPrimaryAttack = DHook_CreateVirtual(gamedata, "CBaseCombatWeapon::PrimaryAttack");
	g_DHookFireProjectile = DHook_CreateVirtual(gamedata, "CTFWeaponBaseGun::FireProjectile");
	g_DHookSmack = DHook_CreateVirtual(gamedata, "CTFWeaponBaseMelee::Smack");
	g_DHookExplode = DHook_CreateVirtual(gamedata, "CBaseGrenade::Explode");
	g_DHookTossJarThink = DHook_CreateVirtual(gamedata, "CTFJar::TossJarThink");
	g_DHookWantsLagCompensationOnEntity = DHook_CreateVirtual(gamedata, "CTFPlayer::WantsLagCompensationOnEntity");
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
	Handle detour = DHookCreateFromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (preCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, false, preCallback))
				LogError("Failed to enable pre detour: %s", name);
		
		if (postCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, true, postCallback))
				LogError("Failed to enable post detour: %s", name);
		
		delete detour;
	}
}

static Handle DHook_CreateVirtual(GameData gamedata, const char[] name)
{
	Handle hook = DHookCreateFromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create virtual: %s", name);
	
	return hook;
}

void DHook_HookGiveNamedItem(int client)
{
	if (g_DHookGiveNamedItem && !g_TF2Items)
		g_HookIdGiveNamedItem[client] = DHookEntity(g_DHookGiveNamedItem, false, client, DHook_GiveNamedItemRemoved, DHook_GiveNamedItemPre);
}

void DHook_UnhookGiveNamedItem(int client)
{
	if (g_HookIdGiveNamedItem[client])
	{
		DHookRemoveHookID(g_HookIdGiveNamedItem[client]);
		g_HookIdGiveNamedItem[client] = 0;
	}
}

bool DHook_IsGiveNamedItemActive()
{
	for (int client = 1; client <= MaxClients; client++)
		if (g_HookIdGiveNamedItem[client])
			return true;
	
	return false;
}

void DHook_HookGamerules()
{
	DHookGamerules(g_DHookSetWinningTeam, false, _, DHook_SetWinningTeam);
}

void DHook_HookClient(int client)
{
	DHookEntity(g_DHookForceRespawn, false, client, _, DHook_ForceRespawnPre);
	DHookEntity(g_DHookWantsLagCompensationOnEntity, false, client, _, DHook_WantsLagCompensationOnEntityPre);
	DHookEntity(g_DHookWantsLagCompensationOnEntity, true, client, _, DHook_WantsLagCompensationOnEntityPost);
}

void DHook_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "tf_projectile_jar") == 0 || StrContains(classname, "tf_projectile_spell") == 0)
	{
		DHookEntity(g_DHookExplode, false, entity, _, DHook_ExplodePre);
		DHookEntity(g_DHookExplode, true, entity, _, DHook_ExplodePost);
	}
	else if (StrEqual(classname, "tf_weapon_spellbook"))
	{
		DHookEntity(g_DHookTossJarThink, false, entity, _, DHook_TossJarThinkPre);
		DHookEntity(g_DHookTossJarThink, true, entity, _, DHook_TossJarThinkPost);
	}
	else if (StrEqual(classname, "tf_weapon_pipebomblauncher"))
	{
		DHookEntity(g_DHookFireProjectile, true, entity, _, DHook_FireProjectilePost);
	}
	else if (StrEqual(classname, "tf_weapon_knife"))
	{
		DHookEntity(g_DHookPrimaryAttack, false, entity, _, DHook_PrimaryAttackPre);
		DHookEntity(g_DHookPrimaryAttack, true, entity, _, DHook_PrimaryAttackPost);
	}
	else if (StrEqual(classname, "tf_weapon_wrench") || StrEqual(classname, "tf_weapon_robot_arm"))
	{
		DHookEntity(g_DHookSmack, false, entity, _, DHook_SmackPre);
		DHookEntity(g_DHookSmack, true, entity, _, DHook_SmackPost);
	}
}

public MRESReturn DHook_InSameTeamPre(int entity, Handle returnVal, Handle params)
{
	//In friendly fire we only want to return true if both entity owner is the same
	
	if (DHookIsNullParam(params, 1))
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	int other = DHookGetParam(params, 1);
	
	entity = GetOwnerLoop(entity);
	other = GetOwnerLoop(other);
	
	DHookSetReturn(returnVal, entity == other);
	return MRES_Supercede;
}

public MRESReturn DHook_FindTargetPre(int sentry, Handle returnVal)
{
	//Sentry can only target one team, target enemy team
	int client = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
	if (client <= 0)
		return;
	
	TF2_ChangeTeam(sentry, TF2_GetEnemyTeam(client));
}

public MRESReturn DHook_FindTargetPost(int sentry, Handle returnVal)
{
	int client = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
	if (client <= 0)
		return;
	
	TF2_ChangeTeam(sentry, TF2_GetTeam(client));
}

public MRESReturn DHook_ValidTargetPre(int sentry, Handle returnVal, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (TF2_IsObjectFriendly(sentry, target))
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CouldHealTargetPre(int dispenser, Handle returnVal, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (0 < target <= MaxClients)
	{
		DHookSetReturn(returnVal, TF2_IsObjectFriendly(dispenser, target));
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CanPickupDroppedWeaponPre(int client, Handle returnVal, Handle params)
{
	if (FRPlayer(client).PlayerState != PlayerState_Alive || TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	int droppedWeapon = DHookGetParam(params, 1);
	int defindex = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType class = TF2_GetPlayerClass(client);
	int slot = TF2_GetItemSlot(defindex, class);
	
	if (slot < 0)
	{
		DHookSetReturn(returnVal, false);
		return MRES_Supercede;
	}
	
	//Check if client already has weapon in given slot, remove and create dropped weapon if so
	int weapon = TF2_GetItemInSlot(client, slot);
	if (weapon > MaxClients)
	{
		if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != INDEX_FISTS)
		{
			float origin[3], angles[3];
			GetClientEyePosition(client, origin);
			GetClientEyeAngles(client, angles);
			TF2_CreateDroppedWeapon(client, weapon, true, origin, angles);
		}
		
		TF2_RemoveItemInSlot(client, slot);
	}
	
	//Create new weapon
	int itemOffset = FindSendPropInfo("CTFDroppedWeapon", "m_Item");
	weapon = TF2_GiveNamedItem(client, GetEntityAddress(droppedWeapon) + view_as<Address>(itemOffset));
	if (weapon > MaxClients)
	{
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
	}
	
	//Fix active weapon, incase was switched to wearable
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") <= MaxClients)
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", TF2_GetItemInSlot(client, WeaponSlot_Melee));
	
	//Remove dropped weapon
	RemoveEntity(droppedWeapon);
	
	FRPlayer(client).LastWeaponPickupTime = GetGameTime();
	
	//Prevent TF2 doing any extra work, we done that
	DHookSetReturn(returnVal, false);
	return MRES_Supercede;
}

public MRESReturn DHook_DropAmmoPackPre(int client, Handle params)
{
	//Ignore feign death
	if (DHookGetParam(params, 2))
		return MRES_Supercede;
	
	float origin[3], angles[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	
	//Drop all weapons
	//TODO drop grapple hook aswell
	for (int slot = WeaponSlot_Primary; slot < WeaponSlot_BuilderEngie; slot++)
	{
		int weapon = TF2_GetItemInSlot(client, slot);
		if (weapon > MaxClients && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != INDEX_FISTS)
			TF2_CreateDroppedWeapon(client, weapon, false, origin, angles);
	}
	
	//Prevent TF2 dropping anything else
	return MRES_Supercede;
}

public MRESReturn DHook_SaveMePre(int client, Handle params)
{
	//Prevent showing medic bubble over this player's head
	return MRES_Supercede;
}

public MRESReturn DHook_SetChargeEffectPre(Address playershared, Handle params)
{
	//If pProvider is null, medic is switching weapon and losing effect, allow medic keep effect
	if (DHookIsNullParam(params, 6))
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_PulseRageBuffPre(Address playershared, Handle params)
{
	int client = GetClientFromPlayerShared(playershared);
	if (!client)
		return;
	
	//Change team so client can't give boosts to teammate
	FRPlayer(client).ChangeToSpectator();
}

public MRESReturn DHook_PulseRageBuffPost(Address playershared, Handle params)
{
	int client = GetClientFromPlayerShared(playershared);
	if (!client)
		return;
	
	FRPlayer(client).ChangeToTeam();
}

public MRESReturn DHook_FindClosestVisibleVictimPre(int eyeball, Handle params)
{
	int owner = GetEntPropEnt(eyeball, Prop_Send, "m_hOwnerEntity");
	if (0 < owner <= MaxClients && IsClientInGame(owner))
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(eyeball, TFTeam_Spectator);
	}
}

public MRESReturn DHook_FindClosestVisibleVictimPost(int eyeball, Handle params)
{
	int owner = GetEntPropEnt(eyeball, Prop_Send, "m_hOwnerEntity");
	if (0 < owner <= MaxClients && IsClientInGame(owner))
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(eyeball, TF2_GetTeam(owner));
	}
}

public MRESReturn DHook_SetWinningTeam(Handle params)
{
	//Prevent round win if atleast 2 players alive
	if (GetAlivePlayersCount() >= 2)
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_ForceRespawnPre(int client)
{
	if (FRPlayer(client).PlayerState == PlayerState_Parachute)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

public MRESReturn DHook_GiveNamedItemPre(int client, Handle returnVal, Handle params)
{
	if (DHookIsNullParam(params, 1) || DHookIsNullParam(params, 3))
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	char classname[256];
	DHookGetParamString(params, 1, classname, sizeof(classname));
	int index = DHookGetParamObjectPtrVar(params, 3, g_OffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	if (TF2_OnGiveNamedItem(client, classname, index) >= Plugin_Handled)
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public void DHook_GiveNamedItemRemoved(int hookid)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_HookIdGiveNamedItem[iClient] == hookid)
		{
			g_HookIdGiveNamedItem[iClient] = 0;
			return;
		}
	}
}

public MRESReturn DHook_PrimaryAttackPre(int weapon)
{
	//Client is in spectator, prevent backstab if using fists
	if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
		FRPlayer(GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity")).ChangeToTeam();
}

public MRESReturn DHook_PrimaryAttackPost(int weapon)
{
	//Client is in spectator, prevent backstab if using fists
	if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
		FRPlayer(GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity")).ChangeToSpectator();
}

public MRESReturn DHook_FireProjectilePost(int weapon, Handle returnVal, Handle params)
{
	//Client may be in spectator team during this hook, change projectile team to correct team
	int client = DHookGetParam(params, 1);
	int projectile = DHookGetReturn(returnVal);
	TF2_ChangeTeam(projectile, FRPlayer(client).Team);
	
	//Set owner entity so breaking loots with projectil works
	SetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity", weapon);
}

public MRESReturn DHook_SmackPre(int weapon)
{
	//Client is in spectator during this hook, allow repair and upgrade his building if not using bare hands
	if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
		return;
	
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (0 < client <= MaxClients && IsClientInGame(client))
		FRPlayer(client).ChangeBuildingsToSpectator();
}

public MRESReturn DHook_SmackPost(int weapon)
{
	if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
		return;
	
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (0 < client <= MaxClients && IsClientInGame(client))
		FRPlayer(client).ChangeBuildingsToTeam();
}

public MRESReturn DHook_ExplodePre(int entity, Handle params)
{
	//Change both projectile and owner to spectator, so effect applies to both red and blu, but not owner itself
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (0 < owner <= MaxClients && IsClientInGame(owner))
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(entity, TFTeam_Spectator);
	}
}

public MRESReturn DHook_ExplodePost(int entity, Handle params)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (0 < owner <= MaxClients && IsClientInGame(owner))
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(entity, FRPlayer(owner).Team);
	}
}

public MRESReturn DHook_TossJarThinkPre(int entity, Handle params)
{
	//Allow self-spell only take effects to themself
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (0 < owner <= MaxClients && IsClientInGame(owner))
		FRPlayer(owner).ChangeToSpectator();
}

public MRESReturn DHook_TossJarThinkPost(int entity, Handle params)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (0 < owner <= MaxClients && IsClientInGame(owner))
		FRPlayer(owner).ChangeToTeam();
}

public MRESReturn DHook_WantsLagCompensationOnEntityPre(int client, Handle returnVal)
{
	FRPlayer(client).ChangeToSpectator();
}

public MRESReturn DHook_WantsLagCompensationOnEntityPost(int client, Handle returnVal)
{
	FRPlayer(client).ChangeToTeam();
}
