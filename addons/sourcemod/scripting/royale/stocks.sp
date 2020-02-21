stock int GetOwnerLoop(int entity)
{
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner > 0 && owner != entity)
		return GetOwnerLoop(owner);
	else
		return entity;
	
	/*
	do
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (owner > 0 && owner != entity)
			entity = owner;
		else
			return entity;
	}
	while (entity > 0);	//Forever until returned
	
	return -1;
	*/
}

stock void TF2_SwapClientTeam(int client)
{
	switch (TF2_GetClientTeam(client))
	{
		case TFTeam_Red: SetEntProp(client, Prop_Send, "m_iTeamNum", view_as<int>(TFTeam_Blue));
		case TFTeam_Blue: SetEntProp(client, Prop_Send, "m_iTeamNum", view_as<int>(TFTeam_Red));
	}
}