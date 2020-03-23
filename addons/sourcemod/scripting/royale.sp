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

#define INDEX_FISTS		5

const TFTeam TFTeam_Alive = TFTeam_Red;
const TFTeam TFTeam_Dead = TFTeam_Blue;

enum
{
	WeaponSlot_Primary = 0,
	WeaponSlot_Secondary,
	WeaponSlot_Melee,
	WeaponSlot_PDABuild,
	WeaponSlot_PDADisguise = 3,
	WeaponSlot_PDADestroy,
	WeaponSlot_InvisWatch = 4,
	WeaponSlot_BuilderEngie,
	WeaponSlot_Unknown1,
	WeaponSlot_Head,
	WeaponSlot_Misc1,
	WeaponSlot_Action,
	WeaponSlot_Misc2
};

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
	PlayerState_Waiting,	/**< Client is in spectator or waiting for new game */
	PlayerState_BattleBus,	/**< Client is in Battle Bus */
	PlayerState_Alive,		/**< Client is alive in map */
	PlayerState_Dead		/**< Client is dead and spectating */
}

enum EditorState
{
	EditorState_None,		/**< Client is not using editor */
	EditorState_View,		/**< Client is viewing props */
	EditorState_Placing		/**< Client is creating or moving a crate */
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

// entity effects
enum
{
	EF_BONEMERGE			= 0x001,	// Performs bone merge on client side
	EF_BRIGHTLIGHT 			= 0x002,	// DLIGHT centered at entity origin
	EF_DIMLIGHT 			= 0x004,	// player flashlight
	EF_NOINTERP				= 0x008,	// don't interpolate the next frame
	EF_NOSHADOW				= 0x010,	// Don't cast no shadow
	EF_NODRAW				= 0x020,	// don't draw entity
	EF_NORECEIVESHADOW		= 0x040,	// Don't receive no shadow
	EF_BONEMERGE_FASTCULL	= 0x080,	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
	EF_ITEM_BLINK			= 0x100,	// blink an item so that the user notices it.
	EF_PARENT_ANIMATES		= 0x200,	// always assume that the parent entity is animating
	EF_MAX_BITS = 10
};

/**
 * Possible drops from loot crates
 */
enum LootType
{
	Loot_Weapon_Primary = 0,	/**< Primary weapons */
	Loot_Weapon_Secondary,		/**< Secondary weapons */
	Loot_Weapon_Melee,			/**< Melee weapons */
	Loot_Weapon_PDA,			/**< PDA weapons */
	Loot_Weapon_Misc,			/**< Grappling Hook, etc. */
	Loot_Pickup_Health,			/**< Health pickups */
	Loot_Pickup_Ammo,			/**< Ammunition pickups */
	Loot_Pickup_Spell,			/**< Halloween spells */
	Loot_Powerup_Crits,			/**< Mannpower crit powerup */
	Loot_Powerup_Uber,			/**< Mannpower uber powerup */
	Loot_Powerup_Rune			/**< Mannpower rune powerup */
}

methodmap LootCrateContents < ArrayList
{
	public LootCrateContents()
	{
		return view_as<LootCrateContents>(new ArrayList(2))
	}
	
	public void PushContent(LootType loot, float chance)
	{
		int length = this.Length;
		this.Resize(length + 1);
		this.Set(length, loot, 0);
		this.Set(length, chance, 1);
	}
	
	public void GetContent(int index, LootType &loot, float &chance)
	{
		loot = this.Get(index, 0);
		chance = this.Get(index, 1);
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char type[PLATFORM_MAX_PATH];
				kv.GetString("type", type, sizeof(type));
				
				ArrayList types = Loot_StrToLootTypes(type);
				float chance = kv.GetFloat("chance");
				
				for (int i = 0; i < types.Length; i++)
				{
					this.PushContent(types.Get(i), chance)
				}
				
				delete types;
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
}

enum struct LootCrateConfig
{
	bool load;						/**< Whenever if this enum struct is loaded */
	char namePrefab[CONFIG_MAXCHAR];/**< Name of prefab if any */
	
	// LootCrates
	float origin[3];				/**< Spawn origin */
	float angles[3];				/**< Spawn angles */
	
	// LootPrefabs/LootDefault
	char model[PLATFORM_MAX_PATH];	/**< World model */
	int skin;						/**< Model skin */
	char sound[PLATFORM_MAX_PATH];	/**< Sound this crate emits when opening */
	int health;						/**< Amount of damage required to open */
	float chance;					/**< Chance for this crate to spawn at all */
	LootCrateContents contents;		/**< ArrayList of content bitflags (block 0) and chance (block 1) **/
	
	void ReadConfig(KeyValues kv)
	{
		this.load = true;
		
		kv.GetVector("origin", this.origin, this.origin);
		kv.GetVector("angles", this.angles, this.angles);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, this.model);
		PrecacheModel(this.model);
		this.skin = kv.GetNum("skin", this.skin);
		kv.GetString("sound", this.sound, PLATFORM_MAX_PATH, this.sound);
		PrecacheSound(this.sound);
		this.health = kv.GetNum("health", this.health);
		this.chance = kv.GetFloat("chance", this.chance);
		
		if (kv.JumpToKey("contents", false))
		{
			LootCrateContents contents = new LootCrateContents();
			contents.ReadConfig(kv);
			this.contents = contents;
			kv.GoBack();
		}
	}
	
	void SetConfig(KeyValues kv)
	{
		kv.SetString("prefab", this.namePrefab);
		kv.SetVector("origin", this.origin);
		kv.SetVector("angles", this.angles);
	}
	
	LootType GetRandomLootType()
	{
		LootType loot;
		float percentage;
		
		this.contents.Sort(Sort_Random, Sort_Integer);
		
		for (int i = 0; i < this.contents.Length; i++)
		{
			this.contents.GetContent(i, loot, percentage);
			
			if (GetRandomFloat() <= percentage)
				return loot;
		}
		
		return this.GetRandomLootType();
	}
}

methodmap CallbackParams < StringMap
{
	public CallbackParams()
	{
		return view_as<CallbackParams>(new StringMap());
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char key[CONFIG_MAXCHAR], value[CONFIG_MAXCHAR];
				kv.GetString("key", key, sizeof(key));
				kv.GetString("value", value, sizeof(value));
				this.SetString(key, value);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public bool GetBool(const char[] key, bool defValue = false)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return view_as<bool>(StringToInt(value));
	}
	
	public int GetInt(const char[] key, int defValue = 0)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToInt(value);
	}
	
	public bool GetIntEx(const char[] key, int &defValue)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return false;
		
		defValue = StringToInt(value);
		return true;
	}
	
	public float GetFloat(const char[] key, float defValue = 0.0)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToFloat(value);
	}
	
	public bool GetFloatEx(const char[] key, float &defValue)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return false;
		
		defValue = StringToFloat(value);
		return true;
	}
}

enum struct LootConfig
{
	LootType type;
	Function callback_create;
	Function callback_filter;
	Function callback_precache;
	CallbackParams callbackParams;
}

methodmap LootTable < ArrayList
{
	public LootTable()
	{
		return view_as<LootTable>(new ArrayList(sizeof(LootConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootConfig lootConfig;
				char type[CONFIG_MAXCHAR];
				kv.GetString("type", type, sizeof(type));
				lootConfig.type = Loot_StrToLootType(type);
				
				char callback[CONFIG_MAXCHAR];
				kv.GetString("callback_create", callback, sizeof(callback), NULL_STRING);
				lootConfig.callback_create = GetFunctionByName(null, callback);
				if (lootConfig.callback_create == INVALID_FUNCTION)
				{
					LogError("Unable to find create function '%s' from type '%s'", callback, type);
					continue;
				}
				
				kv.GetString("callback_filter", callback, sizeof(callback), NULL_STRING);
				if (callback[0] == '\0')
				{
					lootConfig.callback_filter = INVALID_FUNCTION;
				}
				else
				{
					lootConfig.callback_filter = GetFunctionByName(null, callback);
					if (lootConfig.callback_filter == INVALID_FUNCTION)
					{
						LogError("Unable to find filter function '%s' from type '%s'", callback, type);
						continue;
					}
				}
				
				kv.GetString("callback_precache", callback, sizeof(callback), NULL_STRING);
				if (callback[0] == '\0')
				{
					lootConfig.callback_precache = INVALID_FUNCTION;
				}
				else
				{
					lootConfig.callback_precache = GetFunctionByName(null, callback);
					if (lootConfig.callback_precache == INVALID_FUNCTION)
					{
						LogError("Unable to find precache function '%s' from type '%s'", callback, type);
						continue;
					}
				}
				
				if (kv.JumpToKey("params", false))
				{
					lootConfig.callbackParams = new CallbackParams();
					lootConfig.callbackParams.ReadConfig(kv);
				}
				
				this.PushArray(lootConfig);
				
				if (lootConfig.callback_precache != INVALID_FUNCTION)
				{
					Call_StartFunction(null, lootConfig.callback_precache);
					Call_PushCell(lootConfig.callbackParams);
					Call_Finish();
				}
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public int GetRandomLoot(LootConfig buffer, LootType type, int client = 0)
	{
		//Put all loot that matches the specified type into a new list
		ArrayList list = new ArrayList(sizeof(LootConfig));
		for (int i = 0; i < this.Length; i++)
		{
			if (type == this.Get(i, 0))
			{
				LootConfig lootConfig;
				this.GetArray(i, lootConfig, sizeof(lootConfig));
				
				if (lootConfig.callback_filter == INVALID_FUNCTION)
				{
					//Assume all weapons can be used
					list.PushArray(lootConfig);
				}
				else
				{
					Call_StartFunction(null, lootConfig.callback_filter);
					Call_PushCell(client);
					Call_PushCell(lootConfig.callbackParams);
					Call_PushCell(type);
					
					bool result;
					if (Call_Finish(result) == SP_ERROR_NONE && result)
						list.PushArray(lootConfig);			
				}
			}	
		}
		
		int length = list.Length;
		if (length <= 0)
		{
			delete list;
			return -1;
		}
		
		int copied = list.GetArray(GetRandomInt(0, length - 1), buffer, sizeof(buffer));
		delete list;
		return copied;
	}
}

LootTable g_LootTable;

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

bool g_IsRoundActive;

StringMap g_PrecacheWeapon;	//List of custom models precached by defindex

ConVar fr_healthmultiplier;
ConVar fr_fistsdamagemultiplier;

ConVar fr_zone_startdisplay;
ConVar fr_zone_display;
ConVar fr_zone_shrink;
ConVar fr_zone_nextdisplay;

#include "royale/player.sp"

#include "royale/battlebus.sp"
#include "royale/command.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convar.sp"
#include "royale/editor.sp"
#include "royale/event.sp"
#include "royale/loot/loot.sp"
#include "royale/loot/loot_callbacks.sp"
#include "royale/sdk.sp"
#include "royale/stocks.sp"
#include "royale/zone.sp"

public Plugin myinfo = 
{
	name = "Fortress Royale", 
	author = "Mikusch, 42", 
	description = "Team Fortress 2 Battle Royale", 
	version = "0.1", 
	url = "https://github.com/Mikusch/fortress-royale"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("royale.phrases");
	
	g_PrecacheWeapon = new StringMap();
	
	Command_Init();
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
	SDKHook(client, SDKHook_GetMaxHealth, Client_GetMaxHealth);
	SDKHook(client, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKHook(client, SDKHook_PostThink, Client_PostThink);
	
	SDK_HookClient(client);
	
	FRPlayer(client).PlayerState = PlayerState_Waiting;
	FRPlayer(client).EditorState = EditorState_None;
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
	else if (StrEqual(classname, "tf_ammo_pack"))
		RemoveEntity(entity);
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
	FRPlayer(victim).Team = TF2_GetTeam(victim);
	if (0 < attacker <= MaxClients)
	{
		TF2_ChangeTeam(victim, TF2_GetEnemyTeam(attacker));
	}
	
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
	TF2_ChangeTeam(victim, FRPlayer(victim).Team);
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
