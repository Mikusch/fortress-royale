public int LootCallback_CreateWeapon(int client, CallbackParams params)
{
	TFClassType class = TF2_GetPlayerClass(client);
	int defindex = params.GetInt("defindex");
	int slot = TF2Econ_GetItemSlot(defindex, class);
	if (slot < WeaponSlot_Primary)
	{
		LogError("Unable to get slot for def index '%d' and class '%d'", defindex, class);
		return -1;
	}
	
	//Make sure client is in correct team for weapon to have correct skin from CTFWeaponBase::GetSkin
	FRPlayer(client).ChangeToTeam();
	
	int weapon = -1;
	int droppedWeapon = -1;
	
	//Find possible reskin to use
	Address item = SDKCall_GetLoadoutItem(client, class, slot);
	if (item)
	{
		int reskin = LoadFromAddress(item + view_as<Address>(g_OffsetItemDefinitionIndex), NumberType_Int16);
		if (reskin == defindex)
		{
			weapon = TF2_GiveNamedItem(client, item);
		}
		else
		{
			char buffer[256];
			if (params.GetString("reskins", buffer, sizeof(buffer)))
			{
				int defindexbuffer;
				char indexbuffer[32][12];
				int count = ExplodeString(buffer, " ", indexbuffer, sizeof(indexbuffer), sizeof(indexbuffer[]));
				for (int i = 0; i < count; i++)
				{
					if (StringToIntEx(indexbuffer[i], defindexbuffer) && reskin == defindexbuffer)
					{
						weapon = TF2_GiveNamedItem(client, item);
						break;
					}
				}
			}
		}
	}
	
	//Can't find reskin, create default weapon
	if (weapon == -1)
	{
		weapon = TF2_CreateWeapon(defindex, class);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	}
	
	if (weapon > MaxClients)
	{
		int ammo = -1;
		if (!TF2_IsWearable(weapon))
		{
			SetEntPropEnt(weapon, Prop_Send, "m_hOwner", client);
			
			ammo = TF2_GetWeaponAmmo(client, weapon);
			TF2_SetWeaponAmmo(client, weapon, -1);	//Max ammo will be calculated later, need to be equipped from client
		}
		
		droppedWeapon = TF2_CreateDroppedWeapon(client, weapon, false);
		if (droppedWeapon == INVALID_ENT_REFERENCE)
			LogError("Unable to create dropped weapon for def index '%d'", defindex);
		
		if (!TF2_IsWearable(weapon))
			TF2_SetWeaponAmmo(client, weapon, ammo);	//Set client ammo back to what it was
		
		RemoveEntity(weapon);
	}
	
	FRPlayer(client).ChangeToSpectator();
	
	return droppedWeapon;
}

public bool LootCallback_ClassWeapon(CallbackParams params, LootType type, TFClassType class)
{
	int defindex;
	if (!params.GetIntEx("defindex", defindex))
	{
		LogError("Weapon defindex not specified");
		return false;
	}
	
	int slot = TF2_GetItemSlot(defindex, class);
	switch (type)
	{
		case Loot_Weapon_Primary: return slot == WeaponSlot_Primary;
		case Loot_Weapon_Secondary: return slot == WeaponSlot_Secondary;
		case Loot_Weapon_Melee: return slot == WeaponSlot_Melee;
		case Loot_Weapon_PDA: return WeaponSlot_Melee < slot < WeaponSlot_BuilderEngie;
		case Loot_Weapon_Misc: return slot >= WeaponSlot_BuilderEngie;
	}
	
	LogError("Invalid type '%d' passed", type);
	return false;
}

public void LootCallback_PrecacheWeapon(CallbackParams params)
{
	char defindex[12];
	if (!params.GetString("defindex", defindex, sizeof(defindex)))
	{
		LogError("Weapon defindex not specified");
		return;
	}
	
	char model[PLATFORM_MAX_PATH];
	if (!params.GetString("model", model, sizeof(model)))
	{
		LogError("Weapon model not specified");
		return;
	}
	
	PrecacheModel(model);
	g_PrecacheWeapon.SetString(defindex, model);
}

public int LootCallback_CreateSpell(int client, CallbackParams params)
{
	int spell = CreateEntityByName("tf_spell_pickup");
	if (spell > MaxClients)
	{
		SetEntProp(spell, Prop_Data, "m_nTier", params.GetInt("tier"));
		DispatchSpawn(spell);
		return spell;
	}
	return -1;
}

public int LootCallback_CreateRune(int client, CallbackParams params)
{
	int type;
	if (params && params.GetIntEx("type", type))
		return TF2_CreateRune(view_as<TFRuneType>(type));
	else
		return TF2_CreateRune(view_as<TFRuneType>(GetRandomInt(0, view_as<int>(TFRuneType))));
}

public int LootCallback_CreateEntity(int client, CallbackParams params)
{
	char classname[256];
	params.GetString("classname", classname, sizeof(classname));
	int entity = CreateEntityByName(classname);
	if (entity > MaxClients)
	{
		DispatchSpawn(entity);
		return entity;
	}
	return -1;
}
