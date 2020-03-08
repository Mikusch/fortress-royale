/*
Call_StartFunction(null, lootConfig.callback);
Call_PushCell(lootConfig.callbackParams);
Call_Finish();
*/

public int LootCallback_CreateWeapon(CallbackParams params)
{
	PrintToServer("CreateWeapon defindex %d", params.GetInt("defindex"));
}

public int LootCallback_CreatePickup(CallbackParams params)
{
	char classname[256];
	params.GetString("classname", classname, sizeof(classname));
	
	PrintToServer("CreatePickup classname %s", classname);
}

public int LootCallback_CreateSpells(CallbackParams params)
{
	PrintToServer("CreateSpells");
}

public int LootCallback_CreatePowerup(CallbackParams params)
{
	PrintToServer("CreatePowerup index %d", params.GetInt("index"));
}
