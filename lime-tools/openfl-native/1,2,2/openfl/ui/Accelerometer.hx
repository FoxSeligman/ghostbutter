package openfl.ui;


import flash.Lib;


class Accelerometer {
	
	
	public static function get ():Acceleration {
		
		return lime_input_get_acceleration ();
		
	}
	
	
	private static var lime_input_get_acceleration = Lib.load ("lime", "lime_input_get_acceleration", 0);
	
	
}