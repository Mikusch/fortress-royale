/*
 * Copyright (C) 2020  Mikusch & 42
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

enum PostThink
{
	PostThink_None,
	PostThink_Spectator,
	PostThink_SpectatorAll,
	PostThink_EnemyTeam,
}

static char g_SpectatorClassnames[][] = {
	"tf_weapon_buff_item",				//CTFPlayerShared::PulseRageBuff
	"tf_weapon_flamethrower",			//CBaseCombatWeapon::SecondaryAttack
	"tf_weapon_rocketlauncher_fireball",//CBaseCombatWeapon::SecondaryAttack
	"tf_weapon_sniperrifle",			//CTFPlayer::FireBullet
	"tf_weapon_knife",					//CTFKnife::PrimaryAttack
	"tf_weapon_fists"					//CTFWeaponBaseMelee::DoMeleeDamage
};

static char g_EnemyTeamClassnames[][] = {
	"tf_weapon_handgun_scout_primary",	//CTFPistol_ScoutPrimary::Push
	"tf_weapon_bat",					//CTFWeaponBaseMelee::PrimaryAttack
	"tf_weapon_grapplinghook",			//CTFGrapplingHook::ActivateRune
};

static PostThink g_PostThink;
static bool g_PostThinkMelee;

void SDKHook_HookClient(int client)
{
	SDKHook(client, SDKHook_ShouldCollide, Entity_ShouldCollide);
	
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKHook(client, SDKHook_PreThink, Client_PreThink);
	SDKHook(client, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(client, SDKHook_PostThink, Client_PostThink);
	SDKHook(client, SDKHook_PostThinkPost, Client_PostThinkPost);
	SDKHook(client, SDKHook_Touch, Client_Touch);
	SDKHook(client, SDKHook_TouchPost, Client_TouchPost);
}

void SDKHook_UnhookClient(int client)
{
	SDKUnhook(client, SDKHook_ShouldCollide, Entity_ShouldCollide);
	
	SDKUnhook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKUnhook(client, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKUnhook(client, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(client, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKUnhook(client, SDKHook_PostThink, Client_PostThink);
	SDKUnhook(client, SDKHook_PostThinkPost, Client_PostThinkPost);
	SDKUnhook(client, SDKHook_Touch, Client_Touch);
	SDKUnhook(client, SDKHook_TouchPost, Client_TouchPost);
}

void SDKHook_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "obj_") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, Building_SpawnPost);
		SDKHook(entity, SDKHook_OnTakeDamage, Building_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, Building_OnTakeDamagePost);
	}
	
	if (StrEqual(classname, "item_powerup_rune"))
	{
		SDKHook(entity, SDKHook_Spawn, Rune_Spawn);
	}
	else if (StrEqual(classname, "item_teamflag"))
	{
		SDKHook(entity, SDKHook_StartTouch, CaptureFlag_StartTouch);
		SDKHook(entity, SDKHook_Touch, CaptureFlag_Touch);
	}
	else if (StrContains(classname, "prop_vehicle") == 0)
	{
		SDKHook(entity, SDKHook_Spawn, PropVehicle_Spawn);
		SDKHook(entity, SDKHook_SpawnPost, PropVehicle_SpawnPost);
	}
	else if (StrContains(classname, "prop_dynamic") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, PropDynamic_SpawnPost);
	}
	else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		SDKHook(entity, SDKHook_StartTouch, Dispenser_StartTouch);
		SDKHook(entity, SDKHook_StartTouchPost, Dispenser_StartTouchPost);
	}
	else if (StrEqual(classname, "tf_flame_manager"))
	{
		SDKHook(entity, SDKHook_Touch, FlameManager_Touch);
		SDKHook(entity, SDKHook_TouchPost, FlameManager_TouchPost);
	}
	else if (StrEqual(classname, "tf_gas_manager"))
	{
		SDKHook(entity, SDKHook_Touch, GasManager_Touch);
	}
	else if (StrEqual(classname, "tf_projectile_cleaver") || StrEqual(classname, "tf_projectile_pipe"))
	{
		SDKHook(entity, SDKHook_Touch, Projectile_Touch);
		SDKHook(entity, SDKHook_TouchPost, Projectile_TouchPost);
	}
	else if (StrEqual(classname, "tf_projectile_syringe"))
	{
		SDKHook(entity, SDKHook_ShouldCollide, Entity_ShouldCollide);
	}
	else if (StrEqual(classname, "tf_pumpkin_bomb"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, PumpkinBomb_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, PumpkinBomb_OnTakeDamagePost);
	}
	else if (StrEqual(classname, "tf_spell_meteorshowerspawner"))
	{
		SDKHook(entity, SDKHook_Spawn, MeteorShowerSpawner_Spawn);
	}
	else if (StrEqual(classname, "tf_spell_pickup"))
	{
		SDKHook(entity, SDKHook_TouchPost, SpellPickup_TouchPost);
	}
}

public bool Entity_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if (contentsmask & CONTENTS_REDTEAM || contentsmask & CONTENTS_BLUETEAM)
		return true;
	
	return originalResult;
}

public Action Client_SetTransmit(int entity, int client)
{
	//Don't allow alive players see invis spy
	
	if (entity == client || !IsPlayerAlive(client) || FRPlayer(client).VisibleCond > 0)
		return Plugin_Continue;
	
	if (TF2_GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	Action action = Plugin_Changed;
	
	if (damagecustom == 0 && weapon > MaxClients && HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
	{
		float multiplier = fr_fistsdamagemultiplier.FloatValue;
		if (multiplier != 1.0)
		{
			damage *= multiplier;
			action = Plugin_Changed;
		}
	}
	
	if (damagetype & DMG_VEHICLE)
	{
		char classname[256];
		GetEntityClassname(inflictor, classname, sizeof(classname));
		if (StrEqual("prop_vehicle_driveable", classname))
		{
			int driver = GetEntPropEnt(inflictor, Prop_Send, "m_hPlayer");
			if (0 < driver <= MaxClients && victim != driver)
			{
				attacker = driver;
				action = Plugin_Changed;
			}
		}
	}
	
	//attacker may be already in spec, change attacker team so we don't get both victim and attacker in spectator
	if (0 < attacker <= MaxClients && IsClientInGame(attacker))
		FRPlayer(attacker).ChangeToSpectator();
	else
		FRPlayer(victim).ChangeToSpectator();
	
	//Don't drop a beer bottle on death if the attacker wasn't a Demoman
	//Done in OnTakeDamage because a player_death event hook fires too late (after CTFPlayer::Event_Killed)
	if (0 < attacker <= MaxClients && IsClientInGame(attacker) && TF2_GetPlayerClass(attacker) != TFClass_DemoMan)
	{
		if (g_PlayerDestructionLogic != INVALID_ENT_REFERENCE)
		{
			SetVariantInt(0);
			AcceptEntityInput(g_PlayerDestructionLogic, "SetPointsOnPlayerDeath");
		}
	}
	
	return action;
}

public void Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (0 < attacker <= MaxClients && IsClientInGame(attacker))
		FRPlayer(attacker).ChangeToTeam();
	else
		FRPlayer(victim).ChangeToTeam();
	
	//Reset any potential changes from pre-hook
	if (g_PlayerDestructionLogic != INVALID_ENT_REFERENCE)
	{
		SetVariantInt(fr_bottle_points.IntValue);
		AcceptEntityInput(g_PlayerDestructionLogic, "SetPointsOnPlayerDeath");
	}
}

public void Client_PreThink(int client)
{
	//Dont allow buff banner give effects to teammates
	FRPlayer(client).ChangeToSpectator();
}

public void Client_PreThinkPost(int client)
{
	FRPlayer(client).ChangeToTeam();
}

public void Client_PostThink(int client)
{
	//For some reason IN_USE never gets assigned to m_afButtonPressed inside vehicles, preventing exiting, so let's add it ourselves
	if (GetEntPropEnt(client, Prop_Send, "m_hVehicle") && GetClientButtons(client) & IN_USE)
	{
		SetEntProp(client, Prop_Data, "m_afButtonPressed", GetEntProp(client, Prop_Data, "m_afButtonPressed") | IN_USE);
	}
	
	int medigun = TF2_GetItemByClassname(client, "tf_weapon_medigun");
	if (medigun > MaxClients)
	{
		//Set target to ourself so we can build uber passive, and mannpower enabled so uber rate reduced while carrying rune
		SetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget", client);
		GameRules_SetProp("m_bPowerupMode", true);
		SDKCall_FindAndHealTargets(medigun);
		GameRules_SetProp("m_bPowerupMode", false);
		SetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget", -1);
		
		//Passively build projectile shield
		if (TF2Attrib_GetByName(medigun, "generate rage on heal") != Address_Null && !GetEntProp(client, Prop_Send, "m_bRageDraining"))
		{
			float rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
			SetEntPropFloat(client, Prop_Send, "m_flRageMeter", fMin(100.0, rage + (GetGameFrameTime() / SDKCall_GetHealRate(medigun)) * 100.0));
		}
	}
	
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting))	// CTFPlayer::DoTauntAttack
	{
		//Allow taunt kill work on both teams, moving client to spectator wont work perfectly due to taunt kill stuns during truce
		g_PostThink = PostThink_EnemyTeam;
		TFTeam team = TF2_GetEnemyTeam(FRPlayer(client).Team);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && i != client)
				FRPlayer(i).SwapToTeam(team);
		}
		
		return;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon == -1)
		return;
	
	char classname[256];
	GetEntityClassname(weapon, classname, sizeof(classname));
	
	if (SDKCall_GetSlot(weapon) == WeaponSlot_Melee)	// CTFWeaponBaseMelee::Smack
	{
		g_PostThinkMelee = true;
		
		//Mannpower have increased melee damage, and even bigger for knockout powerup
		GameRules_SetProp("m_bPowerupMode", true);
		
		if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
		{
			//Dont allow repair and upgrade his building if using bare hands
			FRPlayer(client).ChangeBuildingsToSpectator();
			
			if (StrEqual(classname, "tf_weapon_robot_arm"))
			{
				//Dont allow triple combo punch from gunslinger hand
				static int offsetComboCount = -1;
				if (offsetComboCount == -1)
					offsetComboCount = FindSendPropInfo("CTFRobotArm", "m_hRobotArm") + 4;	// m_iComboCount
				
				SetEntData(weapon, offsetComboCount, 0);
			}
		}
	}
	
	//For functions that do simple "in same team" checks, move ourself to the spectator team
	for (int i = 0; i < sizeof(g_SpectatorClassnames); i++)
	{
		if (StrContains(classname, g_SpectatorClassnames[i]) == 0)
		{
			if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != INDEX_FISTS)
			{
				//Allow backstab work on both teams
				g_PostThink = PostThink_Spectator;
				FRPlayer(client).ChangeToSpectator();
			}
			else
			{
				//Don't allow backstabbing with fists, move everyone to same team
				g_PostThink = PostThink_SpectatorAll;
				for (int j = 1; j <= MaxClients; j++)
				{
					if (IsClientInGame(j))
						FRPlayer(j).ChangeToSpectator();
				}
			}
			
			return;
		}
	}
	
	//For functions that collect members of one team (RED/BLU), move everyone else to enemy team
	for (int i = 0; i < sizeof(g_EnemyTeamClassnames); i++)
	{
		if (StrContains(classname, g_EnemyTeamClassnames[i]) == 0)
		{
			g_PostThink = PostThink_EnemyTeam;
			
			for (int j = 1; j <= MaxClients; j++)
			{
				if (IsClientInGame(j) && j != client)
					FRPlayer(j).SwapToEnemyTeam();
			}
			
			return;
		}
	}
}

public void Client_PostThinkPost(int client)
{
	switch (g_PostThink)
	{
		case PostThink_Spectator:
		{
			FRPlayer(client).ChangeToTeam();
		}
		
		case PostThink_SpectatorAll:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
					FRPlayer(i).ChangeToTeam();
			}
		}
		
		case PostThink_EnemyTeam:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && i != client)
					FRPlayer(i).SwapToOriginalTeam();
			}
		}
	}
	
	g_PostThink = PostThink_None;
	
	if (g_PostThinkMelee)
	{
		g_PostThinkMelee = false;
		
		GameRules_SetProp("m_bPowerupMode", false);
		
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (weapon != -1 && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == INDEX_FISTS)
			FRPlayer(client).ChangeBuildingsToTeam();
	}
}

public Action Client_Touch(int client, int toucher)
{
	if (0 < toucher <= MaxClients)
	{
		FRPlayer(client).ChangeToSpectator();	//Has team check to start plague powerup
		SetEntProp(client, Prop_Send, "m_lifeState", LIFE_DEAD);	//Use alive player check to not plague ourself
	}
}

public void Client_TouchPost(int client, int toucher)
{
	if (0 < toucher <= MaxClients)
	{
		FRPlayer(client).ChangeToTeam();
		SetEntProp(client, Prop_Send, "m_lifeState", LIFE_ALIVE);
	}
}

public void Building_SpawnPost(int building)
{
	//Enable collision for both teams
	SetEntProp(building, Prop_Send, "m_CollisionGroup", TFCOLLISION_GROUP_OBJECT_SOLIDTOPLAYERMOVEMENT);
}

public Action Building_OnTakeDamage(int building, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//Several powerup change stuffs
	GameRules_SetProp("m_bPowerupMode", true);
	
	//Don't allow building take damage from owner
	if (0 < attacker <= MaxClients && attacker == GetEntPropEnt(building, Prop_Send, "m_hBuilder"))
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public void Building_OnTakeDamagePost(int building, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	GameRules_SetProp("m_bPowerupMode", false);
}

public Action Projectile_Touch(int entity, int other)
{
	//This function have team check, change projectile and owner to spectator to touch both teams
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner != other)
	{
		FRPlayer(owner).ChangeToSpectator();
		TF2_ChangeTeam(entity, TFTeam_Spectator);
	}
}

public void Projectile_TouchPost(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner != other)
	{
		FRPlayer(owner).ChangeToTeam();
		TF2_ChangeTeam(entity, FRPlayer(owner).Team);
	}
}

public Action PropVehicle_Spawn(int vehicle)
{
	Vehicles_Spawn(vehicle);
}

public Action PropVehicle_SpawnPost(int vehicle)
{
	Vehicles_SpawnPost(vehicle);
}

public void PropDynamic_SpawnPost(int prop)
{
	Loot_UpdateEntity(prop);
}

public Action Dispenser_StartTouch(int dispenser, int toucher)
{
	//Disallow players able to be healed from dispenser
	//TODO allow blu spy from enemy team to be healed
	if (0 < toucher <= MaxClients && !TF2_IsObjectFriendly(dispenser, toucher))
		FRPlayer(toucher).ChangeToSpectator();
}

public Action Dispenser_StartTouchPost(int dispenser, int toucher)
{
	if (0 < toucher <= MaxClients && !TF2_IsObjectFriendly(dispenser, toucher))
		FRPlayer(toucher).ChangeToTeam();
}

public Action FlameManager_Touch(int entity, int toucher)
{
	// This calls ShouldCollide with buildings team check
	int client = GetOwnerLoop(entity);
	if (0 < client <= MaxClients)
		FRPlayer(client).ChangeToSpectator();
}

public void FlameManager_TouchPost(int entity, int toucher)
{
	int client = GetOwnerLoop(entity);
	if (0 < client <= MaxClients)
		FRPlayer(client).ChangeToTeam();
}

public Action GasManager_Touch(int entity, int other)
{
	//Don't give gas effects to owner
	if (GetOwnerLoop(entity) == other)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action PumpkinBomb_OnTakeDamage(int pumpkin, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//Pumpkin use private m_iTeam instead of m_iTeamNum which fucking sucks, lets use m_nSkin instead
	TFTeam team;
	switch (GetEntProp(pumpkin, Prop_Send, "m_nSkin"))
	{
		case 1: team = TFTeam_Red;
		case 2: team = TFTeam_Blue;
		default: return;
	}
	
	//Make sure attacker is in same team as pumpkin bomb to explode
	if (0 < attacker <= MaxClients)
	{
		FRPlayer(attacker).ChangeToTeam();
		
		if (FRPlayer(attacker).Team != team)
			FRPlayer(attacker).SwapToEnemyTeam();
	}
}

public void PumpkinBomb_OnTakeDamagePost(int pumpkin, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	//If pumpkin did not explode and destroys itself, this callback wont be called, watch out
	
	TFTeam team;
	switch (GetEntProp(pumpkin, Prop_Send, "m_nSkin"))
	{
		case 1: team = TFTeam_Red;
		case 2: team = TFTeam_Blue;
		default: return;
	}
	
	if (0 < attacker <= MaxClients)
	{
		if (FRPlayer(attacker).Team != team)
			FRPlayer(attacker).SwapToOriginalTeam();
		
		FRPlayer(attacker).ChangeToSpectator();
	}
}

public Action Rune_Spawn(int rune)
{
	SetEntProp(rune, Prop_Send, "m_nSkin", 0);
	
	//Always set rune team to any
	SetEntData(rune, g_OffsetRuneTeam, view_as<int>(TFTeam_Any));
	
	//Never let rune despawn
	SetEntData(rune, g_OffsetRuneShouldReposition, false);
}

public Action CaptureFlag_StartTouch(int entity, int toucher)
{
	char model[PLATFORM_MAX_PATH];
	if (GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model)) > 0 && StrEqual(model, BOTTLE_PICKUP_MODEL))
	{
		if (0 < toucher <= MaxClients && TF2_GetPlayerClass(toucher) != TFClass_DemoMan && GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == -1)
			PrintCenterText(toucher, "%t", "Hint_BottlePickup_WrongClass");
	}
}

public Action CaptureFlag_Touch(int entity, int toucher)
{
	char model[PLATFORM_MAX_PATH];
	if (GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model)) > 0 && StrEqual(model, BOTTLE_PICKUP_MODEL))
	{
		if (0 < toucher <= MaxClients && TF2_GetPlayerClass(toucher) != TFClass_DemoMan)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action MeteorShowerSpawner_Spawn(int entity)
{
	//Set team back to owner team, otherwise TF2 will destroy itself
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	TF2_ChangeTeam(entity, FRPlayer(owner).Team);
}

public Action SpellPickup_TouchPost(int entity, int toucher)
{
	if (0 < toucher <= MaxClients)
	{
		//Skeleton spell requires a nav mesh which most maps do not have, reroll if it was picked
		int spellbook = TF2_GetItemByClassname(toucher, "tf_weapon_spellbook");
		if (spellbook != INVALID_ENT_REFERENCE)
		{
			int tier = GetEntProp(entity, Prop_Data, "m_nTier");
			if (tier == 1)
			{
				int nextSpell = GetEntData(spellbook, g_OffsetNextSpell);
				
				if (nextSpell == TFSpell_SkeletonHorde)
					SetEntData(spellbook, g_OffsetNextSpell, GetRandomInt(TFSpell_LightningBall, TFSpell_Meteor));
			}
		}
	}
}