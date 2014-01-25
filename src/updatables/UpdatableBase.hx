package updatables;

import com.haxepunk.Entity;

class UpdatableBase extends Entity
{
	public var parent : UpdatableBase;
	public var updtList : Array<UpdatableBase>;
	
	public function new(n:String)
	{
		super();
		updtList = new Array();
		name = n;
	}
	
	public override function update()
	{	
		for(u in updtList)
		{
		  u.update();
		}
		
		super.update();
	}
	
	public override function moveCollideX(e:Entity)
	{
		for(u in updtList)
		{
		  u.moveCollideX(e);
		}
		
		return true;
	}
	
	public override function moveCollideY(e:Entity)
	{
		for(u in updtList)
		{
		  u.moveCollideY(e);
		}
		
		return true;
	}
	
	public function upTrigger()
	{
		for(u in updtList)
		{
		  u.upTrigger();
		}
	}
	
	public function downTrigger()
	{
		for(u in updtList)
		{
		  u.downTrigger();
		}
	}
	
	public function leftTrigger()
	{
		for(u in updtList)
		{
		  u.leftTrigger();
		}
	}
	
	public function rightTrigger()
	{
		for(u in updtList)
		{
		  u.rightTrigger();
		}
	}
	
	public function action1Trigger()
	{
		for(u in updtList)
		{
		  u.action1Trigger();
		}
	}
	
	function action2Trigger()
	{
		for(u in updtList)
		{
		  u.action2Trigger();
		}
	}
	
	public function removeUpdt(name:String)
	{
		for(u in updtList)
		{
			if(u.name == name)
			{
				updtList.remove(u);
				break;
			}
		}
	}
	
	public function addUpdt(addMe:UpdatableBase)
	{
		updtList.push(addMe);
		addMe.parent = this;
	}
	
	public function removeSelf()
	{
		parent.removeUpdt(name);
	}
}