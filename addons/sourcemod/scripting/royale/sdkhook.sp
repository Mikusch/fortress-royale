void SDKHook_HookClient(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_ShouldCollide, Client_ShouldCollide);
	SDKHook(client, SDKHook_GetMaxHealth, Client_GetMaxHealth);
	SDKHook(client, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKHook(client, SDKHook_PostThink, Client_PostThink);
	SDKHook(client, SDKHook_PostThinkPost, Client_PostThinkPost);
}

void SDKHook_HookBuilding(int building)
{
	SDKHook(building, SDKHook_OnTakeDamage, Building_OnTakeDamage);
}

void SDKHook_HookProjectile(int entity)
{
	SDKHook(entity, SDKHook_Touch, Projectile_Touch);
	SDKHook(entity, SDKHook_TouchPost, Projectile_TouchPost);
}

void SDKHook_HookGasManager(int entity)
{
	SDKHook(entity, SDKHook_Touch, GasManager_Touch);
}

void SDKHook_HookRune(int rune)
{
	SDKHook(rune, SDKHook_Spawn, Rune_Spawn);
}

public Action Client_SetTransmit(int entity, int client)
{
	//Don't allow teammates see invis spy
	
	if (entity == client
		 || !IsPlayerAlive(client)
		 || TF2_IsPlayerInCondition(entity, TFCond_Bleeding)
		 || TF2_IsPlayerInCondition(entity, TFCond_Jarated)
		 || TF2_IsPlayerInCondition(entity, TFCond_Milked)
		 || TF2_IsPlayerInCondition(entity, TFCond_OnFire)
		 || TF2_IsPlayerInCondition(entity, TFCond_Gas))
	{
		return Plugin_Continue;
	}
	
	if (TF2_GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public bool Client_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if (contentsmask & CONTENTS_REDTEAM || contentsmask & CONTENTS_BLUETEAM)
		return true;
	
	return originalResult;
}

public Action Client_GetMaxHealth(int client, int &maxhealth)
{
	float multiplier = fr_healthmultiplier.FloatValue;
	
	if (multiplier == 1.0)
		return Plugin_Continue;
	
	//Multiply health by convar value, and round up value by 5
	maxhealth = RoundToFloor(float(maxhealth) * multiplier / 5.0) * 5;
	return Plugin_Changed;
}

public Action Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//attacker may be already in spec, change attacker team so we don't get both victim and attacker in spectator
	if (0 < attacker <= MaxClients && IsClientInGame(attacker))
		FRPlayer(attacker).ChangeToSpectator();
	else
		FRPlayer(victim).ChangeToSpectator();
	
	if (weapon > MaxClients && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
	{
		float multiplier = fr_fistsdamagemultiplier.FloatValue;
		if (multiplier != 1.0)
		{
			damage *= multiplier;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (0 < attacker <= MaxClients && IsClientInGame(attacker))
		FRPlayer(attacker).ChangeToTeam();
	else
		FRPlayer(victim).ChangeToTeam();
}

public void Client_PostThink(int client)
{
	int weapon = TF2_GetItemInSlot(client, WeaponSlot_Secondary);
	if (weapon > MaxClients)
	{
		char classname[256];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, "tf_weapon_medigun"))
		{
			//Set target to ourself so we can build uber passive
			SetEntPropEnt(weapon, Prop_Send, "m_hHealingTarget", client);
			SDKCall_FindAndHealTargets(weapon);
			SetEntPropEnt(weapon, Prop_Send, "m_hHealingTarget", -1);
		}
	}
	
	//This function have millions of team checks, swap team to spec to allow both red and blu to take effect
	FRPlayer(client).ChangeToSpectator();
}

public void Client_PostThinkPost(int client)
{
	FRPlayer(client).ChangeToTeam();
}

public Action Building_OnTakeDamage(int building, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//Don't allow building take damage from owner
	if (0 < attacker <= MaxClients && attacker == GetEntPropEnt(building, Prop_Send, "m_hBuilder"))
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action Projectile_Touch(int entity, int other)
{
	//This function have team check, change projectile and owner to spectator to touch both teams
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner == other)
		return;
	
	TF2_ChangeTeam(entity, TFTeam_Spectator);
	TF2_ChangeTeam(owner, TFTeam_Spectator);
}

public void Projectile_TouchPost(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner == other)
		return;
	
	//Get original team by using it's weapon
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	if (weapon <= MaxClients)
		return;
	
	TF2_ChangeTeam(owner, TF2_GetTeam(weapon));
}

public Action GasManager_Touch(int entity, int other)
{
	//Don't give gas effects to owner
	if (GetOwnerLoop(entity) == other)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Rune_Spawn(int rune)
{
	//Always set rune team to any
	Address address = GetEntityAddress(rune) + view_as<Address>(g_OffsetRuneTeam);
	StoreToAddress(address, view_as<int>(TFTeam_Any), NumberType_Int8);
	
	SetEntProp(rune, Prop_Send, "m_nSkin", 0);
	
	//Never let rune despawn
	address = GetEntityAddress(rune) + view_as<Address>(g_OffsetRuneShouldReposition);
	StoreToAddress(address, false, NumberType_Int8);
}