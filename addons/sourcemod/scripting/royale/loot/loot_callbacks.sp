public void LootCallback_CreateWeapon(int client, CallbackParams params, const float origin[3])
{
	int defindex = params.GetInt("defindex");
	
	//Make sure client is in correct team for weapon to have correct skin from CTFWeaponBase::GetSkin
	FRPlayer(client).ChangeToTeam();
	
	int weapon = -1;
	
	//Find possible reskin to use
	for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		int slot = TF2Econ_GetItemSlot(defindex, class);
		if (slot < WeaponSlot_Primary)
			continue;
		
		Address item = SDKCall_GetLoadoutItem(client, class, slot);
		if (!item)
			continue;
	
		int reskin = LoadFromAddress(item + view_as<Address>(g_OffsetItemDefinitionIndex), NumberType_Int16);
		if (reskin == defindex)
		{
			weapon = TF2_GiveNamedItem(client, item);
			break;
		}
		
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
		
		if (weapon != -1)
			break;
	}
	
	//Can't find reskin, create default weapon
	if (weapon == -1)
	{
		weapon = TF2_CreateWeapon(defindex);
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
		
		int droppedWeapon = TF2_CreateDroppedWeapon(client, weapon, false, origin);
		if (droppedWeapon == INVALID_ENT_REFERENCE)
			LogError("Unable to create dropped weapon for def index '%d'", defindex);
		
		if (!TF2_IsWearable(weapon))
			TF2_SetWeaponAmmo(client, weapon, ammo);	//Set client ammo back to what it was
		
		TeleportEntity(droppedWeapon, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 0.0 }) );
		RemoveEntity(weapon);
	}
	
	FRPlayer(client).ChangeToSpectator();
}

public bool LootCallback_ClassWeapon(CallbackParams params, TFClassType class)
{
	int defindex;
	if (!params.GetIntEx("defindex", defindex))
	{
		LogError("Weapon defindex not specified");
		return false;
	}
	
	return TF2_GetItemSlot(defindex, class) >= WeaponSlot_Primary;
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

public void LootCallback_CreateSpell(int client, CallbackParams params, const float origin[3])
{
	int spell = CreateEntityByName("tf_spell_pickup");
	if (spell > MaxClients)
	{
		SetEntProp(spell, Prop_Data, "m_nTier", params.GetInt("tier"));
		TeleportEntity(spell, origin, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(spell, "OnPlayerTouch", "!self,Kill,,0,-1");
		DispatchSpawn(spell);
	}
}

public void LootCallback_CreateRune(int client, CallbackParams params, const float origin[3])
{
	int type;
	if (params && params.GetIntEx("type", type))
		TF2_CreateRune(view_as<TFRuneType>(type), origin);
	else
		TF2_CreateRune(view_as<TFRuneType>(GetRandomInt(0, view_as<int>(TFRuneType))), origin);
}

public void LootCallback_CreateEntity(int client, CallbackParams params, const float origin[3])
{
	char classname[256];
	params.GetString("classname", classname, sizeof(classname));
	int entity = CreateEntityByName(classname);
	if (entity > MaxClients)
	{
		TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
		
		GameRules_SetProp("m_bPowerupMode", true);
		DispatchSpawn(entity);
		GameRules_SetProp("m_bPowerupMode", false);
	}
}

public bool LootCallback_ShouldCreateHealthKit(int client, CallbackParams params)
{
	return GetEntProp(client, Prop_Send, "m_iHealth") / TF2_GetMaxHealth(client) <= 0.795;
}
