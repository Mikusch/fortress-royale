/**
 * Copyright (C) 2022  Mikusch
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

static ArrayList g_itemConfigs;
static ArrayList g_crateConfigs;

methodmap CallbackParams < StringMap
{
	public CallbackParams(StringMap map)
	{
		return view_as<CallbackParams>(map.Clone());
	}
	
	public void Parse(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char key[CONFIG_MAX_LENGTH], value[CONFIG_MAX_LENGTH];
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
		char value[CONFIG_MAX_LENGTH];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return view_as<bool>(StringToInt(value));
	}
	
	public int GetInt(const char[] key, int defValue = 0)
	{
		char value[CONFIG_MAX_LENGTH];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToInt(value);
	}
	
	public int GetIntEx(const char[] key, int &result)
	{
		char value[CONFIG_MAX_LENGTH];
		if (!this.GetString(key, value, sizeof(value)))
			return 0;
		
		return StringToIntEx(value, result);
	}
	
	public float GetFloat(const char[] key, float defValue = 0.0)
	{
		char value[CONFIG_MAX_LENGTH];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToFloat(value);
	}
	
	public int GetFloatEx(const char[] key, float &result)
	{
		char value[CONFIG_MAX_LENGTH];
		if (!this.GetString(key, value, sizeof(value)))
			return 0;
		
		return StringToFloatEx(value, result);
	}
}

enum struct ItemConfig
{
	char type[CONFIG_MAX_LENGTH];
	char subtype[CONFIG_MAX_LENGTH];
	StringMap callback_functions;
	StringMap callback_params;
	
	void Parse(KeyValues kv)
	{
		kv.GetString("type", this.type, sizeof(this.type));
		kv.GetString("subtype", this.subtype, sizeof(this.subtype));
		
		if (kv.JumpToKey("callbacks", false))
		{
			if (kv.JumpToKey("functions", false))
			{
				this.callback_functions = KeyValuesToStringMap(kv);
			}
			
			if (kv.JumpToKey("params", false))
			{
				this.callback_params = KeyValuesToStringMap(kv);
			}
			
			kv.GoBack();
		}
	}
	
	void Precache()
	{
		Function callback = this.GetCallbackFunction("precache");
		if (callback == INVALID_FUNCTION)
			return;
		
		CallbackParams params = new CallbackParams(this.callback_params);
		
		Call_StartFunction(null, callback);
		Call_PushCell(params);
		
		if (Call_Finish() != SP_ERROR_NONE)
		{
			LogError("Failed to call callback 'precache' for item '%s/%s'", this.type, this.subtype);
		}
		
		delete params;
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
		delete this.callback_params;
	}
}

enum struct CrateConfig
{
	Regex regex;
	char model[PLATFORM_MAX_PATH];
	int skin;
	char sound[PLATFORM_MAX_PATH];
	ArrayList contents;
	ArrayList extra_contents;
	int max_drops;
	int max_extra_drops;
	
	void Parse(KeyValues kv)
	{
		char pattern[CONFIG_MAX_LENGTH];
		kv.GetString("pattern", pattern, sizeof(pattern));
		if (pattern[0])
		{
			RegexError errcode;
			char message[256];
			this.regex = new Regex(pattern, _, message, sizeof(message), errcode);
			
			if (!this.regex)
			{
				LogError("Failed to compile regular expression [errcode %d]: %s", errcode, message);
			}
		}
		
		kv.GetString("model", this.model, sizeof(this.model));
		this.skin = kv.GetNum("skin");
		
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
		
		this.max_drops = kv.GetNum("max_drops", fr_crate_max_drops.IntValue);
		this.max_extra_drops = kv.GetNum("max_extra_drops", fr_crate_max_extra_drops.IntValue);
	}
	
	void Delete()
	{
		delete this.contents;
		delete this.extra_contents;
	}
	
	bool GetRandomContent(CrateContentConfig content)
	{
		if (this.contents && this.contents.Length > 0)
		{
			ArrayList contents = this.contents.Clone();
			contents.SortCustom(SortFuncADTArray_SortCrateContentsRandom);
			contents.GetArray(0, content);
			delete contents;
			return true;
		}
		
		return false;
	}
	
	bool GetRandomExtraContent(CrateContentConfig extra_content)
	{
		if (this.extra_contents && this.extra_contents.Length > 0)
		{
			ArrayList extra_contents = this.extra_contents.Clone();
			extra_contents.GetArray(GetRandomInt(0, extra_contents.Length - 1), extra_content);
			delete extra_contents;
			return GetRandomFloat() <= extra_content.chance;
		}
		
		return false;
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

void Config_Parse()
{
	char file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "configs/royale/items.cfg");
	
	KeyValues items = new KeyValues("items");
	if (items.ImportFromFile(file))
	{
		g_itemConfigs = new ArrayList(sizeof(ItemConfig));
		
		if (items.GotoFirstSubKey(false))
		{
			do
			{
				ItemConfig item;
				item.Parse(items);
				g_itemConfigs.PushArray(item);
			}
			while (items.GotoNextKey(false));
			items.GoBack();
		}
	}
	else
	{
		LogError("Failed to import config '%s'", file);
	}
	delete items;
	
	BuildPath(Path_SM, file, sizeof(file), "configs/royale/crates.cfg");
	
	KeyValues crates = new KeyValues("crates");
	if (crates.ImportFromFile(file))
	{
		g_crateConfigs = new ArrayList(sizeof(CrateConfig));
		
		if (crates.GotoFirstSubKey(false))
		{
			do
			{
				CrateConfig crate;
				crate.Parse(crates);
				g_crateConfigs.PushArray(crate);
			}
			while (crates.GotoNextKey(false));
			crates.GoBack();
		}
	}
	else
	{
		LogError("Failed to import config '%s'", file);
	}
	delete crates;
}

void Config_Precache()
{
	for (int i = 0; i < g_itemConfigs.Length; i++)
	{
		ItemConfig item;
		if (g_itemConfigs.GetArray(i, item) > 0)
		{
			item.Precache();
		}
	}
}

void Config_Delete()
{
	for (int i = 0; i < g_itemConfigs.Length; i++)
	{
		ItemConfig item;
		if (g_itemConfigs.GetArray(i, item) > 0)
		{
			item.Delete();
		}
	}
	delete g_itemConfigs;
	
	for (int i = 0; i < g_crateConfigs.Length; i++)
	{
		CrateConfig crate;
		if (g_crateConfigs.GetArray(i, crate) > 0)
		{
			crate.Delete();
		}
	}
	delete g_crateConfigs;
}

ArrayList Config_GetCratesByName(const char[] name)
{
	ArrayList list = new ArrayList(sizeof(CrateConfig));
	
	for (int i = 0; i < g_crateConfigs.Length; i++)
	{
		CrateConfig crate;
		if (g_crateConfigs.GetArray(i, crate) > 0)
		{
			if (crate.regex && crate.regex.Match(name) > 0)
			{
				list.PushArray(crate);
			}
		}
	}
	
	return list;
}

bool Config_IsValidCrateName(const char[] name)
{
	for (int i = 0; i < g_crateConfigs.Length; i++)
	{
		CrateConfig crate;
		if (g_crateConfigs.GetArray(i, crate) > 0)
		{
			if (crate.regex && crate.regex.Match(name) > 0)
			{
				return true;
			}
		}
	}
	
	return false;
}

bool Config_GetRandomCrateByName(const char[] name, CrateConfig crate)
{
	ArrayList crates = Config_GetCratesByName(name);
	
	if (!crates || crates.Length == 0)
	{
		LogError("No crate configs for '%s' found", name);
		delete crates;
		return false;
	}
	
	return crates.GetArray(GetRandomInt(0, crates.Length - 1), crate) > 0;
}

ArrayList Config_GetItemsByType(const char[] type, const char[] subtype)
{
	ArrayList list = new ArrayList(sizeof(ItemConfig));
	
	for (int i = 0; i < g_itemConfigs.Length; i++)
	{
		ItemConfig item;
		if (g_itemConfigs.GetArray(i, item) > 0)
		{
			if (StrEqual(item.type, type) && StrEqual(item.subtype, subtype))
			{
				list.PushArray(item);
			}
		}
	}
	
	return list;
}

bool Config_GetRandomItemByType(int client, const char[] type, const char[] subtype, ItemConfig item)
{
	ArrayList items = Config_GetItemsByType(type, subtype);
	
	if (!items || items.Length == 0)
	{
		LogError("No item configs for '%s/%s' found", type, subtype);
		delete items;
		return false;
	}
	
	// Go through each item until one matches our criteria
	for (int i = 0; i < items.Length; i++)
	{
		if (items.GetArray(i, item) > 0)
		{
			Function callback = item.GetCallbackFunction("can_be_used");
			if (callback == INVALID_FUNCTION)
				continue;
			
			CallbackParams params = new CallbackParams(item.callback_params);
			
			Call_StartFunction(null, callback);
			Call_PushCell(client);
			Call_PushCell(params);
			
			// If we can not equip this item, remove it from the list
			bool result;
			if (Call_Finish(result) != SP_ERROR_NONE)
			{
				LogError("Failed to call callback 'can_be_used' for item '%s/%s'", item.type, item.subtype);
				items.Erase(i);
			}
			else if (!result)
			{
				LogMessage("Removing item '%s/%s'", item.type, item.subtype);
				items.Erase(i);
			}
			
			delete params;
		}
	}
	
	if (items.Length == 0)
	{
		delete items;
		LogError("No valid items for '%s/%s' found!", type, subtype);
		return false;
	}
	
	bool success = items.GetArray(GetRandomInt(0, items.Length - 1), item) > 0;
	delete items;
	return success;
}

bool Config_CreateItem(int client, int crate, ItemConfig item)
{
	Function callback = item.GetCallbackFunction("create");
	if (callback == INVALID_FUNCTION)
		return false;
	
	float center[3];
	CBaseEntity(crate).WorldSpaceCenter(center);
	
	CallbackParams params = new CallbackParams(item.callback_params);
	
	Call_StartFunction(null, callback);
	Call_PushCell(client);
	Call_PushCell(params);
	Call_PushArray(center, sizeof(center));
	
	if (Call_Finish() != SP_ERROR_NONE)
	{
		LogError("Failed to call callback 'create' for item '%s/%s'", item.type, item.subtype);
		return false;
	}
	
	return true;
}

static StringMap KeyValuesToStringMap(KeyValues kv)
{
	StringMap map = new StringMap();
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char key[CONFIG_MAX_LENGTH], value[CONFIG_MAX_LENGTH];
			kv.GetSectionName(key, sizeof(key));
			kv.GetString(NULL_STRING, value, sizeof(value));
			map.SetString(key, value);
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
	
	return map;
}
