void SDK_Init()
{
	GameData gamedata = new GameData("royale");
	if (gamedata == null)
		SetFailState("Could not find royale gamedata");
	
	Handle detour = DHookCreateFromConf(gamedata, "CBaseEntity::InSameTeam");
	if (detour == null)
		LogMessage("Failed to create hook: CBaseEntity::InSameTeam");
	else
		DHookEnableDetour(detour, false, DHook_InSameTeam);
	
	delete detour;
}

public MRESReturn DHook_InSameTeam(int entity, Handle returnVal, Handle params)
{
	//In friendly fire we only want to return true if both entity has same owner
	
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