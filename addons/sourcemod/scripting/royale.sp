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

#define TICK_NEVER_THINK		-1.0

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

#define TF_WEAPON_PICKUP_RANGE	150.0

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

enum FRRoundState
{
	FRRoundState_Waiting,
	FRRoundState_Setup,
	FRRoundState_Active,
	FRRoundState_End,
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

enum EditorItem
{
	EditorItem_None,
	EditorItem_Crate,
	EditorItem_Vehicle
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

// entity flags, CBaseEntity::m_iEFlags
enum
{
	EFL_KILLME	=				(1<<0),	// This entity is marked for death -- This allows the game to actually delete ents at a safe time
	EFL_DORMANT	=				(1<<1),	// Entity is dormant, no updates to client
	EFL_NOCLIP_ACTIVE =			(1<<2),	// Lets us know when the noclip command is active.
	EFL_SETTING_UP_BONES =		(1<<3),	// Set while a model is setting up its bones.
	EFL_KEEP_ON_RECREATE_ENTITIES = (1<<4), // This is a special entity that should not be deleted when we restart entities only

	EFL_HAS_PLAYER_CHILD=		(1<<4),	// One of the child entities is a player.

	EFL_DIRTY_SHADOWUPDATE =	(1<<5),	// Client only- need shadow manager to update the shadow...
	EFL_NOTIFY =				(1<<6),	// Another entity is watching events on this entity (used by teleport)

	// The default behavior in ShouldTransmit is to not send an entity if it doesn't
	// have a model. Certain entities want to be sent anyway because all the drawing logic
	// is in the client DLL. They can set this flag and the engine will transmit them even
	// if they don't have a model.
	EFL_FORCE_CHECK_TRANSMIT =	(1<<7),

	EFL_BOT_FROZEN =			(1<<8),	// This is set on bots that are frozen.
	EFL_SERVER_ONLY =			(1<<9),	// Non-networked entity.
	EFL_NO_AUTO_EDICT_ATTACH =	(1<<10), // Don't attach the edict; we're doing it explicitly
	
	// Some dirty bits with respect to abs computations
	EFL_DIRTY_ABSTRANSFORM =	(1<<11),
	EFL_DIRTY_ABSVELOCITY =		(1<<12),
	EFL_DIRTY_ABSANGVELOCITY =	(1<<13),
	EFL_DIRTY_SURROUNDING_COLLISION_BOUNDS	= (1<<14),
	EFL_DIRTY_SPATIAL_PARTITION = (1<<15),
//	UNUSED						= (1<<16),

	EFL_IN_SKYBOX =				(1<<17),	// This is set if the entity detects that it's in the skybox.
											// This forces it to pass the "in PVS" for transmission.
	EFL_USE_PARTITION_WHEN_NOT_SOLID = (1<<18),	// Entities with this flag set show up in the partition even when not solid
	EFL_TOUCHING_FLUID =		(1<<19),	// Used to determine if an entity is floating

	// FIXME: Not really sure where I should add this...
	EFL_IS_BEING_LIFTED_BY_BARNACLE = (1<<20),
	EFL_NO_ROTORWASH_PUSH =		(1<<21),		// I shouldn't be pushed by the rotorwash
	EFL_NO_THINK_FUNCTION =		(1<<22),
	EFL_NO_GAME_PHYSICS_SIMULATION = (1<<23),

	EFL_CHECK_UNTOUCH =			(1<<24),
	EFL_DONTBLOCKLOS =			(1<<25),		// I shouldn't block NPC line-of-sight
	EFL_DONTWALKON =			(1<<26),		// NPC;s should not walk on this entity
	EFL_NO_DISSOLVE =			(1<<27),		// These guys shouldn't dissolve
	EFL_NO_MEGAPHYSCANNON_RAGDOLL = (1<<28),	// Mega physcannon can't ragdoll these guys.
	EFL_NO_WATER_VELOCITY_CHANGE  =	(1<<29),	// Don't adjust this entity's velocity when transitioning into water
	EFL_NO_PHYSCANNON_INTERACTION =	(1<<30),	// Physcannon can't pick these up or punt them
	EFL_NO_DAMAGE_FORCES =		(1<<31),	// Doesn't accept forces from physics damage
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

// edict->movecollide values
enum MoveCollide_t
{
	MOVECOLLIDE_DEFAULT = 0,
	
	// These ones only work for MOVETYPE_FLY + MOVETYPE_FLYGRAVITY
	MOVECOLLIDE_FLY_BOUNCE,	// bounces, reflects, based on elasticity of surface and object - applies friction (adjust velocity)
	MOVECOLLIDE_FLY_CUSTOM,	// Touch() will modify the velocity however it likes
	MOVECOLLIDE_FLY_SLIDE,  // slides along surfaces (no bounce) - applies friciton (adjusts velocity)
	
	MOVECOLLIDE_COUNT,		// Number of different movecollides
	
	// When adding new movecollide types, make sure this is correct
	MOVECOLLIDE_MAX_BITS = 3
};

enum ETFAmmoType
{
	TF_AMMO_DUMMY = 0,	// Dummy index to make the CAmmoDef indices correct for the other ammo types.
	TF_AMMO_PRIMARY,
	TF_AMMO_SECONDARY,
	TF_AMMO_METAL,
	TF_AMMO_GRENADES1,
	TF_AMMO_GRENADES2,
	TF_AMMO_GRENADES3,	// Utility Slot Grenades
	TF_AMMO_COUNT
};

/**
 * Possible drops from loot crates
 */
enum LootType
{
	Loot_Weapon,			/**< Weapons */
	Loot_Item_HealthKit,	/**< Health pickups */
	Loot_Item_AmmoPack,		/**< Ammunition pickups */
	Loot_Pickup_Spell,		/**< Halloween spell pickups */
	Loot_Item_Powerup,		/**< Mannpower powerups */
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

TFCond g_visibleConds[] = {
	TFCond_Bleeding,
	TFCond_Jarated,
	TFCond_Milked,
	TFCond_OnFire,
	TFCond_Gas,
};

TFCond g_runeConds[] = {
	TFCond_RuneStrength,
	TFCond_RuneHaste,
	TFCond_RuneRegen,
	TFCond_RuneResist,
	TFCond_RuneVampire,
	TFCond_RuneWarlock,
	TFCond_RunePrecision,
	TFCond_RuneAgility,
	TFCond_RuneKnockout,
	TFCond_KingRune,
	TFCond_PlagueRune,
	TFCond_SupernovaRune,
};

bool g_TF2Items;
FRRoundState g_RoundState;
int g_PlayerCount;

StringMap g_PrecacheWeapon;	//List of custom models precached by defindex

ConVar fr_healthmultiplier[view_as<int>(TFClass_Engineer)+1];
ConVar fr_fistsdamagemultiplier;
ConVar fr_sectodeployparachute;
ConVar fr_classfilter;

ConVar fr_zone_startdisplay;
ConVar fr_zone_startdisplay_player;
ConVar fr_zone_display;
ConVar fr_zone_display_player;
ConVar fr_zone_shrink;
ConVar fr_zone_shrink_player;
ConVar fr_zone_nextdisplay;
ConVar fr_zone_nextdisplay_player;
ConVar fr_zone_damagemultiplier;

int g_OffsetItemDefinitionIndex;
int g_OffsetRuneType;
int g_OffsetRuneTeam;
int g_OffsetRuneShouldReposition;

#include "royale/config.sp"
#include "royale/entity.sp"
#include "royale/player.sp"

#include "royale/loot/loot_crates.sp"
#include "royale/loot/loot_config.sp"
#include "royale/loot/loot_params.sp"
#include "royale/loot/loot_table.sp"
#include "royale/loot/loot_callbacks.sp"
#include "royale/loot/loot.sp"

#include "royale/vehicles/vehicles.sp"
#include "royale/vehicles/vehicles_config.sp"

#include "royale/battlebus.sp"
#include "royale/command.sp"
#include "royale/console.sp"
#include "royale/convar.sp"
#include "royale/dhook.sp"
#include "royale/editor.sp"
#include "royale/event.sp"
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
	
	delete gamedata;
	
	FREntity.InitPropertyList();
	Command_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
	Loot_Init();
	LootConfig_Init();
	Vehicles_Init();
	VehiclesConfig_Init();
	
	ConVar_Enable();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	if (g_RoundState == FRRoundState_Setup || g_RoundState == FRRoundState_Active)
		TF2_ForceRoundWin(TFTeam_Spectator);
	
	ConVar_Disable();
}

public void OnMapStart()
{
	g_RoundState = FRRoundState_Waiting;
	
	Config_Refresh();
	
	BattleBus_Precache();
	Zone_Precache();
}

public void OnMapEnd()
{
	g_RoundState = FRRoundState_Waiting;
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
	FRPlayer(client).VisibleCond = 0;
}

public void OnClientDisconnect(int client)
{
	DHook_UnhookGiveNamedItem(client);
	Vehicles_ExitVehicle(client);
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
	else if ((buttons & IN_ATTACK || buttons & IN_ATTACK2))
	{
		TF2_TryToPickupDroppedWeapon(client);
		
		//Entering and exiting vehicles
		if (FRPlayer(client).LastVehicleEnterTime < GetGameTime() - 1.0)
		{
			Vehicle vehicle;
			if (Vehicles_GetByClient(client, vehicle))
				Vehicles_ExitVehicle(client);
			else
				Vehicles_TryToEnterVehicle(client);
		}
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char command[64];
	kv.GetSectionName(command, sizeof(command));
	if (StrEqual(command, "+use_action_slot_item_server"))
	{
		if (TF2_TryToPickupDroppedWeapon(client))
			return Plugin_Handled;
		
		int spellbook = TF2_GetItemByClassname(client, "tf_weapon_spellbook");
		if (spellbook != -1 && GetEntProp(spellbook, Prop_Send, "m_iSpellCharges") > 0)
			return Plugin_Continue;
		
		//Player cant switch grappling hook if have spellbook, fix that if not picking up weapon or have spell to cast
		int grapplinghook = TF2_GetItemByClassname(client, "tf_weapon_grapplinghook");
		if (grapplinghook != -1)
		{
			TF2_SwitchActiveWeapon(client, grapplinghook);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public void OnGameFrame()
{
	Vehicles_OnGameFrame();
	
	switch (g_RoundState)
	{
		case FRRoundState_Waiting: TryToStartRound();
		case FRRoundState_Active: TryToEndRound();
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHook_OnEntityCreated(entity, classname);
	SDKHook_OnEntityCreated(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	if (0 < entity < 2048)
	{
		Loot_OnEntityDestroyed(entity);
		Vehicles_OnEntityDestroyed(entity);
		FREntity.Destroy(entity);
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	//Dont give uber on spawn from mannpower
	if (condition == TFCond_UberchargedCanteen && FRPlayer(client).PlayerState == PlayerState_Parachute)
		TF2_RemoveCondition(client, TFCond_UberchargedCanteen);
	
	for (int i = 0; i < sizeof(g_visibleConds); i++)
		if (condition == g_visibleConds[i])
			FRPlayer(client).VisibleCond++;
	
	//knockout dont get forced to melee if have fists as melee weapon (only works properly on heavy)
	if (condition == TFCond_RuneKnockout)
		TF2_SwitchActiveWeapon(client, TF2_GetItemInSlot(client, WeaponSlot_Melee));
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Parachute && FRPlayer(client).PlayerState == PlayerState_Parachute)
	{
		//Remove starting parachute as it no longer needed, and set state to alive
		TF2_RemoveItemInSlot(client, WeaponSlot_Secondary);
		FRPlayer(client).PlayerState = PlayerState_Alive;
	}
	
	for (int i = 0; i < sizeof(g_visibleConds); i++)
		if (condition == g_visibleConds[i])
			FRPlayer(client).VisibleCond--;
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Changed;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int index, Handle &item)
{
	return TF2_OnGiveNamedItem(client, classname, index);
}

bool TryToStartRound()
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return false;
	
	//Need 2 players
	if (GetPlayerCount() < 2)
		return false;
	
	//Start round
	g_RoundState = FRRoundState_Setup;
	TF2_CreateSetupTimer(10, EntOutput_SetupFinished);
	return true;
}

public Action EntOutput_SetupFinished(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
	
	// how
	if (g_RoundState != FRRoundState_Setup)
		return;
	
	g_RoundState = FRRoundState_Active;
	
	BattleBus_SpawnPlayerBus();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
			BattleBus_SpectateBus(client);
	}
	
	g_PlayerCount = GetAlivePlayersCount();
	
	Zone_RoundArenaStart();
	Loot_SpawnCratesInWorld();
}

void TryToEndRound()
{
	int winner;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).IsAlive())
		{
			if (winner)	//More than 1 player alive
				return;
			
			winner = client;
		}
	}
	
	//Round ended
	g_RoundState = FRRoundState_End;
	
	if (!winner)	//Nobody alive? wew
	{
		TF2_ForceRoundWin(TFTeam_Spectator);
		PrintToChatAll("%t", "RoundState_NoWinner");
	}
	else
	{
		TF2_ForceRoundWin(TFTeam_Alive);
		PrintToChatAll("%t", "RoundState_Winner", winner, FRPlayer(winner).Killstreak);
	}
	
	ArrayList mostKills = new ArrayList();
	int killStreak;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && FRPlayer(client).Killstreak > 0)
		{
			if (FRPlayer(client).Killstreak > killStreak)
			{
				mostKills.Clear();
				killStreak = FRPlayer(client).Killstreak;
				mostKills.Push(client);
			}
			else if (FRPlayer(client).Killstreak == killStreak)
			{
				mostKills.Push(client);
			}
		}
	}
	
	int length = mostKills.Length;
	if (length == 0)
	{
		delete mostKills;
		return;
	}
	
	char message[256];
	for (int i = 0; i < length; i++)
	{
		if (length > 1 && 0 < i < length - 1)
			Format(message, sizeof(message), "%s, %N", message, mostKills.Get(i));
		else if (length > 1 && i == length - 1)
			Format(message, sizeof(message), "%s %t %N", message, "RoundState_MostKillsAnd", mostKills.Get(i));
		else
			Format(message, sizeof(message), "%N", mostKills.Get(i));
	}
	
	PrintToChatAll("%t", "RoundState_MostKills", message, killStreak);
	delete mostKills;
}