static Handle g_DHookPrimaryAttack;
static Handle g_DHookDeflectPlayer;
static Handle g_DHookDeflectEntity;

static int g_PrimaryAttackClient;
static TFTeam g_PrimaryAttackTeam;

void SDK_Init()
{
	GameData gamedata = new GameData("royale");
	if (gamedata == null)
		SetFailState("Could not find royale gamedata");
	
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeam, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetPlayer", DHook_ValidTargetPlayer, _);
	DHook_CreateDetour(gamedata, "CObjectDispenser::CouldHealTarget", DHook_CouldHealTarget, _);
	
	g_DHookPrimaryAttack = DHook_CreateVirtual(gamedata, "CBaseCombatWeapon::PrimaryAttack");
	g_DHookDeflectPlayer = DHook_CreateVirtual(gamedata, "CTFWeaponBase::DeflectPlayer");
	g_DHookDeflectEntity = DHook_CreateVirtual(gamedata, "CTFWeaponBase::DeflectEntity");
	
	delete gamedata;
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
		LogError("Failed to create detour: %s", name);
	
	return hook;
}

void SDK_HookPrimaryAttack(int weapon)
{
	DHookEntity(g_DHookPrimaryAttack, false, weapon, _, DHook_PrimaryAttackPre);
	DHookEntity(g_DHookPrimaryAttack, true, weapon, _, DHook_PrimaryAttackPost);
}

void SDK_HookFlamethrower(int weapon)
{
	DHookEntity(g_DHookDeflectPlayer, false, weapon, _, DHook_DeflectPre);
	DHookEntity(g_DHookDeflectPlayer, true, weapon, _, DHook_DeflectPost);
	DHookEntity(g_DHookDeflectEntity, false, weapon, _, DHook_DeflectPre);
	DHookEntity(g_DHookDeflectEntity, true, weapon, _, DHook_DeflectPost);
}

public MRESReturn DHook_InSameTeam(int entity, Handle returnVal, Handle params)
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

public MRESReturn DHook_ValidTargetPlayer(int sentry, Handle hReturn, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (0 < target <= MaxClients && TF2_IsObjectFriendly(sentry, target))
	{
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CouldHealTarget(int dispenser, Handle hReturn, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	if (0 < target <= MaxClients)
	{
		DHookSetReturn(hReturn, TF2_IsObjectFriendly(dispenser, target));
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_PrimaryAttackPre(int weapon)
{
	//This weapon may not work for teammate, swap client team
	
	g_PrimaryAttackClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	g_PrimaryAttackTeam = TF2_GetClientTeam(g_PrimaryAttackClient);
	TF2_ChangeTeam(g_PrimaryAttackClient, TF2_GetEnemyTeam(g_PrimaryAttackClient));
}

public MRESReturn DHook_PrimaryAttackPost(int weapon)
{
	//DHook bug with Pre and Post giving incorrect 'weapon' entity for post,
	//Set team back to what it was
	
	TF2_ChangeTeam(g_PrimaryAttackClient, g_PrimaryAttackTeam);
}

public MRESReturn DHook_DeflectPre(int weapon, Handle params)
{
	//Allow airblast teamates, change attacker team to victim/entity's enemy team
	TF2_ChangeTeam(DHookGetParam(params, 2), TF2_GetEnemyTeam(DHookGetParam(params, 1)));
}

public MRESReturn DHook_DeflectPost(int weapon, Handle params)
{
	//Change attacker team back to what it was, using flamethrower weapon team
	TF2_ChangeTeam(DHookGetParam(params, 2), TF2_GetTeam(weapon));
}