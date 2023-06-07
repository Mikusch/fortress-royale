/**
 * Copyright (C) 2023  Mikusch
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

#pragma newdecls required
#pragma semicolon 1

#define CONFIG_MAX_LENGTH	256

static ArrayList g_hItemConfigs;
static ArrayList g_hCrateConfigs;
static ArrayList g_hWeaponData;

enum struct ItemConfig
{
	char name[CONFIG_MAX_LENGTH];
	char type[CONFIG_MAX_LENGTH];
	char subtype[CONFIG_MAX_LENGTH];
	StringMap callback_functions;
	KeyValues callback_data;
	
	void Parse(KeyValues kv)
	{
		if (kv.GetSectionName(this.name, sizeof(this.name)))
		{
			kv.GetString("type", this.type, sizeof(this.type));
			kv.GetString("subtype", this.subtype, sizeof(this.subtype));
			
			if (kv.JumpToKey("callbacks", false))
			{
				if (kv.JumpToKey("functions", false))
				{
					this.callback_functions = new StringMap();
					if (kv.GotoFirstSubKey(false))
					{
						do
						{
							char key[CONFIG_MAX_LENGTH], value[CONFIG_MAX_LENGTH];
							kv.GetSectionName(key, sizeof(key));
							kv.GetString(NULL_STRING, value, sizeof(value));
							this.callback_functions.SetString(key, value);
						}
						while (kv.GotoNextKey(false));
						kv.GoBack();
					}
					kv.GoBack();
				}
				
				if (kv.JumpToKey("data", false))
				{
					this.callback_data = new KeyValues("data");
					this.callback_data.Import(kv);
					kv.GoBack();
				}
				
				kv.GoBack();
			}
		}
	}
	
	Function GetCallbackFunction(const char[] key, Handle plugin = null)
	{
		char name[CONFIG_MAX_LENGTH];
		if (this.callback_functions.GetString(key, name, sizeof(name)))
		{
			Function callback = GetFunctionByName(plugin, name);
			if (callback == INVALID_FUNCTION)
			{
				LogError("Unable to find callback function '%s' for '%s'", name, key);
			}
			
			return callback;
		}
		
		// No callbacks specified on item
		return INVALID_FUNCTION;
	}
	
	void Delete()
	{
		delete this.callback_functions;
		delete this.callback_data;
	}
}

enum struct CrateConfig
{
	char name[CONFIG_MAX_LENGTH];
	char model[PLATFORM_MAX_PATH];
	ArrayList contents;
	ArrayList extra_contents;
	float time_to_open;
	int max_drops;
	int max_extra_drops;
	char open_sound[PLATFORM_MAX_PATH];
	char opened_sound[PLATFORM_MAX_PATH];
	
	void Parse(KeyValues kv)
	{
		if (kv.GetSectionName(this.name, sizeof(this.name)))
		{
			kv.GetString("model", this.model, sizeof(this.model));
			
			if (kv.JumpToKey("contents", false))
			{
				this.contents = new ArrayList(sizeof(CrateContentConfig));
				if (kv.GotoFirstSubKey(false))
				{
					do
					{
						CrateContentConfig content;
						content.Parse(kv);
						this.contents.PushArray(content);
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				kv.GoBack();
			}
			
			if (kv.JumpToKey("extra_contents", false))
			{
				this.extra_contents = new ArrayList(sizeof(CrateContentConfig));
				if (kv.GotoFirstSubKey(false))
				{
					do
					{
						CrateContentConfig extra_content;
						extra_content.Parse(kv);
						this.extra_contents.PushArray(extra_content);
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				kv.GoBack();
			}
			
			this.time_to_open = kv.GetFloat("time_to_open", sm_fr_crate_open_time.FloatValue);
			this.max_drops = kv.GetNum("max_drops", sm_fr_crate_max_drops.IntValue);
			this.max_extra_drops = kv.GetNum("max_extra_drops", sm_fr_crate_max_extra_drops.IntValue);
			
			kv.GetString("open_sound", this.open_sound, sizeof(this.open_sound), ")ui/item_open_crate.wav");
			PrecacheSound(this.open_sound);
			
			kv.GetString("opened_sound", this.opened_sound, sizeof(this.opened_sound), ")ui/itemcrate_smash_rare.wav");
			PrecacheSound(this.opened_sound);
		}
	}
	
	void Delete()
	{
		delete this.contents;
		delete this.extra_contents;
	}
	
	void Open(int crate, int client)
	{
		if (!IsValidEntity(crate))
			return;
		
		if (!IsValidClient(client))
			return;
		
		// Normal crate drops (guaranteed)
		if (this.contents)
		{
			ArrayList contents = this.contents.Clone();
			
			int nDropped = 0;
			while (nDropped < this.max_drops)
			{
				// Re-shuffle contents for every drop
				contents.SortCustom(SortFuncADTArray_SortCrateContentsRandom);
				
				// Go through each category and try to drop an item
				for (int i = 0; i < contents.Length; i++)
				{
					CrateContentConfig content;
					if (contents.GetArray(i, content) != 0)
					{
						ArrayList items = Config_GetItemsByTypeFiltered(content.type, content.subtype, client);
						
						if (items.Length == 0)
						{
							// Remove categories with no items
							contents.Erase(i);
							continue;
						}
						
						// Now that we filtered everything, grab a random item
						ItemConfig item;
						if (items.GetArray(GetRandomInt(0, items.Length - 1), item) != 0)
						{
							if (Config_CreateItem(client, crate, item))
							{
								++nDropped;
								break;
							}
						}
						
						delete items;
					}
				}
				
				// If we failed to drop a single item after our first iteration, something is very wrong
				if (nDropped == 0)
				{
					LogError("Could not find any items to drop from '%s' for %L.", this.name, client);
					break;
				}
			}
			
			delete contents;
		}
		
		// Extra crate drops (random, not guaranteed)
		if (this.extra_contents)
		{
			ArrayList extra_contents = this.extra_contents.Clone();
			
			for (int i = 0; i < this.max_extra_drops; i++)
			{
				CrateContentConfig content;
				if (extra_contents.GetArray(GetRandomInt(0, extra_contents.Length - 1), content) != 0)
				{
					ArrayList items = Config_GetItemsByTypeFiltered(content.type, content.subtype, client);
					
					if (items.Length == 0)
					{
						// Remove categories with no items
						extra_contents.Erase(i);
						continue;
					}
					
					// Now that we filtered everything, grab a random item
					if (GetRandomFloat() <= content.chance)
					{
						ItemConfig item;
						if (items.GetArray(GetRandomInt(0, items.Length - 1), item) != 0)
						{
							Config_CreateItem(client, crate, item);
						}
					}
					
					delete items;
				}
			}
			
			delete extra_contents;
		}
	}
}

enum struct CrateContentConfig
{
	char type[CONFIG_MAX_LENGTH];
	char subtype[CONFIG_MAX_LENGTH];
	float chance;
	
	void Parse(KeyValues kv)
	{
		kv.GetString("type", this.type, sizeof(this.type));
		kv.GetString("subtype", this.subtype, sizeof(this.subtype));
		this.chance = kv.GetFloat("chance");
	}
}

enum struct WeaponData
{
	int defindex;
	char world_model[PLATFORM_MAX_PATH];
	ArrayList reskins;
	
	void Parse(KeyValues kv)
	{
		char section[CONFIG_MAX_LENGTH];
		if (kv.GetSectionName(section, sizeof(section)) && StringToIntEx(section, this.defindex))
		{
			kv.GetString("world_model", this.world_model, sizeof(this.world_model));
			
			if (kv.JumpToKey("reskins", false))
			{
				this.reskins = new ArrayList();
				if (kv.GotoFirstSubKey(false))
				{
					do
					{
						if (kv.GetSectionName(section, sizeof(section)))
						{
							int reskin = StringToInt(section);
							if (kv.GetNum(NULL_STRING) != 0)
							{
								this.reskins.Push(reskin);
							}
						}
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				kv.GoBack();
			}
		}
	}
	
	void Delete()
	{
		delete this.reskins;
	}
}

void Config_Parse()
{
	char file[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, file, sizeof(file), "configs/royale/items.cfg");
	KeyValues kv = new KeyValues("items");
	if (kv.ImportFromFile(file))
	{
		g_hItemConfigs = new ArrayList(sizeof(ItemConfig));
		
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				ItemConfig item;
				item.Parse(kv);
				g_hItemConfigs.PushArray(item);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
	else
	{
		LogError("Failed to import config '%s'", file);
	}
	delete kv;
	
	BuildPath(Path_SM, file, sizeof(file), "configs/royale/weapons.cfg");
	kv = new KeyValues("weapons");
	if (kv.ImportFromFile(file))
	{
		g_hWeaponData = new ArrayList(sizeof(WeaponData));
		
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				WeaponData data;
				data.Parse(kv);
				g_hWeaponData.PushArray(data);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
	else
	{
		LogError("Failed to import config '%s'", file);
	}
	delete kv;
	
	// Parse global config (for all maps)
	BuildPath(Path_SM, file, sizeof(file), "configs/royale/global.cfg");
	Config_ParseMapConfig(file);
	
	// Parse map specific config to override global settings
	file[0] = '\0';
	if (Config_GetMapConfigFilepath(file, sizeof(file)))
	{
		Config_ParseMapConfig(file);
	}
}

void Config_ParseCrates(KeyValues kv)
{
	if (!g_hCrateConfigs)
	{
		g_hCrateConfigs = new ArrayList(sizeof(CrateConfig));
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			CrateConfig crate;
			crate.Parse(kv);
			
			int index = g_hCrateConfigs.FindString(crate.name);
			if (index == -1)
			{
				// Insert new crate
				g_hCrateConfigs.PushArray(crate);
			}
			else
			{
				// Override existing crate
				CrateConfig oldCrate;
				if (g_hCrateConfigs.GetArray(index, oldCrate))
				{
					oldCrate.Delete();
					g_hCrateConfigs.SetArray(index, crate);
				}
			}
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
}

void Config_ParseMapConfig(const char[] file)
{
	KeyValues kv = new KeyValues("global");
	if (kv.ImportFromFile(file))
	{
		if (kv.JumpToKey("zone", false))
		{
			Zone_Parse(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("battlebus", false))
		{
			BattleBus_Parse(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("crates", false))
		{
			Config_ParseCrates(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("downloadables", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char filename[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, filename, sizeof(filename));
					AddFileToDownloadsTable(filename);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}
	else
	{
		LogError("Failed to import config '%s'", file);
	}
	delete kv;
}

bool Config_GetMapConfigFilepath(char[] filePath, int length)
{
	char mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	GetMapDisplayName(mapName, mapName, sizeof(mapName));
	
	int partsCount = CountCharInString(mapName, '_') + 1;
	
	// Split map prefix and first part of its name (e.g. pl_hightower)
	char[][] nameParts = new char[partsCount][PLATFORM_MAX_PATH];
	ExplodeString(mapName, "_", nameParts, partsCount, PLATFORM_MAX_PATH);
	
	// Start to stitch name parts together
	char tidyMapName[PLATFORM_MAX_PATH];
	char filePathBuffer[PLATFORM_MAX_PATH];
	strcopy(tidyMapName, sizeof(tidyMapName), nameParts[0]);
	
	// Build file path
	BuildPath(Path_SM, tidyMapName, sizeof(tidyMapName), "configs/royale/maps/%s", tidyMapName);
	
	for (int i = 1; i < partsCount; i++)
	{
		Format(tidyMapName, sizeof(tidyMapName), "%s_%s", tidyMapName, nameParts[i]);
		Format(filePathBuffer, sizeof(filePathBuffer), "%s.cfg", tidyMapName);
		
		// Find the most specific config
		if (FileExists(filePathBuffer))
		{
			strcopy(filePath, length, filePathBuffer);
		}
	}
	
	return FileExists(filePath);
}

void Config_Delete()
{
	for (int i = 0; i < g_hItemConfigs.Length; i++)
	{
		ItemConfig item;
		if (g_hItemConfigs.GetArray(i, item) != 0)
		{
			item.Delete();
		}
	}
	delete g_hItemConfigs;
	
	for (int i = 0; i < g_hCrateConfigs.Length; i++)
	{
		CrateConfig crate;
		if (g_hCrateConfigs.GetArray(i, crate) != 0)
		{
			crate.Delete();
		}
	}
	delete g_hCrateConfigs;
	
	for (int i = 0; i < g_hWeaponData.Length; i++)
	{
		WeaponData data;
		if (g_hWeaponData.GetArray(i, data) != 0)
		{
			data.Delete();
		}
	}
	delete g_hWeaponData;
}

bool Config_GetCrateByName(const char[] name, CrateConfig crate)
{
	for (int i = 0; i < g_hCrateConfigs.Length; i++)
	{
		if (g_hCrateConfigs.GetArray(i, crate) != 0)
		{
			if (StrEqual(crate.name, name))
			{
				return true;
			}
		}
	}
	
	return false;
}

ArrayList Config_GetItemsByType(const char[] type, const char[] subtype)
{
	ArrayList list = new ArrayList(sizeof(ItemConfig));
	
	for (int i = 0; i < g_hItemConfigs.Length; i++)
	{
		ItemConfig item;
		if (g_hItemConfigs.GetArray(i, item) != 0)
		{
			if (StrEqual(item.type, type) && StrEqual(item.subtype, subtype))
			{
				list.PushArray(item);
			}
		}
	}
	
	return list;
}

ArrayList Config_GetItemsByTypeFiltered(const char[] type, const char[] subtype, int client)
{
	ArrayList items = Config_GetItemsByType(type, subtype);
	
	for (int i = 0; i < items.Length; i++)
	{
		// Go through each item until one matches our criteria
		ItemConfig item;
		if (items.GetArray(i, item) != 0)
		{
			Function callback = item.GetCallbackFunction("should_drop");
			if (callback == INVALID_FUNCTION)
				continue;
			
			Call_StartFunction(null, callback);
			Call_PushCell(client);
			Call_PushCell(item.callback_data);
			
			// If we can not use item, remove it from the list
			bool result;
			if (Call_Finish(result) != SP_ERROR_NONE)
			{
				LogError("Failed to call callback 'should_drop' for item '%s'", item.name);
				items.Erase(i--);
			}
			else if (!result)
			{
				items.Erase(i--);
			}
		}
	}
	
	return items;
}

bool Config_GetWeaponDataByDefIndex(int defindex, WeaponData data)
{
	int index = g_hWeaponData.FindValue(defindex);
	if (index != -1)
	{
		return g_hWeaponData.GetArray(index, data) != 0;
	}
	
	return false;
}

bool Config_CreateItem(int client, int crate, ItemConfig item)
{
	if (!IsValidClient(client))
		return false;
	
	if (!IsValidEntity(crate))
		return false;
	
	Function callback = item.GetCallbackFunction("create");
	if (callback == INVALID_FUNCTION)
		return false;
	
	float center[3], angles[3];
	CBaseEntity(crate).WorldSpaceCenter(center);
	CBaseEntity(crate).GetAbsAngles(angles);
	
	Call_StartFunction(null, callback);
	Call_PushCell(client);
	Call_PushCell(item.callback_data);
	Call_PushArray(center, sizeof(center));
	Call_PushArray(angles, sizeof(angles));
	
	if (Call_Finish() != SP_ERROR_NONE)
	{
		LogError("Failed to call callback 'create' for item '%s'", item.name);
		return false;
	}
	
	return true;
}
