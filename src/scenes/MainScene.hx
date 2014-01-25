package scenes;

import com.haxepunk.HXP;
import com.haxepunk.Scene;
import com.haxepunk.graphics.Image;
import com.haxepunk.Entity;
import com.haxepunk.utils.Draw;
import com.haxepunk.graphics.Text;
import com.haxepunk.tmx.TmxEntity;
import com.haxepunk.tmx.TmxMap;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;

class MainScene extends Scene
{
	public override function begin()
	{
		Input.define("andrew", [Key.SPACE]);
		Input.define("victor", [Key.V]);
	}
	
	public override function update()
	{
		super.update();
		if(Input.check("andrew"))
		{
			HXP.scene = new scenes.AndrewScene();
		}
		else if(Input.check("victor"))
		{
			HXP.scene = new scenes.VictorSandbox();
		}
	}
	
	public function createMap(path:String, graphicPath:String, collidableLayerName:String)
	{
		// Load the map data into an entity.
		var e = new TmxEntity(path);

		// Specify the tileset and layers to use.
		e.loadGraphic(graphicPath, [collidableLayerName]);

		// Treat the 'Wall' layer as collidable.
		e.loadMask(collidableLayerName, collidableLayerName);

		// Add to world.
		add(e);
	}
}