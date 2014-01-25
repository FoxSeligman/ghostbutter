package entities;

import updatables.Gravity;
import updatables.DieOnCollide;
import updatables.UpdatableBase;
import updatables.Velocity;

import com.haxepunk.Entity;
import com.haxepunk.graphics.Image;

class Movement extends UpdatableBase
{
	var myVelocity : Velocity;
	
	public function new()
	{
		super("Movement");	
	}
	
	public override function upTrigger()
	{
		
	}
}