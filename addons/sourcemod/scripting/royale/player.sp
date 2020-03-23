static PlayerState g_ClientPlayerState[TF_MAXPLAYERS + 1];
static TFTeam g_ClientTeam[TF_MAXPLAYERS + 1];
static bool g_ClientOutsideZone[TF_MAXPLAYERS + 1];
static EditorState g_ClientEditorState[TF_MAXPLAYERS + 1];
static int g_ClientEditorCrateRef[TF_MAXPLAYERS + 1];

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
	
	property TFTeam Team
	{
		public get()
		{
			return g_ClientTeam[this];
		}
		
		public set(TFTeam val)
		{
			g_ClientTeam[this] = val;
		}
	}
	
	property bool OutsideZone
	{
		public get()
		{
			return g_ClientOutsideZone[this];
		}
		
		public set(bool val)
		{
			g_ClientOutsideZone[this] = val;
		}
	}
	
	property EditorState EditorState
	{
		public get()
		{
			return g_ClientEditorState[this];
		}
		
		public set(EditorState val)
		{
			g_ClientEditorState[this] = val;
		}
	}
	
	property int EditorCrateRef
	{
		public get()
		{
			return g_ClientEditorCrateRef[this];
		}
		
		public set(int val)
		{
			g_ClientEditorCrateRef[this] = val;
		}
	}
}
