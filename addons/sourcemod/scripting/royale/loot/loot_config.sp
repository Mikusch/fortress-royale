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

static LootCrate g_LootCrateDefault;	//Default loot crate
static LootCrate g_LootCrateBus;		//Bus loot crate

methodmap LootPrefabs < ArrayList
{
	public LootPrefabs()
	{
		return view_as<LootPrefabs>(new ArrayList(sizeof(LootCrate)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every prefabs
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrate loot;
				loot = g_LootCrateDefault;
				
				//Must have a targetname for prefab
				kv.GetString("targetname", loot.targetname, sizeof(loot.targetname));
				if (!loot.targetname[0])
				{
					LogError("Found prefab with missing 'targetname' key");
					continue;
				}
				
				loot.ReadConfig(kv);
				this.PushArray(loot);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
	
	public bool FindPrefab(const char[] name, LootCrate lootBuffer)
	{
		int length = this.Length;
		for (int i = 0; i < length; i++)
		{
			LootCrate Loot;
			this.GetArray(i, Loot);
			
			if (StrEqual(Loot.targetname, name, false))
			{
				lootBuffer = Loot;
				return true;
			}
		}
		
		return false;
	}
}

static LootPrefabs g_LootPrefabs;		//All prefabs to copy

methodmap LootConfig < ArrayList
{
	public LootConfig()
	{
		return view_as<LootConfig>(new ArrayList(sizeof(LootCrate)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every crates
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrate loot;
				
				//Attempt use targetname, otherwise use default
				kv.GetString("targetname", loot.targetname, sizeof(loot.targetname));
				if (!g_LootPrefabs.FindPrefab(loot.targetname, loot))
					loot = g_LootCrateDefault;
				
				loot.ReadConfig(kv);
				this.PushArray(loot);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public void SetConfig(KeyValues kv)
	{
		int length = this.Length;
		for (int configIndex = 0; configIndex < length; configIndex++)
		{
			LootCrate loot;
			this.GetArray(configIndex, loot);
			
			kv.JumpToKey("322", true);	//Just so we can create new key without jumping to existing Loot
			kv.SetSectionName("LootCrate");
			loot.SetConfig(kv);
			kv.GoBack();
		}
	}
}

static LootConfig g_LootConfig;			//All loot crates from config

void LootConfig_Init()
{
	g_LootPrefabs = new LootPrefabs();
	g_LootConfig = new LootConfig();
	
	g_LootCrateDefault.entity = INVALID_ENT_REFERENCE;
}

void LootConfig_Clear()
{
	g_LootPrefabs.Clear();
	g_LootConfig.Clear();
}

void LootConfig_ReadConfig(KeyValues kv)
{
	if (kv.JumpToKey("LootDefault", false))
	{
		g_LootCrateDefault.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("LootBus", false))
	{
		g_LootCrateBus.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("LootPrefabs", false))
	{
		g_LootPrefabs.ReadConfig(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("LootCrates", false))
	{
		g_LootConfig.ReadConfig(kv);
		kv.GoBack();
	}
}

void LootConfig_SetConfig(KeyValues kv)
{
	g_LootConfig.SetConfig(kv);
}

int LootConfig_AddCrate(LootCrate loot)
{
	g_LootConfig.PushArray(loot);
	return g_LootConfig.Length - 1;
}

void LootConfig_SetCrate(int pos, LootCrate loot)
{
	g_LootConfig.SetArray(pos, loot);
}

bool LootConfig_GetCrate(int pos, LootCrate loot)
{
	if (pos < 0 || pos >= g_LootConfig.Length)
		return false;
	
	g_LootConfig.GetArray(pos, loot);
	return true;
}

int LootConfig_GetCrateByEntity(int entity, LootCrate loot)
{
	int pos = g_LootConfig.FindValue(entity, LootCrate::entity);
	if (pos == -1)
		return -1;
	
	g_LootConfig.GetArray(pos, loot);
	return pos;
}

void LootConfig_DeleteCrateByEntity(int entity)
{
	int pos = g_LootConfig.FindValue(entity, LootCrate::entity);
	if (pos >= 0)
		g_LootConfig.Erase(pos);
}

bool LootConfig_GetPrefab(int pos, LootCrate loot)
{
	if (pos < 0 || pos >= g_LootPrefabs.Length)
		return false;
	
	g_LootPrefabs.GetArray(pos, loot);
	return true;
}

bool LootConfig_GetPrefabByTargetname(const char[] name, LootCrate loot)
{
	return g_LootPrefabs.FindPrefab(name, loot);
}

void LootCrate_GetDefault(LootCrate loot)
{
	loot = g_LootCrateDefault;
}

void LootCrate_GetBus(LootCrate loot)
{
	loot = g_LootCrateBus;
}