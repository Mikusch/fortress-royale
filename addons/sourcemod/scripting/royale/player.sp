static bool g_ClientInBattleBus[TF_MAXPLAYERS + 1];

methodmap FRPlayer
{
	public FRPlayer(int client)
	{
		return view_as<FRPlayer>(client);
	}
	
	property bool InBattleBus
	{
		public get()
		{
			return g_ClientInBattleBus[this];
		}
		
		public set(bool val)
		{
			g_ClientInBattleBus[this] = val;
		}
	}
}
