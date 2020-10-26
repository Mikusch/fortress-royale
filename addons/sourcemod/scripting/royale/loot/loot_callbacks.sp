public void LootCallback_CreateWeapon(int client, CallbackParams params, const float origin[3])
{
	int defindex = params.GetInt("defindex");
	
	//Make sure client is in correct team for weapon to have correct skin from CTFWeaponBase::GetSkin
	FRPlayer(client).ChangeToTeam();
	
	int weapon = -1;
	
	//Find possible reskin to use
	for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		int slot = TF2Econ_GetItemLoadoutSlot(defindex, class);
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
		
		DispatchSpawn(spell);
		DropSingleInstance(spell, client, view_as<float>( { 0.0, 0.0, 350.0 } ));
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
		
		GameRules_SetProp("m_bPowerupMode", true);
		DispatchSpawn(entity);
		GameRules_SetProp("m_bPowerupMode", false);
		
		DropSingleInstance(entity, client, view_as<float>( { 0.0, 0.0, 350.0 } ));
	}
}

public bool LootCallback_ShouldCreateAmmoPack(int client, CallbackParams params)
{
	if (client <= 0 || client > MaxClients)
		return false;
	
	//Check if client is low on metal
	int maxMetal = SDKCall_GetMaxAmmo(client, view_as<int>(TF_AMMO_METAL));
	int metal = GetEntProp(client, Prop_Data, "m_iAmmo", _, view_as<int>(TF_AMMO_METAL));
	
	if (float(metal) / float(maxMetal) <= 0.8)
		return true;
	
	//Check if any weapon in loadout is low on ammo
	for (int slot = TFWeaponSlot_Primary; slot <= WeaponSlot_Melee; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon != -1)
		{
			int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
			if (ammoType != -1)
			{
				int maxAmmo = SDKCall_GetMaxAmmo(client, ammoType);
				int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
				
				//Ignore charge meters
				if (maxAmmo != 1 && float(ammo) / float(maxAmmo) <= 0.8)
					return true;
			}
		}
	}
	
	return false;
}

public bool LootCallback_ShouldCreateHealthKit(int client, CallbackParams params)
{
	if (client <= 0 || client > MaxClients)
		return false;
	
	return float(GetEntProp(client, Prop_Send, "m_iHealth")) / float(TF2_GetMaxHealth(client)) <= 0.795;
}

public bool LootCallback_ShouldCreateRune(int client, CallbackParams params)
{
	if (client <= 0 || client > MaxClients)
		return false;
	
	//Only spawn Supernova if player has a Grappling Hook
	if (params && view_as<TFRuneType>(params.GetInt("type")) == TFRune_Supernova)
		return TF2_GetItemByClassname(client, "tf_weapon_grapplinghook") != -1;
	
	return true;
}
