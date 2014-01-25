package updatables;

import updatables.UpdatableBase;
import com.haxepunk.Entity;

class DieOnCollide extends UpdatableBase
{
	public var deathList : Array<String>;
	
	function new(dL : Array<String>)
	{
		super("DieOnCollide");
		deathList = dL;
	}

	public override function moveCollideY(e:Entity)
	{
		if(deathList.length == 0)
			parent.scene.remove(parent);
			
		for(dT in deathList)
		{
			if(dT == e.type)
			{
				parent.scene.remove(parent);
			}
		}
		
		super.moveCollideY(e);
		return false;
	}
}