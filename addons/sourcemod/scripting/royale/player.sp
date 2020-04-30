static PlayerState g_ClientPlayerState[TF_MAXPLAYERS + 1];
static int g_ClientSecToDeployParachute[TF_MAXPLAYERS + 1];
static bool g_ClientOutsideZone[TF_MAXPLAYERS + 1];
static EditorState g_ClientEditorState[TF_MAXPLAYERS + 1];
static int g_ClientEditorCrateRef[TF_MAXPLAYERS + 1];

static TFTeam g_ClientTeam[TF_MAXPLAYERS + 1];
static int g_ClientSpectator[TF_MAXPLAYERS + 1];

methodmap FRPlayer
{
	public FRPlayer(int client)
	{
		return view_as<FRPlayer>(client);
	}
	
	property int Client
	{
		public get()
		{
			return view_as<int>(this);
		}
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
	
	property int SecToDeployParachute
	{
		public get()
		{
			return g_ClientSecToDeployParachute[this];
		}
		
		public set(int val)
		{
			g_ClientSecToDeployParachute[this] = val;
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
	
	public void ChangeToSpectator()
	{
		g_ClientSpectator[this]++;
		
		if (g_ClientSpectator[this] == 1)
		{
			g_ClientTeam[this] = TF2_GetTeam(this.Client);
			TF2_ChangeTeam(this.Client, TFTeam_Spectator);
		}
	}
	
	public void ChangeToSpectatorBuilding()
	{
		int building = MaxClients+1;
		while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
		{
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") == this.Client)
				TF2_ChangeTeam(building, TFTeam_Spectator);
		}
	}
	
	public void ChangeToTeam()
	{
		g_ClientSpectator[this]--;
		
		if (g_ClientSpectator[this] == 0)
		{
			TF2_ChangeTeam(this.Client, g_ClientTeam[this]);
		}
	}
	
	public void ChangeToTeamBuilding()
	{
		int building = MaxClients+1;
		while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
		{
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") == this.Client)
				TF2_ChangeTeam(building, g_ClientTeam[this]);
		}
	}
}
