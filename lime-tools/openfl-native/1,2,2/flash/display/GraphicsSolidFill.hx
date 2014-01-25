package flash.display;


import flash.Lib;


class GraphicsSolidFill extends IGraphicsData {
	
	
	public function new (color:Int = 0, alpha:Float = 1.0) {
		
		super (lime_graphics_solid_fill_create (color, alpha));
		
	}
	
	
	private static var lime_graphics_solid_fill_create = Lib.load ("lime", "lime_graphics_solid_fill_create", 2);
	
	
}