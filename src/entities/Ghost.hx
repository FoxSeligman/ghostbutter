package entities;

import updatables.UpdatableBase;
import com.haxepunk.Entity;

class Ghost extends UpdatableBase
{
	public override function moveCollideY(e:Entity)
	{
		trace("moo");
		return true;
	}
}