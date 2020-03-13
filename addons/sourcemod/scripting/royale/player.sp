static PlayerState g_ClientPlayerState[TF_MAXPLAYERS + 1];
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
