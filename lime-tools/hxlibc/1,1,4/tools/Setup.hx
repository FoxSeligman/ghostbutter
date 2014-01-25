package;


import haxe.io.Eof;
import helpers.LogHelper;
import sys.io.Process;
import sys.FileSystem;


class Setup {
	
	
	static function findAndroidNdkRoot (inDir:String) {
		
		var files:Array<String> = null;
		
		try {
			
			files = FileSystem.readDirectory (inDir);
			
		} catch (e:Dynamic) {
			
			LogHelper.error ('ANDROID_NDK_DIR "$inDir" does not point to a valid directory');
			
		}
		
		var extract_version = ~/^android-ndk-r(\d+)([a-z]?)$/;
		var bestMajor = 0;
		var bestMinor = "";
		var result = "";
		
		for (file in files) {
			
			if (extract_version.match (file)) {
				
				var major = Std.parseInt (extract_version.matched (1));
				var minor = extract_version.matched (2);
				
				if (major > bestMajor || (major == bestMajor && minor > bestMinor)) {
					
					bestMajor = major;
					bestMinor = minor;
					result = inDir + "/" + file;
					
				}
				
			}
			
		}
		
		if (Tools.verbose) {
			
			var message = "Found NDK " + result;
			Sys.println (message);
			
		}
		
		if (result == "") {
			
			LogHelper.error ('ANDROID_NDK_DIR "$inDir" does not contain matching NDK downloads'); 
			
		}
		
		return result;
		
	}
	
	
	public static function initHXCPPConfig (ioDefines:Map<String, String>) {
		
		var env = Sys.environment ();
		
		// If the user has set it themselves, they mush know what they are doing...
		if (env.exists("HXCPP_CONFIG")) {
			
			return;
			
		}
		
		var home = "";
		
		if (env.exists ("HOME")) {
			
			home = env.get ("HOME");
			
		} else if (env.exists ("USERPROFILE")) {
			
			home = env.get ("USERPROFILE");
			
		} else {
			
			Sys.println ("Warning: No 'HOME' variable set - .hxcpp_config.xml might be missing.");
			return;
			
		}
		
		var  config = toPath (home + "/.hxcpp_config.xml");
		ioDefines.set ("HXCPP_CONFIG", config);
		
		if (Tools.HXCPP != "") {
			
			var src = toPath (Tools.HXCPP + "/toolchain/example.hxcpp_config.xml");
			
			if (!FileSystem.exists (config)) {
				
				try {
					
					if (Tools.verbose) {
						
						Sys.println ("Copy config: " + src + " -> " + config);
						
					}
					
					sys.io.File.copy (src, config);
					
				} catch (e:Dynamic) {
					
					Sys.println ("Warning : could not create config: " + config);
					
				}
				
			}
			
		}
		
	}
	
	
	public static function isRaspberryPi () {
		
		var proc = new Process ("uname", [ "-a" ]);
		var str = proc.stdout.readLine ();
		proc.close ();
		
		return str.split (" ")[1] == "raspberrypi";
		
	}
	
	
	public static function getNdkVersion (inDirName:String):Int {
		
		var extract_version = ~/android-ndk-r(\d+)*/;
		
		if (extract_version.match (inDirName)) {
			
			return Std.parseInt (extract_version.matched (1));
			
		}
		
		//throw 'Could not deduce NDK version from "$inDirName"';
		return 8;
		
	}
	
	
	public static function setup (inWhat:String, ioDefines: Map<String, String>) {
		
		if (inWhat == "androidNdk") {
			
			setupAndroidNdk (ioDefines);
			
		} else if (inWhat == "msvc") {
			
			setupMSVC (ioDefines, ioDefines.exists ("HXCPP_M64"));
			
		} else {
			
			LogHelper.error ('Unknown setup feature "$inWhat"');
			
		}
		
	}
	
	
	public static function setupAndroidNdk (defines:Map <String, String>) {
		
		if (!defines.exists ("ANDROID_NDK_ROOT")) {
			
			if (defines.exists ("ANDROID_NDK_DIR")) {
				
				var root = Setup.findAndroidNdkRoot (defines.get ("ANDROID_NDK_DIR"));
				
				if (Tools.verbose) {
					
					Sys.println ("Using found ndk root " + root);
					
				}
				
				Sys.putEnv ("ANDROID_NDK_ROOT", root);
				defines.set ("ANDROID_NDK_ROOT", root);
				
			} else {
				
				LogHelper.error ("Could not find ANDROID_NDK_ROOT or ANDROID_NDK_DIR variable");
				
			}
			
		} else {
			
			if (Tools.verbose) {
				
				Sys.println ("Using specified ndk root " + defines.get ("ANDROID_NDK_ROOT"));
				
			}
			
		}
		
		var found = false;
		
		for (i in 6...20) {
			
			if (defines.exists("NDKV" + i)) {
				
				found = true;
				if (Tools.verbose) {
					
					Sys.println ("Using specified android NDK " + i);
					
				}
				
				break;
				
			}
			
		}
		
		if (!found) {
			
			var version = Setup.getNdkVersion (defines.get ("ANDROID_NDK_ROOT"));
			
			if (Tools.verbose) {
				
				Sys.println ("Deduced android NDK " + version);
				
			}
			
			defines.set ("NDKV" + version, "1");
			
		}
		
	}
	
	
	public static function setupBlackBerryNativeSDK (ioDefines:Map<String, String>) {
		
		if (ioDefines.exists ("BLACKBERRY_NDK_ROOT") && (!ioDefines.exists ("QNX_HOST") || !ioDefines.exists ("QNX_TARGET"))) {
			
			var fileName = ioDefines.get ("BLACKBERRY_NDK_ROOT");
			
			if (Tools.isWindows) {
				
				fileName += "\\bbndk-env.bat";
				
			} else {
				
				fileName += "/bbndk-env.sh";
				
			}
			
			if (FileSystem.exists (fileName)) {
				
				var fin = sys.io.File.read (fileName, false);
				
				try {
					
					while (true) {
						
						var str = fin.readLine ();
						var split = str.split ("=");
						var name = StringTools.trim (split[0].substr (split[0].lastIndexOf (" ") + 1));
						
						switch (name) {
							
							case "QNX_HOST", "QNX_TARGET", "QNX_HOST_VERSION", "QNX_TARGET_VERSION":
								
								var value = split[1];
								
								if (StringTools.startsWith (value, "${") && split.length > 2) {
									
									value = split[2].substr (0, split[2].length - 1);
									
								}
								
								if (StringTools.startsWith (value, "\"")) {
									
									value = value.substr (1);
									
								}
								
								if (StringTools.endsWith (value, "\"")) {
									
									value = value.substr (0, value.length - 1);
									
								}
								
								if (name == "QNX_HOST_VERSION" || name == "QNX_TARGET_VERSION") {
									
									if (Sys.getEnv (name) != null) {
										
										continue;
										
									}
									
								} else {
									
									value = StringTools.replace (value, "$QNX_HOST_VERSION", Sys.getEnv ("QNX_HOST_VERSION"));
									value = StringTools.replace (value, "$QNX_TARGET_VERSION", Sys.getEnv ("QNX_TARGET_VERSION"));
									value = StringTools.replace (value, "%QNX_HOST_VERSION%", Sys.getEnv ("QNX_HOST_VERSION"));
									value = StringTools.replace (value, "%QNX_TARGET_VERSION%", Sys.getEnv ("QNX_TARGET_VERSION"));
									
								}
								
								ioDefines.set (name, value);
								Sys.putEnv (name, value);
							
						}
						
					}
					
				} catch (ex:Eof) { }
				
				fin.close ();
				
			}
			
		}
		
	}
	
	
	public static function setupMSVC (ioDefines:Map <String, String>, in64:Bool) {
		
		if (!ioDefines.exists ("NO_AUTO_MSVC")) {
			
			var extra = in64 ? "64" : "";
			var xpCompat = false;
			
			if (ioDefines.exists ("HXCPP_WINXP_COMPAT")) {
				
				Sys.putEnv ("HXCPP_WINXP_COMPAT", "1");
				xpCompat = true;
				
			}
			
			var vc_setup_proc = new Process ("cmd.exe", [ "/C", Tools.HXCPP + "\\toolchain\\msvc" + extra + "-setup.bat" ]);
			var vars_found = false;
			var error_found = false;
			var output = new Array<String> ();
			
			try {
				
				while (true) {
					
					var str = vc_setup_proc.stdout.readLine ();
					
					if (str == "HXCPP_VARS") {
						
						vars_found = true;
						
					} else if (!vars_found) {
						
						if (str.substr (0, 5) == "Error" || ~/missing/.match (str)) {
							
							error_found = true;
							
						}
						
						output.push (str);
						
					} else {
						
						var pos = str.indexOf ("=");
						var name = str.substr (0, pos);
						
						switch (name.toLowerCase ()) {
							
							case "path", "vcinstalldir", "windowssdkdir", "framework35version", "frameworkdir", "frameworkdir32", "frameworkversion", "frameworkversion32", "devenvdir", "include", "lib", "libpath", "hxcpp_xp_define":
								
								var value = str.substr (pos + 1);
								ioDefines.set (name, value);
								Sys.putEnv (name, value);
							
						}
						
					}
					
				}
				
			} catch (e:Dynamic) { }
			
			vc_setup_proc.close ();
			
			if (!vars_found || error_found) {
				
				for (o in output) {
					
					Sys.println (o);
					
				}
				
				LogHelper.error ("Could not automatically setup MSVC");
				
			}
			
		}
		
		try {
			
			var proc = new Process ("cl.exe", []);
			var str = proc.stderr.readLine ();
			proc.close ();
			
			if (str > "") {
				
				var reg = ~/Version\s+(\d+)/i;
				
				if (reg.match (str)) {
					
					var cl_version = Std.parseInt (reg.matched (1));
					
					if (Tools.verbose) {
						
						Sys.println("Using msvc cl version " + cl_version);
						
					}
					
					ioDefines.set ("MSVC_VER", cl_version + "");
					
					if (cl_version >= 17) {
						
						ioDefines.set ("MSVC17+", "1");
						
					}
					
					if (cl_version >= 18) {
						
						ioDefines.set ("MSVC18+", "1");
						
					}
					
					Tools.sAllowNumProcs = (cl_version >= 14);
					
					if (Std.parseInt (ioDefines.get("HXCPP_COMPILE_THREADS")) > 1 && cl_version >= 18) {
						
						ioDefines.set ("HXCPP_FORCE_PDB_SERVER", "1");
						
					}
					
					//Sys.println ("Using cl version: " + cl_version);
					
				}
				
			}
			
		} catch (e:Dynamic) { }
		
	}
	
	
	private static function toPath (inPath:String) {
		
		if (!Tools.isWindows) {
			
			return inPath;
			
		}
		
		var bits = inPath.split ("/");
		return bits.join ("\\");
		
	}
	
	
}