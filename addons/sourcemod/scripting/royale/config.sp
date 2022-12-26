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

ArrayList g_itemConfigs;
ArrayList g_crateConfigs;

methodmap CallbackParams < StringMap
{
	public CallbackParams()
	{
		return view_as<CallbackParams>(new StringMap());
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
	ArrayList callbacks;
	
	void Parse(KeyValues kv)
	{
		kv.GetString("type", this.type, sizeof(this.type));
		kv.GetString("subtype", this.subtype, sizeof(this.subtype));
		
		if (kv.JumpToKey("callbacks", false))
		{
			this.callbacks = new ArrayList(sizeof(ItemCallbackConfig));
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					ItemCallbackConfig callback;
					callback.Parse(kv);
					this.callbacks.PushArray(callback);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}
	
	void Delete()
	{
		if (this.callbacks)
		{
			for (int i = 0; i < this.callbacks.Length; i++)
			{
				ItemCallbackConfig callback;
				if (this.callbacks.GetArray(i, callback) > 0)
				{
					callback.Delete();
				}
			}
			delete this.callbacks;
		}
	}
}

enum struct ItemCallbackConfig
{
	Function callback;
	CallbackParams params;
	
	void Parse(KeyValues kv)
	{
		char name[CONFIG_MAX_LENGTH];
		kv.GetString("name", name, sizeof(name));
		
		if (name[0])
		{
			this.callback = GetFunctionByName(null, name);
			if (this.callback == INVALID_FUNCTION)
			{
				LogError("Failed to find callback function '%s'", name);
			}
		}
		
		if (kv.JumpToKey("params", false))
		{
			this.params = new CallbackParams();
			this.params.Parse(kv);
		}
	}
	
	void Delete()
	{
		delete this.params;
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
