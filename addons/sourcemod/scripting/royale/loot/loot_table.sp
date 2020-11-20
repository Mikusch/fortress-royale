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

enum struct LootTable
{
	LootType type;
	int tier;
	Function callback_create;
	Function callback_shouldcreate;
	Function callback_class;
	Function callback_precache;
	CallbackParams callbackParams;
}

static ArrayList g_LootTableClass[view_as<int>(LootType)][view_as<int>(TFClassType)];
static ArrayList g_LootTableGlobal[view_as<int>(LootType)];

void LootTable_ReadConfig(KeyValues kv)
{
	//Clear current table
	for (int type = 0; type < sizeof(g_LootTableClass); type++)
		for (int class = 0; class < sizeof(g_LootTableClass[]); class++)
			delete g_LootTableClass[type][class];
	
	for (int type = 0; type < sizeof(g_LootTableGlobal); type++)
		delete g_LootTableGlobal[type];
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			LootTable lootTable;
			char type[CONFIG_MAXCHAR];
			kv.GetString("type", type, sizeof(type));
			lootTable.type = Loot_StrToLootType(type);
			
			lootTable.tier = kv.GetNum("tier", -1);
			
			char callback[CONFIG_MAXCHAR];
			
			kv.GetString("callback_create", callback, sizeof(callback), NULL_STRING);
			lootTable.callback_create = GetFunctionByName(null, callback);
			if (lootTable.callback_create == INVALID_FUNCTION)
			{
				LogError("Unable to find create function '%s' from type '%s'", callback, type);
				continue;
			}
			
			kv.GetString("callback_shouldcreate", callback, sizeof(callback), NULL_STRING);
			if (callback[0] == '\0')
			{
				lootTable.callback_shouldcreate = INVALID_FUNCTION;
			}
			else
			{
				lootTable.callback_shouldcreate = GetFunctionByName(null, callback);
				if (lootTable.callback_shouldcreate == INVALID_FUNCTION)
				{
					LogError("Unable to find shouldcreate function '%s' from type '%s'", callback, type);
					continue;
				}
			}
			
			kv.GetString("callback_class", callback, sizeof(callback), NULL_STRING);
			if (callback[0] == '\0')
			{
				lootTable.callback_class = INVALID_FUNCTION;
			}
			else
			{
				lootTable.callback_class = GetFunctionByName(null, callback);
				if (lootTable.callback_class == INVALID_FUNCTION)
				{
					LogError("Unable to find class function '%s' from type '%s'", callback, type);
					continue;
				}
			}
			
			kv.GetString("callback_precache", callback, sizeof(callback), NULL_STRING);
			if (callback[0] == '\0')
			{
				lootTable.callback_precache = INVALID_FUNCTION;
			}
			else
			{
				lootTable.callback_precache = GetFunctionByName(null, callback);
				if (lootTable.callback_precache == INVALID_FUNCTION)
				{
					LogError("Unable to find precache function '%s' from type '%s'", callback, type);
					continue;
				}
			}
			
			if (kv.JumpToKey("params", false))
			{
				lootTable.callbackParams = new CallbackParams();
				lootTable.callbackParams.ReadConfig(kv);
			}
			
			//Call precache function
			if (lootTable.callback_precache != INVALID_FUNCTION)
			{
				Call_StartFunction(null, lootTable.callback_precache);
				Call_PushCell(lootTable.callbackParams);
				Call_Finish();
			}
			
			//Call class function, see which class this is for
			if (lootTable.callback_class == INVALID_FUNCTION)
			{
				if (!g_LootTableClass[lootTable.type][TFClass_Unknown])
					g_LootTableClass[lootTable.type][0] = new ArrayList(sizeof(LootTable));
				
				ArrayList list = g_LootTableClass[lootTable.type][0];
				list.PushArray(lootTable);
			}
			else
			{
				for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
				{
					Call_StartFunction(null, lootTable.callback_class);
					Call_PushCell(lootTable.callbackParams);
					Call_PushCell(class);
					
					bool result;
					if (Call_Finish(result) == SP_ERROR_NONE && result)
					{
						if (!g_LootTableClass[lootTable.type][class])
							g_LootTableClass[lootTable.type][class] = new ArrayList(sizeof(LootTable));
						
						ArrayList list = g_LootTableClass[lootTable.type][class];
						list.PushArray(lootTable);
					}
				}
			}
			
			if (!g_LootTableGlobal[lootTable.type])
				g_LootTableGlobal[lootTable.type] = new ArrayList(sizeof(LootTable));
			
			g_LootTableGlobal[lootTable.type].PushArray(lootTable);
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
}

bool LootTable_GetRandomLoot(LootTable buffer, int client, LootCrateContent content, TFClassType class)
{
	LootType type = content.type;
	int tier = content.tier;
	
	ArrayList list;
	
	if (fr_classfilter.BoolValue)
	{
		if (g_LootTableClass[type][class])
			list = g_LootTableClass[type][class];
		else if (g_LootTableClass[type][TFClass_Unknown])
			list = g_LootTableClass[type][0];
		else
			return false;
	}
	else
	{
		if (g_LootTableGlobal[type])
			list = g_LootTableGlobal[type];
		else
			return false;
	}
	
	ArrayList loots;
	
	if (tier == -1)
	{
		loots = list.Clone();
	}
	else
	{
		//Collect all loot with the specified tier
		loots = new ArrayList(sizeof(LootTable));
		
		LootTable temp;
		for (int i = 0; i < list.Length; i++)
		{
			list.GetArray(i, temp, sizeof(temp));
			if (temp.tier == tier)
				loots.PushArray(temp, sizeof(temp));
		}
	}
	
	int length = loots.Length;
	for (int i = length - 1; i >= 0; i--)
	{
		LootTable lootTable;
		loots.GetArray(i, lootTable, sizeof(lootTable));
		
		//Conditional callback to determine if this loot should spawn
		if (lootTable.callback_shouldcreate != INVALID_FUNCTION)
		{
			Call_StartFunction(null, lootTable.callback_shouldcreate);
			Call_PushCell(client);
			Call_PushCell(lootTable.callbackParams);
			
			bool result;
			if (Call_Finish(result) != SP_ERROR_NONE)
			{
				LogError("Unable to call shouldcreate callback for type '%d' and tier '%d'", type, tier);
				loots.Erase(i);
			}
			else if (!result)
			{
				loots.Erase(i);
			}
		}
	}
	
	length = loots.Length;
	if (length == 0)
	{
		delete loots;
		return false;
	}
	
	loots.GetArray(GetRandomInt(0, length - 1), buffer, sizeof(buffer));
	delete loots;
	return true;
}
