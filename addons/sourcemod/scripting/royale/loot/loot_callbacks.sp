public int LootCallback_CreateWeapon(CallbackParams params)
{
	PrintToServer("CreateWeapon defindex %d", params.GetInt("defindex"));
}

public int LootCallback_CreateSpell(CallbackParams params)
{
	int spell = CreateEntityByName("tf_spell_pickup");
	if (spell > MaxClients)
	{
		SetEntProp(spell, Prop_Data, "m_nTier", params.GetInt("tier"));
		DispatchSpawn(spell)
		return spell;
	}
	return -1;
}

public int LootCallback_CreateRune(CallbackParams params)
{
	int type;
	if (params && params.GetValue("type", type))
		return TF2_CreateRune(view_as<TFRuneType>(type));
	else
		return TF2_CreateRune(view_as<TFRuneType>(GetRandomInt(0, view_as<int>(TFRuneType))));
}

public int LootCallback_CreateEntity(CallbackParams params)
{
	char classname[256];
	params.GetString("classname", classname, sizeof(classname));
	int entity = CreateEntityByName(classname);
	if (entity > MaxClients)
	{
		DispatchSpawn(entity)
		return entity;
	}
	return -1;
}
