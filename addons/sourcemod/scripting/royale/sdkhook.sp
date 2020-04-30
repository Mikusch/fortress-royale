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

public Action Client_SetTransmit(int entity, int client)
{
	//Don't allow teammates see invis spy
	
	if (entity == client
		 || TF2_GetClientTeam(client) <= TFTeam_Spectator
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

public Action Client_OnTakeDamagePost(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	FRPlayer(victim).ChangeToTeam();
}

public void Client_PostThink(int client)
{
	int weapon = TF2_GetItemInSlot(client, WeaponSlot_Secondary);
	if (weapon > MaxClients)
	{
		char classname[256];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, "tf_weapon_medigun") && !GetEntProp(weapon, Prop_Send, "m_bChargeRelease"))
		{
			float charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel") + (GetGameFrameTime() / 10.0);
			if (charge > 1.0)
				charge = 1.0;
			
			SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", charge);
		}
	}
	
	//Calls CTFPlayer::DoTauntAttack and holiday punch tickle with enemy team check
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