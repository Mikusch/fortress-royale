enum
{
	Prop_EntRef = 0, 
	Prop_OutsideZone, 
	
	MAX_PROP_TYPES
}

static ArrayList g_Properties;

methodmap FREntity
{
	public static void InitPropertyList()
	{
		if (g_Properties == null)
			g_Properties = new ArrayList(MAX_PROP_TYPES);
	}
	
	public FREntity(int ref)
	{
		return view_as<FREntity>(ref);
	}
	
	property int Ref
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int Index
	{
		public get()
		{
			return EntRefToEntIndex(this.Ref);
		}
	}
	
	public int FindAttributeListIndex()
	{
		FREntity.InitPropertyList();
		
		int index = g_Properties.FindValue(this.Ref);
		if (index > -1)
		{
			return index;
		}
		else
		{
			int length = g_Properties.Length;
			g_Properties.Resize(length + 1);
			g_Properties.Set(length, this.Ref, 0);
			return length;
		}
	}
	
	property bool OutsideZone
	{
		public get()
		{
			return g_Properties.Get(this.FindAttributeListIndex(), Prop_OutsideZone);
		}
		
		public set(bool val)
		{
			g_Properties.Set(this.FindAttributeListIndex(), val, Prop_OutsideZone);
		}
	}
	
	public void Destroy()
	{
		g_Properties.Erase(this.FindAttributeListIndex());
	}
}
