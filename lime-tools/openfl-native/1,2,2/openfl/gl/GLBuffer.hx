package openfl.gl;


class GLBuffer extends GLObject {
	
	
	public function new (version:Int, id:Dynamic) {
		
		super (version, id);
		
	}
	
	
	override function getType ():String {
		
		return "Buffer";
		
	}
	
	
}