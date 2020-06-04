enum struct LootTable
{
	LootType type;
	Function callback_create;
	Function callback_class;
	Function callback_precache;
	CallbackParams callbackParams;
}

static ArrayList g_LootTable[view_as<int>(LootType)][view_as<int>(TFClassType)];

void LootTable_ReadConfig(KeyValues kv)
{
	//Clear current table
	for (int type = 0; type < sizeof(g_LootTable); type++)
		for (int class = 0; class < sizeof(g_LootTable[]); class++)
			delete g_LootTable[type][class];
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			LootTable lootTable;
			char type[CONFIG_MAXCHAR];
			kv.GetString("type", type, sizeof(type));
			lootTable.type = Loot_StrToLootType(type);
			
			char callback[CONFIG_MAXCHAR];
			kv.GetString("callback_create", callback, sizeof(callback), NULL_STRING);
			lootTable.callback_create = GetFunctionByName(null, callback);
			if (lootTable.callback_create == INVALID_FUNCTION)
			{
				LogError("Unable to find create function '%s' from type '%s'", callback, type);
				continue;
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
				if (!g_LootTable[lootTable.type][TFClass_Unknown])
					g_LootTable[lootTable.type][0] = new ArrayList(sizeof(LootTable));
				
				ArrayList list = g_LootTable[lootTable.type][0];
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
						if (!g_LootTable[lootTable.type][class])
							g_LootTable[lootTable.type][class] = new ArrayList(sizeof(LootTable));
						
						ArrayList list = g_LootTable[lootTable.type][class];
						list.PushArray(lootTable);
					}
				}
			}
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
}

bool LootTable_GetRandomLoot(LootTable lootTable, LootType type, TFClassType class)
{
	ArrayList list;
	
	if (g_LootTable[type][class])
		list = g_LootTable[type][class];
	else if (g_LootTable[type][TFClass_Unknown])
		list = g_LootTable[type][0];
	else
		return false;
	
	list.GetArray(GetRandomInt(0, list.Length - 1), lootTable, sizeof(lootTable));
	return true;
}