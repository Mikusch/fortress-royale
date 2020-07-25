enum
{
	Prop_EntRef = 0, 
	Prop_OutsideZone,
	Prop_ZoneDamageTicks,
	Prop_Spectator,
	Prop_Team,
	
	MAX_PROP_TYPES
}

static ArrayList g_Properties;

methodmap FREntity
{
	public static void InitPropertyList()
	{
		g_Properties = new ArrayList(MAX_PROP_TYPES);
	}
	
	public static void Destroy(int entity)
	{
		int index = g_Properties.FindValue(EntIndexToEntRef(entity), Prop_EntRef);
		if (index > -1)
			g_Properties.Erase(index);
	}
	
	public FREntity(int entity)
	{
		int ref = EntIndexToEntRef(entity);
		int index = g_Properties.FindValue(ref, Prop_EntRef);
		if (index > -1)
		{
			return view_as<FREntity>(index);
		}
		else
		{
			//Push empty value to new array, ArrayList.Resize dont get initialized
			any buffer[MAX_PROP_TYPES];
			buffer[Prop_EntRef] = ref;
			
			g_Properties.PushArray(buffer);
			return view_as<FREntity>(g_Properties.Length-1);
		}
	}
	
	property int Ref
	{
		public get()
		{
			return g_Properties.Get(view_as<int>(this), Prop_EntRef);
		}
	}
	
	property bool OutsideZone
	{
		public get()
		{
			return g_Properties.Get(view_as<int>(this), Prop_OutsideZone);
		}
		
		public set(bool val)
		{
			g_Properties.Set(view_as<int>(this), val, Prop_OutsideZone);
		}
	}
	
	property bool ZoneDamageTicks
	{
		public get()
		{
			return g_Properties.Get(view_as<int>(this), Prop_ZoneDamageTicks);
		}
		
		public set(bool val)
		{
			g_Properties.Set(view_as<int>(this), val, Prop_ZoneDamageTicks);
		}
	}
	
	property TFTeam Team
	{
		public get()
		{
			return g_Properties.Get(view_as<int>(this), Prop_Team);
		}
		
		public set(TFTeam val)
		{
			g_Properties.Set(view_as<int>(this), val, Prop_Team);
		}
	}
	
	public void ChangeToSpectator()
	{
		int val = g_Properties.Get(view_as<int>(this), Prop_Spectator);
		val++;
		g_Properties.Set(view_as<int>(this), val, Prop_Spectator);
		if (val == 1)
		{
			g_Properties.Set(view_as<int>(this), TF2_GetTeam(this.Ref), Prop_Team);
			TF2_ChangeTeam(this.Ref, TFTeam_Spectator);
		}
	}
	
	public void ChangeToTeam()
	{
		int val = g_Properties.Get(view_as<int>(this), Prop_Spectator);
		val--;
		g_Properties.Set(view_as<int>(this), val, Prop_Spectator);
		if (val == 0)
		{
			TF2_ChangeTeam(this.Ref, view_as<TFTeam>(g_Properties.Get(view_as<int>(this), Prop_Team)));
		}
	}
}
