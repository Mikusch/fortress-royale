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

int g_OriginalClassHealth[view_as<int>(TFClass_Engineer)+1];

void Patch_Enable()
{
	for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		Address playerClassData = SDKCall_GetPlayerClassData(class);
		g_OriginalClassHealth[class] = LoadFromAddress(playerClassData + view_as<Address>(g_OffsetMaxHealth), NumberType_Int32);
		StoreToAddress(playerClassData + view_as<Address>(g_OffsetMaxHealth), fr_class_health[class].IntValue, NumberType_Int32);
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