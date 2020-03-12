static PlayerState g_ClientPlayerState[TF_MAXPLAYERS + 1];
static bool g_ClientEditor[TF_MAXPLAYERS + 1];
static int g_ClientEditorCrate[TF_MAXPLAYERS + 1];

methodmap FRPlayer
{
	public FRPlayer(int client)
	{
		return view_as<FRPlayer>(client);
	}
	
	property PlayerState PlayerState
	{
		public get()
		{
			return g_ClientPlayerState[this];
		}
		
		public set(PlayerState val)
		{
			g_ClientPlayerState[this] = val;
		}
	}
	
	property bool Editor
	{
		public get()
		{
			return g_ClientEditor[this];
		}
		
		public set(bool val)
		{
			g_ClientEditor[this] = val;
		}
	}
	
	property int EditorCrate
	{
		public get()
		{
			return g_ClientEditorCrate[this];
		}
		
		public set(int val)
		{
			g_ClientEditorCrate[this] = val;
		}
	}
}
