package entities;

import updatables.Gravity;
import updatables.DieOnCollide;
import updatables.UpdatableBase;
import updatables.Velocity;

import com.haxepunk.Entity;
import com.haxepunk.graphics.Image;

class Crate extends UpdatableBase
{
	public function new()
	{
		super("Crate");
		graphic = Image.createRect(32, 32, 0xDDEEFF);
		setHitbox(32,32);
		
		x = 128;
		
		addUpdt(new Velocity(["wall"]));
		addUpdt(new Gravity(50, 200));
		addUpdt(new DieOnCollide([]));		
	}
	
	public override function moveCollideY(e:Entity)
	{
		super.moveCollideY(e);
		
		return true;
	}
}