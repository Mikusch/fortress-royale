void SDK_Init()
{
	GameData gamedata = new GameData("royale");
	if (gamedata == null)
		SetFailState("Could not find royale gamedata");
	
	DHook_CreateDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeam, _);
	DHook_CreateDetour(gamedata, "CObjectSentrygun::ValidTargetPlayer", DHook_ValidTargetPlayer, _);
	DHook_CreateDetour(gamedata, "CObjectDispenser::CouldHealTarget", DHook_CouldHealTarget, _);
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