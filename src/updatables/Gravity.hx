package updatables;

import updatables.Velocity;
import com.haxepunk.Entity;
import com.haxepunk.utils.Input;
import com.haxepunk.HXP;

class Gravity extends UpdatableBase
{
	public var gravityForce : Float;
	public var myVelocity : Velocity;
	public var terminalVelocity:Float;
	
	public function new(gF:Float, tV:Float)
	{
		gravityForce = gF;
		terminalVelocity = tV;
		super("Gravity");
	}
	
	public override function update()
	{
		if(myVelocity != null)
		{
			myVelocity.velocityY += gravityForce * HXP.elapsed;
			
			if(myVelocity.velocityY > terminalVelocity)
			{
				myVelocity.velocityY = terminalVelocity;
			}
		}
		else
		{
			for(uB in parent.updtList)
			{
				if(uB.name == "Velocity")
				{
					myVelocity = cast(uB,Velocity);
					break;
				}
			}
		}
		super.update();
	}
}