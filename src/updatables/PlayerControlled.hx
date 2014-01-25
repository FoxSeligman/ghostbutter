package updatables;

import com.haxepunk.utils.Input;

class PlayerControlled extends UpdatableBase
{	
	public function new(up:Int,down:Int,left:Int,right:Int,act1:Int,act2:Int)
	{
		super("PlayerControlled");
		Input.define("up", [up]);
		Input.define("down", [down]);
		Input.define("left", [left]);
		Input.define("right", [right]);
		Input.define("act1", [act1]);
		Input.define("act2", [act2]);
	}
	
	public override function update()
	{
		if(Input.check("up"))
		{
			parent.upTrigger();
		}
		if(Input.check("down"))
		{
			parent.downTrigger();
		}
		if(Input.check("left"))
		{
			parent.leftTrigger();
		}
		if(Input.check("right"))
		{
			parent.rightTrigger();
		}
		if(Input.check("act1"))
		{
			parent.action1Trigger();
		}
		if(Input.check("act2"))
		{
			parent.action2Trigger();
		}
		
		super.update();
	}
}