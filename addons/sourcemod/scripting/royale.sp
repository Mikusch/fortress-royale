#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#define TF_MAXPLAYERS	32

#define CONTENTS_REDTEAM	CONTENTS_TEAM1
#define CONTENTS_BLUETEAM	CONTENTS_TEAM2

#define MODEL_EMPTY			"models/empty.mdl"

#define CONFIG_MAXCHAR		256

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

#define INDEX_FISTS			5
#define INDEX_SPELLBOOK		1070	// Spellbook Magazine
#define INDEX_BASEJUMPER	1101

const TFTeam TFTeam_Any = view_as<TFTeam>(-2);
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

enum eEurekaTeleportTargets
{
	EUREKA_FIRST_TARGET = 0,

	EUREKA_TELEPORT_HOME = 0,
	EUREKA_TELEPORT_TELEPORTER_EXIT,

	EUREKA_LAST_TARGET = EUREKA_TELEPORT_TELEPORTER_EXIT,
		
	EUREKA_NUM_TARGETS
}

enum PlayerState
{
	PlayerState_Waiting,	/**< Client is in spectator or waiting for new game */
	PlayerState_BattleBus,	/**< Client is in Battle Bus */
	PlayerState_Parachute,	/**< Client is alive and dropping with parachute */
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

enum
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP,

	TF_COLLISIONGROUP_GRENADES = LAST_SHARED_COLLISION_GROUP,
	TFCOLLISION_GROUP_OBJECT,
	TFCOLLISION_GROUP_OBJECT_SOLIDTOPLAYERMOVEMENT,
	TFCOLLISION_GROUP_COMBATOBJECT,
	TFCOLLISION_GROUP_ROCKETS,		// Solid to players, but not player movement. ensures touch calls are originating from rocket
	TFCOLLISION_GROUP_RESPAWNROOMS,
	TFCOLLISION_GROUP_TANK,
	TFCOLLISION_GROUP_ROCKET_BUT_NOT_WITH_OTHER_ROCKETS,
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
		return view_as<LootCrateContents>(new ArrayList(2));
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
					this.PushContent(types.Get(i), chance);
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

enum struct LootTable
{
	LootType type;
	Function callback_create;
	Function callback_class;
	Function callback_precache;
	CallbackParams callbackParams;
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
};

bool g_TF2Items;

StringMap g_PrecacheWeapon;	//List of custom models precached by defindex

ConVar fr_healthmultiplier;
ConVar fr_fistsdamagemultiplier;
ConVar fr_sectodeployparachute;

ConVar fr_zone_startdisplay;
ConVar fr_zone_display;
ConVar fr_zone_shrink;
ConVar fr_zone_nextdisplay;

int g_OffsetItemDefinitionIndex;
int g_OffsetRuneType;
int g_OffsetRuneTeam;
int g_OffsetRuneShouldReposition;
int g_SizeofEconItemView;

#include "royale/entity.sp"
#include "royale/player.sp"

#include "royale/battlebus.sp"
#include "royale/command.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convar.sp"
#include "royale/dhook.sp"
#include "royale/editor.sp"
#include "royale/event.sp"
#include "royale/loot/loot.sp"
#include "royale/loot/loot_callbacks.sp"
#include "royale/loot/loot_table.sp"
#include "royale/sdkcall.sp"
#include "royale/sdkhook.sp"
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
	
	g_TF2Items = LibraryExists("TF2Items");
	
	g_PrecacheWeapon = new StringMap();
	
	GameData gamedata = new GameData("royale");
	if (gamedata == null)
		SetFailState("Could not find royale gamedata");
	
	DHook_Init(gamedata);
	SDKCall_Init(gamedata);
	
	g_OffsetItemDefinitionIndex = gamedata.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	g_OffsetRuneType = gamedata.GetOffset("CTFRune::m_nRuneType");
	g_OffsetRuneTeam = gamedata.GetOffset("CTFRune::m_nTeam");
	g_OffsetRuneShouldReposition = gamedata.GetOffset("CTFRune::m_bShouldReposition");
	g_SizeofEconItemView = gamedata.GetOffset("sizeof(CEconItemView)");
	
	delete gamedata;
	
	Command_Init();
	Config_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
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
	
	DHook_HookGamerules();
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_TF2Items = true;
		
		//We cant allow TF2Items load while GiveNamedItem already hooked due to crash
		if (DHook_IsGiveNamedItemActive())
			SetFailState("Do not load TF2Items midgame while Royale is already loaded!");
	}
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_TF2Items = false;
		
		//TF2Items unloaded with GiveNamedItem unhooked, we can now safely hook GiveNamedItem ourself
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				DHook_HookGiveNamedItem(iClient);
	}
}


public void OnClientPutInServer(int client)
{
	DHook_HookClient(client);
	DHook_HookGiveNamedItem(client);
	SDKHook_HookClient(client);
	
	FRPlayer(client).PlayerState = PlayerState_Waiting;
	FRPlayer(client).EditorState = EditorState_None;
}

public void OnClientDisconnect(int iClient)
{
	DHook_UnhookGiveNamedItem(iClient);
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
	else if ((buttons & IN_ATTACK || buttons & IN_ATTACK2) && FRPlayer(client).LastWeaponPickupTime < GetGameTime() - 1.0)
	{
		SDKCall_TryToPickupDroppedWeapon(client);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHook_OnEntityCreated(entity, classname);
	SDKHook_OnEntityCreated(entity, classname);
	
	if (StrContains(classname, "obj_") == 0)
		HookSingleEntityOutput(entity, "OnDestroyed", EntityOutput_OnDestroyed, true);
}

public void EntityOutput_OnDestroyed(const char[] output, int caller, int activator, float delay)
{
	FREntity(EntIndexToEntRef(caller)).Destroy();
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	//Dont give uber on spawn from mannpower
	if (condition == TFCond_UberchargedCanteen && FRPlayer(client).PlayerState == PlayerState_Parachute)
		TF2_RemoveCondition(client, TFCond_UberchargedCanteen);
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Parachute && FRPlayer(client).PlayerState == PlayerState_Parachute)
	{
		//Remove starting parachute as it no longer needed, and set state to alive
		TF2_RemoveItemInSlot(client, WeaponSlot_Secondary);
		FRPlayer(client).PlayerState = PlayerState_Alive;
	}
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Changed;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int index, Handle &item)
{
	if (CanKeepWeapon(classname, index))
		return Plugin_Continue;
	
	return Plugin_Handled;
}