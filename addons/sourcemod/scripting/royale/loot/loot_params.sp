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

methodmap CallbackParams < StringMap
{
	public CallbackParams()
	{
		return view_as<CallbackParams>(new StringMap());
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char key[CONFIG_MAXCHAR], value[CONFIG_MAXCHAR];
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
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return view_as<bool>(StringToInt(value));
	}
	
	public int GetInt(const char[] key, int defValue = 0)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToInt(value);
	}
	
	public bool GetIntEx(const char[] key, int &defValue)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return false;
		
		defValue = StringToInt(value);
		return true;
	}
	
	public float GetFloat(const char[] key, float defValue = 0.0)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return defValue;
		else
			return StringToFloat(value);
	}
	
	public bool GetFloatEx(const char[] key, float &defValue)
	{
		char value[CONFIG_MAXCHAR];
		if (!this.GetString(key, value, sizeof(value)))
			return false;
		
		defValue = StringToFloat(value);
		return true;
	}
}