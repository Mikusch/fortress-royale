static PlayerState g_ClientPlayerState[TF_MAXPLAYERS + 1];
static int g_ClientSecToDeployParachute[TF_MAXPLAYERS + 1];
static int g_ClientVisibleCond[TF_MAXPLAYERS + 1];
static float g_ClientLastWeaponPickupTime[TF_MAXPLAYERS + 1];
static float g_ClientLastVehicleEnterTime[TF_MAXPLAYERS + 1];
static int g_ClientKillstreak[TF_MAXPLAYERS + 1];
static bool g_ClientOutsideZone[TF_MAXPLAYERS + 1];
static EditorState g_ClientEditorState[TF_MAXPLAYERS + 1];
static EditorItem g_ClientEditorItem[TF_MAXPLAYERS + 1];
static int g_ClientEditorItemRef[TF_MAXPLAYERS + 1];
static int g_ClientZoneDamageTicks[TF_MAXPLAYERS + 1];

static TFTeam g_ClientTeam[TF_MAXPLAYERS + 1];
static int g_ClientSpectator[TF_MAXPLAYERS + 1];
static TFClassType g_ClientClass[TF_MAXPLAYERS + 1];
static int g_ClientClassUnknown[TF_MAXPLAYERS + 1];

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
	
	property int VisibleCond
	{
		public get()
		{
			return g_ClientVisibleCond[this];
		}
		
		public set(int val)
		{
			g_ClientVisibleCond[this] = val;
		}
	}
	
	property float LastWeaponPickupTime
	{
		public get()
		{
			return g_ClientLastWeaponPickupTime[this];
		}
		
		public set(float val)
		{
			g_ClientLastWeaponPickupTime[this] = val;
		}
	}
	
	property float LastVehicleEnterTime
	{
		public get()
		{
			return g_ClientLastVehicleEnterTime[this];
		}
		
		public set(float val)
		{
			g_ClientLastVehicleEnterTime[this] = val;
		}
	}
	
	property int Killstreak
	{
		public get()
		{
			return g_ClientKillstreak[this];
		}
		
		public set(int val)
		{
			g_ClientKillstreak[this] = val;
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
	
	property EditorItem EditorItem
	{
		public get()
		{
			return g_ClientEditorItem[this];
		}
		
		public set(EditorItem val)
		{
			g_ClientEditorItem[this] = val;
		}
	}
	
	property int EditorItemRef
	{
		public get()
		{
			return g_ClientEditorItemRef[this];
		}
		
		public set(int val)
		{
			g_ClientEditorItemRef[this] = val;
		}
	}
	
	property int ZoneDamageTicks
	{
		public get()
		{
			return g_ClientZoneDamageTicks[this];
		}
		
		public set(int val)
		{
			g_ClientZoneDamageTicks[this] = val;
		}
	}
	
	property TFTeam Team
	{
		public get()
		{
			return g_ClientTeam[this];
		}
	}
	
	property TFClassType Class
	{
		public get()
		{
			return g_ClientClass[this];
		}
	}
	
	public bool IsAlive()
	{
		return g_ClientPlayerState[this] == PlayerState_BattleBus || g_ClientPlayerState[this] == PlayerState_Parachute || g_ClientPlayerState[this] == PlayerState_Alive;
	}
	
	public void ChangeTeam(TFTeam team, bool respawn = false, bool ghost = true)
	{
		if (TF2_IsPlayerInCondition(this.Client, TFCond_HalloweenGhostMode))
			TF2_RemoveCondition(this.Client, TFCond_HalloweenGhostMode);
		
		SetEntProp(this.Client, Prop_Send, "m_lifeState", LIFE_DEAD);
		TF2_ChangeClientTeam(this.Client, team);
		SetEntProp(this.Client, Prop_Send, "m_lifeState", LIFE_ALIVE);
		
		if (respawn)
		{
			//Allow RuneRegenThink to start
			GameRules_SetProp("m_bPowerupMode", true);
			TF2_RespawnPlayer(this.Client);
			GameRules_SetProp("m_bPowerupMode", false);
		}
		
		if (ghost)
			TF2_AddCondition(this.Client, TFCond_HalloweenGhostMode, TFCondDuration_Infinite);
	}
	
	public void ChangeToSpectator()
	{
		if (++g_ClientSpectator[this] == 1)
		{
			g_ClientTeam[this] = TF2_GetTeam(this.Client);
			TF2_ChangeTeam(this.Client, TFTeam_Spectator);
		}
	}
	
	public void ChangeBuildingsToSpectator()
	{
		int building = MaxClients + 1;
		while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
		{
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") == this.Client)
				TF2_ChangeTeam(building, TFTeam_Spectator);
		}
	}
	
	public void ChangeToTeam()
	{
		if (--g_ClientSpectator[this] == 0)
		{
			TF2_ChangeTeam(this.Client, g_ClientTeam[this]);
		}
	}
	
	public void ChangeBuildingsToTeam()
	{
		int building = MaxClients + 1;
		while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
		{
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") == this.Client)
				TF2_ChangeTeam(building, g_ClientTeam[this]);
		}
	}
	
	public void ChangeToUnknown()
	{
		if (++g_ClientClassUnknown[this] == 1)
		{
			g_ClientClass[this] = TF2_GetPlayerClass(this.Client);
			TF2_SetPlayerClass(this.Client, TFClass_Unknown);
		}
	}
	
	public void ChangeToClass()
	{
		if (--g_ClientClassUnknown[this] == 0)
		{
			TF2_SetPlayerClass(this.Client, g_ClientClass[this]);
		}
	}
}
