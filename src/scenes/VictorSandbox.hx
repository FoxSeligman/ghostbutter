package scenes;

import updatables.*;
import com.haxepunk.utils.Key;
import com.haxepunk.graphics.Image;
import entities.*;

class VictorSandbox extends MainScene
{
	public override function begin()
	{
		super.begin();
		createMap("maps/vic.tmx", "graphics/bricks.png", "Wall");
		var test : Ghost;
		test = new Ghost("Test");
		test.graphic = Image.createRect(32, 32, 0xDDEEFF);
		test.setHitbox(32,32);
		test.addUpdt(new Gravity(50, 15));
		test.addUpdt(new PlayerControlled(Key.UP,Key.DOWN,Key.LEFT,Key.RIGHT,Key.O,Key.P));
		
		var box : Crate;
		box = new Crate();
		
		add(box);
		add(test);
	}
	
	
}