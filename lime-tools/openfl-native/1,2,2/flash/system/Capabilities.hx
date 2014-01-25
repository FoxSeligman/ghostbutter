package flash.system;


import flash.Lib;


class Capabilities {
	
	
	public static var language (get, null):String;
	public static var pixelAspectRatio (get, null):Float;
	public static var screenDPI (get, null):Float;
	public static var screenResolutions (get, null):Array<Array<Int>>;
	public static var screenResolutionX (get, null):Float;
	public static var screenResolutionY (get, null):Float;
	
	
	
	
	// Getters & Setters
	
	
	
	
	private static function get_language():String {
		
		var locale:String = lime_capabilities_get_language ();
		
		if (locale == null || locale == "" || locale == "C" || locale == "POSIX") {
			
			return "en-US";
			
		} else {
			
			var formattedLocale = "";
			var length = locale.length;
			
			if (length > 5) {
				
				length = 5;
				
			}
			
			for (i in 0...length) {
				
				var char = locale.charAt (i);
				
				if (i < 2) {
					
					formattedLocale += char.toLowerCase ();
					
				} else if (i == 2) {
					
					formattedLocale += "-";
					
				} else {
					
					formattedLocale += char.toUpperCase ();
					
				}
				
			}
			
			return formattedLocale;
			
		}
		
	}
	
	
	private static function get_pixelAspectRatio ():Float { return lime_capabilities_get_pixel_aspect_ratio (); }
	private static function get_screenDPI ():Float { return lime_capabilities_get_screen_dpi (); }
	
	
	private static function get_screenResolutions ():Array<Array<Int>> {
		
		var res:Array<Int> = lime_capabilities_get_screen_resolutions ();
		
		if (res == null) {
			
			return new Array<Array<Int>> ();
			
		}
		
		var out = new Array<Array<Int>>();

		for (c in 0...Std.int (res.length / 2)) {
			
			out.push ([ res[ c * 2 ], res[ c * 2 + 1 ] ]);
			
		}
		
		return out;
		
	}
	
	
	private static function get_screenResolutionX ():Float { return lime_capabilities_get_screen_resolution_x (); }
	private static function get_screenResolutionY ():Float { return lime_capabilities_get_screen_resolution_y (); }
	
	
	
	
	// Native Methods
	
	
	
	
	private static var lime_capabilities_get_pixel_aspect_ratio = Lib.load ("lime", "lime_capabilities_get_pixel_aspect_ratio", 0);
	private static var lime_capabilities_get_screen_dpi = Lib.load ("lime", "lime_capabilities_get_screen_dpi", 0);
	private static var lime_capabilities_get_screen_resolution_x = Lib.load ("lime", "lime_capabilities_get_screen_resolution_x", 0);
	private static var lime_capabilities_get_screen_resolution_y = Lib.load ("lime", "lime_capabilities_get_screen_resolution_y", 0);
	private static var lime_capabilities_get_screen_resolutions = Lib.load ("lime", "lime_capabilities_get_screen_resolutions", 0 );
	private static var lime_capabilities_get_language = Lib.load ("lime", "lime_capabilities_get_language", 0);
	
	
}