int g_OriginalClassHealth[view_as<int>(TFClass_Engineer)+1];

void Patch_Enable()
{
	for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		Address playerClassData = SDKCall_GetPlayerClassData(class);
		g_OriginalClassHealth[class] = LoadFromAddress(playerClassData + view_as<Address>(g_OffsetMaxHealth), NumberType_Int32);
		StoreToAddress(playerClassData + view_as<Address>(g_OffsetMaxHealth), fr_health[class].IntValue, NumberType_Int32);
	}
}

void Patch_Disable()
{
	for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		Address playerClassData = SDKCall_GetPlayerClassData(class);
		StoreToAddress(playerClassData + view_as<Address>(g_OffsetMaxHealth), g_OriginalClassHealth[class], NumberType_Int32);
	}
}