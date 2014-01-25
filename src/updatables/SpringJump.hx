package updatables;

import com.haxepunk.utils.Input;
import com.haxepunk.HXP;

class SpringJump extends UpdatableBase
{
	private var releaseButton : String;
	private var timeOfCompression : Float;
	private var velocityPerSecond : Float;
	
	public function new(rB:String)
	{
		super("SpringJump");
		releaseButton = rB;
		timeOfCompression = HXP._systemTime;
		
		velocityPerSecond = 20;
	}
	
	public override function update()
	{
		if(!Input.check(releaseButton))
		{
			trace("jump!");
			parent.removeUpdt("SpringJump");
			
		}
		
		super.update();
	}
}