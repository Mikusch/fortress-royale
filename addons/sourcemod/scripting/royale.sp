#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

#define TF_MAXPLAYERS	32

#define CONTENTS_REDTEAM	CONTENTS_TEAM1
#define CONTENTS_BLUETEAM	CONTENTS_TEAM2

#define MODEL_EMPTY			"models/empty.mdl"

#define CONFIG_MAXCHAR		64

// m_lifeState values
#define LIFE_ALIVE				0 // alive
#define LIFE_DYING				1 // playing death animation or still falling off of a ledge waiting to hit ground
#define LIFE_DEAD				2 // dead. lying still.
#define LIFE_RESPAWNABLE		3
#define LIFE_DISCARDBODY		4

// settings for m_takedamage
#define DAMAGE_NO				0
#define DAMAGE_EVENTS_ONLY		1		// Call damage functions, but don't modify health
#define DAMAGE_YES				2
#define DAMAGE_AIM				3

const TFTeam TFTeam_Alive = TFTeam_Red;
const TFTeam TFTeam_Dead = TFTeam_Blue;

//TF2 Mannpower Powerups
enum TFRuneType
{
	TFRune_Strength = 0, 
	TFRune_Haste, 
	TFRune_Regen, 
	TFRune_Defense, 
	TFRune_Vampire, 
	TFRune_Reflect, 
	TFRune_Precision, 
	TFRune_Agility, 
	TFRune_Knockout, 
	TFRune_King, 
	TFRune_Plague, 
	TFRune_Supernova
}

enum PlayerState
{
	PlayerState_Waiting,
	PlayerState_BattleBus,
	PlayerState_Alive,
	PlayerState_Dead
}

enum SolidType_t
{
	SOLID_NONE			= 0,	// no solid model
	SOLID_BSP			= 1,	// a BSP tree
	SOLID_BBOX			= 2,	// an AABB
	SOLID_OBB			= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM		= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
};

/**
 * Possible drops from loot crates
 */
enum LootType
{
	Loot_Weapon_Primary = (1<<0),	/**< Primary weapons */
	Loot_Weapon_Secondary = (1<<1),	/**< Secondary weapons */
	Loot_Weapon_Melee = (1<<2),		/**< Melee weapons */
	Loot_Weapon_Misc = (1<<3),		/**< Grappling Hook, PDA, etc. */
	Loot_Pickup_Health = (1<<4),	/**< Health pickups */
	Loot_Pickup_Ammo = (1<<5),		/**< Ammunition pickups */
	Loot_Pickup_Spell = (1<<6),		/**< Halloween spells */
	Loot_Powerup_Crits = (1<<7),	/**< Mannpower crit powerup */
	Loot_Powerup_Uber = (1<<8),		/**< Mannpower uber powerup */
	Loot_Powerup_Rune = (1<<9)		/**< Mannpower rune powerup */
}

/** Everything */
#define LOOT_ALL		view_as<LootType>(0xFFFFFFFF)
/** Any weapon */
#define LOOT_WEAPONS	Loot_Weapon_Primary|Loot_Weapon_Secondary|Loot_Weapon_Melee|Loot_Weapon_Misc
/** Health, ammo and spells */
#define LOOT_PICKUPS	Loot_Pickup_Health|Loot_Pickup_Ammo|Loot_Pickup_Spell
/** Mannpower powerups */
#define LOOT_POWERUPS	Loot_Powerup_Crits|Loot_Powerup_Uber|Loot_Powerup_Rune

enum struct LootCrateConfig
{
	char namePrefab[CONFIG_MAXCHAR];/**< Name of prefab if any */
	float origin[3];				/**< Spawn origin */
	float angles[3];				/**< Spawn angles */
	char model[PLATFORM_MAX_PATH];	/**< World model */
	int skin;						/**< Model skin */
	char sound[PLATFORM_MAX_PATH];	/**< Sound this crate emits when opening */
	int health;						/**< Amount of damage required to open */
	float chance;					/**< Chance for this crate to spawn at all */
	LootType contents;				/**< Content bitflags **/
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetVector("origin", this.origin, this.origin);
		kv.GetVector("angles", this.angles, this.angles);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		this.skin = kv.GetNum("skin", this.skin);
		kv.GetString("sound", this.sound, PLATFORM_MAX_PATH, this.sound);
		PrecacheSound(this.sound);
		this.health = kv.GetNum("health", this.health);
		this.chance = kv.GetFloat("chance", this.chance);
		
		char contents[PLATFORM_MAX_PATH];
		kv.GetString("contents", contents, sizeof(contents), "ALL");
		this.contents = Loot_StrToLootType(contents);
	}
	
	LootType GetRandomLootType()
	{
		ArrayList list = new ArrayList();
		for (int i = 1; i < view_as<int>(LootType); i*=2)
		{
			if (view_as<int>(this.contents) & i)
				list.Push(i);
		}
		int type = list.Get(GetRandomInt(0, list.Length - 1));
		delete list;
		return view_as<LootType>(type);
	}
}

char g_fistsClassname[][] = {
	"",						//Unknown
	"tf_weapon_bat",		//Scout
	"tf_weapon_club",		//Sniper
	"tf_weapon_shovel",		//Soldier
	"tf_weapon_bottle",		//Demoman
	"tf_weapon_bonesaw",	//Medic
	"tf_weapon_fists",		//Heavy
	"tf_weapon_fireaxe",	//Pyro
	"tf_weapon_knife",		//Spy
	"tf_weapon_robot_arm"	//Engineer
}

#define INDEX_FISTS		5

bool g_IsRoundActive;

#include "royale/player.sp"

#include "royale/battlebus.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convar.sp"
#include "royale/event.sp"
#include "royale/loot/loot.sp"
#include "royale/loot/loot_callbacks.sp"
#include "royale/sdk.sp"
#include "royale/stocks.sp"
#include "royale/zone.sp"

public void OnPluginStart()
{
	Config_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
	SDK_Init();
	Loot_Init();
	
	ConVar_Toggle(true);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	ConVar_Toggle(false);
}

public void OnMapStart()
{
	Config_Refresh();
	
	BattleBus_Precache();
	Zone_Precache();
	
	SDK_HookGamerules();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_ShouldCollide, Client_ShouldCollide);
	SDK_HookClient(client);
	
	FRPlayer(client).PlayerState = PlayerState_Waiting;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (FRPlayer(client).PlayerState == PlayerState_BattleBus)
	{
		if (buttons & IN_ATTACK3)
			BattleBus_EjectClient(client);
		else
			buttons = 0;	//Don't allow client in battle bus process any other buttons
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_pipe") || StrEqual(classname, "tf_projectile_cleaver"))
	{
		SDKHook(entity, SDKHook_Touch, Projectile_Touch);
		SDKHook(entity, SDKHook_TouchPost, Projectile_TouchPost);
	}
	else if (StrContains(classname, "tf_projectile_jar") == 0)
		SDK_HookProjectile(entity);
	else if (StrContains(classname, "tf_weapon_sniperrifle") == 0 || StrEqual(classname, "tf_weapon_knife"))
		SDK_HookPrimaryAttack(entity);
	else if (StrEqual(classname, "tf_weapon_flamethrower"))
		SDK_HookFlamethrower(entity);
	else if (StrEqual(classname, "tf_gas_manager"))
		SDK_HookGasManager(entity);
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

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Changed;
}
