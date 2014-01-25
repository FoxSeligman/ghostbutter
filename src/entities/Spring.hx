package entities;

import updatables.UpdatableBase;
import com.haxepunk.Entity;
import updatables.*;

class Spring extends UpdatableBase
{	
	
	
	public override function moveCollideY(e:Entity)
	{
		trace("moo");
		return true;
	}
	
	public override function update()
	{
		super.update();
	}
	
	public override function upTrigger()
	{
		
	}
	
	public override function downTrigger()
	{
		
	}
	
	public override function leftTrigger()
	{
		
	}
	
	public override function rightTrigger()
	{
		
	}
	
	public override function action1Trigger()
	{
		for(u in updtList)
		{
			if(u.name == "SpringJump")
			{
				return;
			}
		}
		addUpdt(new SpringJump("act1"));
	}
	
	public override function action2Trigger()
	{
	
	}
}