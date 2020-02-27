/**
 * Possible drops from loot crates
 */
enum ContentType
{
	ContentType_Weapon_Primary = (1<<0),	/**< Primary weapons */
	ContentType_Weapon_Secondary = (1<<1),	/**< Secondary weapons */
	ContentType_Weapon_Melee = (1<<2),		/**< Melee weapons */
	ContentType_GrapplingHook = (1<<3),		/**< Grappling Hook etc. */
	ContentType_Health = (1<<4),			/**< Health pickups */
	ContentType_Ammo = (1<<5),				/**< Ammunition pickups */
	ContentType_Spell = (1<<6),				/**< Halloween spells */
	ContentType_Rune = (1<<7)				/**< Mannpower powerups */
}

/** Weapons to be dropped as tf_dropped_weapon entities */
#define CONTENT_TYPE_WEAPONS	ContentType_Weapon_Primary|ContentType_Weapon_Secondary|ContentType_Weapon_Melee|ContentType_Weapon_Other
/** Entities that can be picked up by walking over them */
#define CONTENT_TYPE_PICKUPS	ContentType_Health|ContentType_Ammo|ContentType_Spell|ContentType_Rune
/** Everything */
#define CONTENT_TYPE_ALL		view_as<ContentType>(0xFFFFFFFF)

/**
 * Loot crate information from configuration
 */
enum struct LootCrate
{
	int entRef;						/**< Entity reference of this crate.
									 Should be set when spawning a new loot crate using this definition.
									 A crate that has not spawned yet should set this to INVALID_ENT_REFERENCE. */
	float origin[3];				/**< Spawn origin */
	float angles[3];				/**< Spawn angles */
	char model[PLATFORM_MAX_PATH];	/**< World model */
	int skin;						/**< Model skin */
	int health;						/**< Amount of damage required to open */
	float chance;					/**< Chance for this crate to spawn at all */
	ContentType contents;			/**< Content bitflags **/
}

/**
 * Weapon information from configuration
 */
enum struct LootCrateWeapon
{
	int defindex;
	int chance;
}

// TODO: Spawn all crates according to LootCrate struct retrieved from config
//		Populate the LootCrate.entRef attribute after spawn
//    Hook OnBreak entity output and fetch the LootCrate struct using the ent ref, then spawn loot accordingly
