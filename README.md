# Fortress Royale
A battle royale game mode for Team Fortress 2, created by [Mikusch](https://github.com/Mikusch) and [42](https://github.com/FortyTwoFortyTwo).

**This gamemode is still in an early stage of development.**

## Dependencies
* SourceMod 1.10
* [DHooks with Detour Support](https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589)
* [TF2 Econ Data](https://forums.alliedmods.net/showthread.php?t=315011)
* [LoadSoundScript](https://github.com/haxtonsale/LoadSoundScript) (optional, used for vehicle sounds)

## Configuration
There are various [configuration files](https://github.com/Mikusch/fortress-royale/tree/master/addons/sourcemod/configs/royale) available to edit:
* ``global.cfg`` - Global configuration that applies to *all* maps.
* ``maps/<mapname>.cfg`` - Map-specific configuration. These will override anything specified in ``global.cfg``. Files should only be named after the map's "tidy" name e.g. for a map called``br_awesomemap_b3_fix`` the plugin will look for the configuration file ``br_awesomemap.cfg``.
* ``loot.cfg`` - All the loot that may drop from crates.
