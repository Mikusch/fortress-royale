/*
Call_StartFunction(null, lootConfig.callback);
Call_PushCell(lootConfig.callbackParams);
Call_Finish();
*/

public int LootCallback_CreateWeapon(CallbackParams params)
{
	PrintToServer("defindex %d", params.GetInt("defindex"));
}
