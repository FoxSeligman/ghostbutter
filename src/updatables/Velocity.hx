package updatables;

import com.haxepunk.Entity;
import com.haxepunk.HXP;

class Velocity extends UpdatableBase
{
	public var velocityX : Float;
	public var velocityY : Float;
	
	public var collideList : Array<String>;
	
	public function new(cL)
	{
		collideList = cL;
		velocityX = 0;
		velocityY = 10;
		
		super("Velocity");
	}
	
	public override function update()
	{	
		trace(velocityY);
		parent.moveBy(velocityX*HXP.elapsed, velocityY*HXP.elapsed, collideList);
		super.update();
	}
}