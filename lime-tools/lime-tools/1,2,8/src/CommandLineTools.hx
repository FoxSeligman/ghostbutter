package;


import flash.text.Font;
import flash.utils.ByteArray;
import flash.utils.CompressionAlgorithm;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.rtti.Meta;
import helpers.*;
import platforms.*;
import project.*;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
import utils.CreateTemplate;
import utils.JavaExternGenerator;
import utils.PlatformSetup;
	
	
class CommandLineTools {
	
	
	private var additionalArguments:Array <String>;
	private var command:String;
	private var debug:Bool;
	private var includePaths:Array <String>;
	private var overrides:HXProject;
	private var project:HXProject;
	private var projectDefines:Map <String, String>;
	private var targetFlags:Map <String, String>;
	private var traceEnabled:Bool;
	private var userDefines:Map <String, Dynamic>;
	private var version:String;
	private var words:Array <String>;
	
	
	public function new () {
		
		additionalArguments = new Array <String> ();
		command = "";
		debug = false;
		includePaths = new Array <String> ();
		projectDefines = new Map <String, String> ();
		targetFlags = new Map <String, String> ();
		traceEnabled = true;
		userDefines = new Map <String, Dynamic> ();
		words = new Array <String> ();
		
		overrides = new HXProject ();
		overrides.architectures = [];
		
		processArguments ();
		version = getVersion ();
		
		if (LogHelper.verbose && command != "") {
			
			displayInfo ();
			Sys.println ("");
			
		}
		
		switch (command) {
			
			case "":
				
				displayInfo (true);
			
			case "help":
				
				displayHelp ();
			
			case "setup":
				
				platformSetup ();
			
			case "document":
				
				document ();
			
			case "generate":
				
				generate ();
			
			case "compress":
				
				compress ();
			
			case "create":
				
				createTemplate ();
				
			case "install", "remove", "upgrade":
				
				updateLibrary ();
			
			case "clean", "update", "display", "build", "run", "rerun", /*"install",*/ "uninstall", "trace", "test":
				
				if (words.length < 1 || words.length > 2) {
					
					LogHelper.error ("Incorrect number of arguments for command '" + command + "'");
					return;
					
				}
				
				buildProject ();
			
			case "installer", "copy-if-newer":
				
				// deprecated?
			
			default:
				
				LogHelper.error ("'" + command + "' is not a valid command");
			
		}
		
	}
	
	
	private function buildProject () {
		
		var project = initializeProject ();
		var platform:IPlatformTool = null;
		
		LogHelper.info ("", "\x1b[32;1mUsing target platform: " + project.target + "\x1b[0m");
		
		switch (project.target) {
			
			case ANDROID:
				
				platform = new AndroidPlatform ();
				
			case BLACKBERRY:
				
				platform = new BlackBerryPlatform ();
			
			case IOS:
				
				platform = new IOSPlatform ();
			
			case TIZEN:
				
				platform = new TizenPlatform ();
			
			case WEBOS:
				
				platform = new WebOSPlatform ();
			
			case WINDOWS:
				
				platform = new WindowsPlatform ();
			
			case MAC:
				
				platform = new MacPlatform ();
			
			case LINUX:
				
				platform = new LinuxPlatform ();
			
			case FLASH:
				
				platform = new FlashPlatform ();
			
			case HTML5:
				
				platform = new HTML5Platform ();
			
			case EMSCRIPTEN:
				
				platform = new EmscriptenPlatform ();
			
		}
		
		var metaFields = Meta.getFields (Type.getClass (platform));
		
		if (platform != null) {
			
			var command = project.command.toLowerCase ();
			
			if (!Reflect.hasField (metaFields.display, "ignore") && (command == "display")) {
				
				platform.display (project);
				
			}
			
			if (!Reflect.hasField (metaFields.clean, "ignore") && (command == "clean" || targetFlags.exists ("clean"))) {
				
				LogHelper.info ("", "\n\x1b[32;1mRunning command: CLEAN\x1b[0m");
				platform.clean (project);
				
			}
			
			if (!Reflect.hasField (metaFields.update, "ignore") && (command == "update" || command == "build" || command == "test")) {
				
				LogHelper.info ("", "\n\x1b[32;1mRunning command: UPDATE\x1b[0m");
				AssetHelper.processLibraries (project);
				platform.update (project);
				
			}
			
			if (!Reflect.hasField (metaFields.build, "ignore") && (command == "build" || command == "test")) {
				
				LogHelper.info ("", "\n\x1b[32;1mRunning command: BUILD\x1b[0m");
				platform.build (project);
				
			}
			
			if (!Reflect.hasField (metaFields.install, "ignore") && (command == "install" || command == "run" || command == "test")) {
				
				LogHelper.info ("", "\n\x1b[32;1mRunning command: INSTALL\x1b[0m");
				platform.install (project);
				
			}
		
			if (!Reflect.hasField (metaFields.run, "ignore") && (command == "run" || command == "rerun" || command == "test")) {
				
				LogHelper.info ("", "\n\x1b[32;1mRunning command: RUN\x1b[0m");
				platform.run (project, additionalArguments);
				
			}
		
			if (!Reflect.hasField (metaFields.trace, "ignore") && (command == "test" || command == "trace")) {
				
				if (traceEnabled || command == "trace") {
					
					LogHelper.info ("", "\n\x1b[32;1mRunning command: TRACE\x1b[0m");
					platform.trace (project);
					
				}
				
			}
			
		}
		
	}
	
	
	private function compress () { 
		
		if (words.length > 0) {
			
			//var bytes = new ByteArray ();
			//bytes.writeUTFBytes (words[0]);
			//bytes.compress (CompressionAlgorithm.LZMA);
			//Sys.print (bytes.toString ());
			//File.saveBytes (words[0] + ".compress", bytes);
			
		}
		
	}
	
	
	private function createTemplate () {
		
		LogHelper.info ("", "\x1b[32;1mRunning command: CREATE\x1b[0m");
		
		if (words.length > 0) {
			
			var projectName = words[0].substring (0, words[0].indexOf (":"));
			var sampleName = words[0].substr (words[0].indexOf (":") + 1);
			
			if (sampleName == "project") {
				
				CreateTemplate.createProject (words, userDefines);
				
			} else if (sampleName == "extension") {
				
				CreateTemplate.createExtension (words, userDefines);
				
			} else {
				
				if (projectName == "") {
					
					if (FileSystem.exists (PathHelper.combine (PathHelper.getHaxelib (new Haxelib ("lime")), "samples/" + sampleName))) {
						
						CreateTemplate.createSample (words, userDefines);
						
					} else if (PathHelper.getHaxelib (new Haxelib (sampleName)) != "") {
						
						CreateTemplate.listSamples (sampleName, userDefines);
						
					} else {
						
						CreateTemplate.listSamples ("lime", userDefines);
						
					}
					
				} else {
					
					CreateTemplate.createSample (words, userDefines);
					
				}
				
			}
			
		} else {
			
			CreateTemplate.listSamples ("lime", userDefines);
			
		}
		
	}
	
	
	private function document ():Void {
	
	
	}
	
	
	private function ascii (text:String):String {
		
		if (PlatformHelper.hostPlatform != Platform.WINDOWS) {
			
			return text;
			
		}
		
		return "";
		
	}
	
	
	private function displayHelp ():Void {
		
		displayInfo ();
		
		LogHelper.println ("");
		LogHelper.println (" \x1b[32;1mUsage:\x1b[0m \x1b[1mlime\x1b[0m setup \x1b[3;37m(target)\x1b[0m");
		LogHelper.println (" \x1b[32;1mUsage:\x1b[0m \x1b[1mlime\x1b[0m clean|update|build|run|test|display \x1b[3;37m<project>\x1b[0m (target) \x1b[3;37m[options]\x1b[0m");
		LogHelper.println (" \x1b[32;1mUsage:\x1b[0m \x1b[1mlime\x1b[0m create library:template \x1b[3;37m(directory)\x1b[0m");
		LogHelper.println (" \x1b[32;1mUsage:\x1b[0m \x1b[1mlime\x1b[0m rebuild \x1b[3;37m<extension>\x1b[0m (target)\x1b[3;37m,(target),...\x1b[0m");
		LogHelper.println (" \x1b[32;1mUsage:\x1b[0m \x1b[1mlime\x1b[0m install|remove|upgrade <library>");
		LogHelper.println (" \x1b[32;1mUsage:\x1b[0m \x1b[1mlime\x1b[0m help");
		LogHelper.println ("");
		LogHelper.println (" \x1b[32;1mCommands:\x1b[0m ");
		LogHelper.println ("");
		LogHelper.println ("  \x1b[1msetup\x1b[0m -- Setup Lime or a specific target");
		LogHelper.println ("  \x1b[1mclean\x1b[0m -- Remove the target build directory if it exists");
		LogHelper.println ("  \x1b[1mupdate\x1b[0m -- Copy assets for the specified project/target");
		LogHelper.println ("  \x1b[1mbuild\x1b[0m -- Compile and package for the specified project/target");
		LogHelper.println ("  \x1b[1mrun\x1b[0m -- Install and run for the specified project/target");
		LogHelper.println ("  \x1b[1mtest\x1b[0m -- Update, build and run in one command");
		LogHelper.println ("  \x1b[1mdisplay\x1b[0m -- Display information for the specified project/target");
		LogHelper.println ("  \x1b[1mcreate\x1b[0m -- Create a new project or extension using templates");
		LogHelper.println ("  \x1b[1mrebuild\x1b[0m -- Recompile native binaries for extensions");
		LogHelper.println ("  \x1b[1minstall\x1b[0m -- Install a library from haxelib, plus dependencies");
		LogHelper.println ("  \x1b[1mremove\x1b[0m -- Remove a library from haxelib");
		LogHelper.println ("  \x1b[1mupgrade\x1b[0m -- Upgrade a library from haxelib");
		LogHelper.println ("  \x1b[1mhelp\x1b[0m -- Show this information");
		LogHelper.println ("");
		LogHelper.println (" \x1b[32;1mTargets:\x1b[0m ");
		LogHelper.println ("");
		LogHelper.println ("  \x1b[1mandroid\x1b[0m -- Create an Android application");
		LogHelper.println ("  \x1b[1mblackberry\x1b[0m -- Create a BlackBerry application");
		LogHelper.println ("  \x1b[1memscripten\x1b[0m -- Create an Emscripten application");
		LogHelper.println ("  \x1b[1mflash\x1b[0m -- Create a Flash SWF application");
		LogHelper.println ("  \x1b[1mhtml5\x1b[0m -- Create an HTML5 canvas application");
		LogHelper.println ("  \x1b[1mios\x1b[0m -- Create an iOS application");
		LogHelper.println ("  \x1b[1mlinux\x1b[0m -- Create a Linux application");
		LogHelper.println ("  \x1b[1mmac\x1b[0m -- Create a Mac OS X application");
		LogHelper.println ("  \x1b[1mtizen\x1b[0m -- Create a Tizen application");
		LogHelper.println ("  \x1b[1mwebos\x1b[0m -- Create a webOS application");
		LogHelper.println ("  \x1b[1mwindows\x1b[0m -- Create a Windows application");
		LogHelper.println ("");
		LogHelper.println (" \x1b[32;1mOptions:\x1b[0m ");
		LogHelper.println ("");
		LogHelper.println ("  \x1b[1m-D\x1b[0;3mvalue\x1b[0m -- Specify a define to use when processing other commands");
		LogHelper.println ("  \x1b[1m-debug\x1b[0m -- Use debug configuration instead of release");
		LogHelper.println ("  \x1b[1m-verbose\x1b[0m -- Print additional information (when available)");
		LogHelper.println ("  \x1b[1m-clean\x1b[0m -- Add a \"clean\" action before running the current command");
		LogHelper.println ("  \x1b[1m-xml\x1b[0m -- Generate XML type information, useful for documentation");
		LogHelper.println ("  \x1b[3m(windows|mac|linux)\x1b[0m \x1b[1m-neko\x1b[0m -- Build with Neko instead of C++");
		LogHelper.println ("  \x1b[3m(mac|linux)\x1b[0m \x1b[1m-32\x1b[0m -- Compile for 32-bit instead of the OS default");
		LogHelper.println ("  \x1b[3m(mac|linux)\x1b[0m \x1b[1m-64\x1b[0m -- Compile for 64-bit instead of the OS default");
		LogHelper.println ("  \x1b[3m(ios|blackberry|tizen|webos)\x1b[0m \x1b[1m-simulator\x1b[0m -- Target the device simulator");
		LogHelper.println ("  \x1b[3m(ios)\x1b[0m \x1b[1m-simulator -ipad\x1b[0m -- Build/test for the iPad Simulator");
		LogHelper.println ("  \x1b[3m(android)\x1b[0m \x1b[1m-emulator\x1b[0m -- Target the device emulator");
		LogHelper.println ("  \x1b[3m(html5)\x1b[0m \x1b[1m-minify\x1b[0m -- Minify output using the Google Closure compiler");
		LogHelper.println ("  \x1b[3m(html5)\x1b[0m \x1b[1m-minify -yui\x1b[0m -- Minify output using the YUI compressor");
		LogHelper.println ("");
		LogHelper.println (" \x1b[32;1mProject Overrides:\x1b[0m ");
		LogHelper.println ("");
		LogHelper.println ("  \x1b[1m--app-\x1b[0;3moption=value\x1b[0m -- Override a project <app/> setting");
		LogHelper.println ("  \x1b[1m--meta-\x1b[0;3moption=value\x1b[0m -- Override a project <meta/> setting");
		LogHelper.println ("  \x1b[1m--window-\x1b[0;3moption=value\x1b[0m -- Override a project <window/> setting");
		LogHelper.println ("  \x1b[1m--dependency\x1b[0;3m=value\x1b[0m -- Add an additional <dependency/> value");
		LogHelper.println ("  \x1b[1m--haxedef\x1b[0;3m=value\x1b[0m -- Add an additional <haxedef/> value");
		LogHelper.println ("  \x1b[1m--haxeflag\x1b[0;3m=value\x1b[0m -- Add an additional <haxeflag/> value");
		LogHelper.println ("  \x1b[1m--haxelib\x1b[0;3m=value\x1b[0m -- Add an additional <haxelib/> value");
		LogHelper.println ("  \x1b[1m--source\x1b[0;3m=value\x1b[0m -- Add an additional <source/> value");
		LogHelper.println ("  \x1b[1m--certificate-\x1b[0;3moption=value\x1b[0m -- Override a project <certificate/> setting");
		
	}
	
	
	private function displayInfo (showHint:Bool = false):Void {
		
		if (PlatformHelper.hostPlatform == Platform.WINDOWS) {
			
			LogHelper.println ("");
			
		}
		
		LogHelper.println ("\x1b[32;1m |. _ _  _");
		LogHelper.println (" ||| | ||_|");
		LogHelper.println (" ||| | ||_.\x1b[0m");
		
		if (PlatformHelper.hostPlatform == Platform.WINDOWS) {
			
			LogHelper.println ("");
			
		}
		
		//Sys.println ("  __      ");
		//Sys.println ("  \\ \\  __  __ _ _  ____");
		//Sys.println ("   \\ \\ \\ \\ \\ \\ \\ \\ \\ -_\\");
		//Sys.println ("    \\_\\ \\_\\ \\_\\_\\_\\ \\__\\");
		
		LogHelper.println ("\x1b[102m\x1b[1mLime Command-Line Tools\x1b[0;1m (" + version + ")\x1b[0m");
		
		
		if (showHint) {
			
			LogHelper.println ("Use \x1b[3mlime setup\x1b[0m to configure Lime or \x1b[3mlime help\x1b[0m for more commands");
			
		}
		
	}
	
	
	private function findProjectFile (path:String):String {
		
		if (FileSystem.exists (PathHelper.combine (path, "project.hxp"))) {
			
			return PathHelper.combine (path, "project.hxp");
			
		} else if (FileSystem.exists (PathHelper.combine (path, "project.lime"))) {
			
			return PathHelper.combine (path, "project.lime");
			
		} else if (FileSystem.exists (PathHelper.combine (path, "project.nmml"))) {
			
			return PathHelper.combine (path, "project.nmml");
			
		} else if (FileSystem.exists (PathHelper.combine (path, "project.xml"))) {
			
			return PathHelper.combine (path, "project.xml");
			
		} else {
			
			var files = FileSystem.readDirectory (path);
			var matches = new Map <String, Array <String>> ();
			matches.set ("hxp", []);
			matches.set ("lime", []);
			matches.set ("nmml", []);
			matches.set ("xml", []);
			
			for (file in files) {
				
				var path = PathHelper.combine (path, file);
				
				if (FileSystem.exists (path) && !FileSystem.isDirectory (path)) {
					
					var extension = Path.extension (file);
					
					if ((extension == "lime" && file != "include.lime") || (extension == "nmml" && file != "include.nmml") || (extension == "xml" && file != "include.xml") || extension == "hxp") {
						
						matches.get (extension).push (path);
						
					}
					
				}
				
			}
			
			if (matches.get ("hxp").length > 0) {
				
				return matches.get ("hxp")[0];
				
			}
			
			if (matches.get ("lime").length > 0) {
				
				return matches.get ("lime")[0];
				
			}
			
			if (matches.get ("nmml").length > 0) {
				
				return matches.get ("nmml")[0];
				
			}
			
			if (matches.get ("xml").length > 0) {
				
				return matches.get ("xml")[0];
				
			}
			
		}
		
		return "";
		
	}
	
	
	private function generate ():Void {
		
		if (targetFlags.exists ("font-hash")) {
			
			var sourcePath = words[0];
			var glyphs = "32-255";
			
			ProcessHelper.runCommand (Path.directory (sourcePath), "neko", [ PathHelper.getHaxelib (new Haxelib ("lime-tools")) + "/templates/bin/hxswfml.n", "ttf2hash2", Path.withoutDirectory (sourcePath), Path.withoutDirectory (sourcePath) + ".hash", "-glyphs", glyphs ]);
			
		} else if (targetFlags.exists ("font-details")) {
			
			var sourcePath = words[0];
			
			var details = Font.load (sourcePath);
			var json = Json.stringify (details);
			Sys.print (json);
			
		} else if (targetFlags.exists ("java-externs")) {
			
			var config = getHXCPPConfig ();
			var sourcePath = words[0];
			var targetPath = words[1];
			
			new JavaExternGenerator (config, sourcePath, targetPath);
			
		}
		
	}
	
	
	private function getBuildNumber (project:HXProject, increment:Bool = true):Void {
		
		if (project.meta.buildNumber == "1") {
			
			var versionFile = PathHelper.combine (project.app.path, ".build");
			var version = 1;
			
			PathHelper.mkdir (project.app.path);
			
			if (FileSystem.exists (versionFile)) {
				
				var previousVersion = Std.parseInt (File.getBytes (versionFile).toString ());
				
				if (previousVersion != null) {
					
					version = previousVersion;
					
					if (increment) {
						
						version ++;
						
					}
					
				}
				
			}
			
			project.meta.buildNumber = Std.string (version);
			
			try {
				
			   var output = File.write (versionFile, false);
			   output.writeString (Std.string (version));
			   output.close ();
				
			} catch (e:Dynamic) {}
			
		}
		
	}
	
	
	public static function getHXCPPConfig ():HXProject {
		
		var environment = Sys.environment ();
		var config = "";
		
		if (environment.exists ("HXCPP_CONFIG")) {
			
			config = environment.get ("HXCPP_CONFIG");
			
		} else {
			
			var home = "";
			
			if (environment.exists ("HOME")) {
				
				home = environment.get ("HOME");
				
			} else if (environment.exists ("USERPROFILE")) {
				
				home = environment.get ("USERPROFILE");
				
			} else {
				
				LogHelper.warn ("HXCPP config might be missing (Environment has no \"HOME\" variable)");
				
				return null;
				
			}
			
			config = home + "/.hxcpp_config.xml";
			
			if (PlatformHelper.hostPlatform == Platform.WINDOWS) {
				
				config = config.split ("/").join ("\\");
				
			}
			
		}
		
		if (FileSystem.exists (config)) {
			
			LogHelper.info ("", "\x1b[32;1mReading HXCPP config: " + config + "\x1b[0m");
			
			return new ProjectXMLParser (config);
			
		} else {
			
			LogHelper.warn ("", "Could not read HXCPP config: " + config);
			
		}
		
		return null;
		
	}
	
	
	private function getVersion ():String {
		
		var json = Json.parse (File.getContent (PathHelper.getHaxelib (new Haxelib ("lime-tools")) + "/haxelib.json"));
		return json.version;
		
	}
	
	
	#if (neko && (haxe_210 || haxe3))
	public static function __init__ () {
		
		var haxePath = Sys.getEnv ("HAXEPATH");
		var command = (haxePath != null && haxePath != "") ? haxePath + "/haxelib" : "haxelib";
		
		var process = new Process (command, [ "path", "lime-tools" ]);
		var path = "";
		
		try {
			
			var lines = new Array <String> ();
			
			while (true) {
				
				var length = lines.length;
				var line = process.stdout.readLine ();
				
				if (length > 0 && StringTools.trim (line) == "-D lime-tools") {
					
					path = StringTools.trim (lines[length - 1]);
					
				}
				
				lines.push (line);
         		
   			}
   			
		} catch (e:Dynamic) {
			
		}
		
		process.close ();
		path += "/ndll/";
		
		switch (PlatformHelper.hostPlatform) {
			
			case WINDOWS:
				
				untyped $loader.path = $array (path + "Windows/", $loader.path);
				
			case MAC:
				
				//if (PlatformHelper.hostArchitecture == Architecture.X64) {
					
					untyped $loader.path = $array (path + "Mac64/", $loader.path);
					
				//} else {
					
				//	untyped $loader.path = $array (path + "Mac/", $loader.path);
					
				//}
				
			case LINUX:
				
				var arguments = Sys.args ();
				var raspberryPi = false;
				
				for (argument in arguments) {
					
					if (argument == "-rpi") raspberryPi = true;
					
				}
				
				if (raspberryPi) {
					
					untyped $loader.path = $array (path + "RPi/", $loader.path);
					
				} else if (PlatformHelper.hostArchitecture == Architecture.X64) {
					
					untyped $loader.path = $array (path + "Linux64/", $loader.path);
					
				} else {
					
					untyped $loader.path = $array (path + "Linux/", $loader.path);
					
				}
			
			default:
			
		}
		
	}
	#end
	
	
	private function initializeProject ():HXProject {
		
		LogHelper.info ("", "\x1b[32;1mInitializing project...\x1b[0m");
		
		var projectFile = "";
		var targetName = "";
		
		if (words.length == 2) {
			
			if (FileSystem.exists (words[0])) {
				
				if (FileSystem.isDirectory (words[0])) {
					
					projectFile = findProjectFile (words[0]);
					
				} else {
					
					projectFile = words[0];
					
				}
				
			}
			
			targetName = words[1].toLowerCase ();
			
		} else {
			
			projectFile = findProjectFile (Sys.getCwd ());
			targetName = words[0].toLowerCase ();
			
		}
		
		if (projectFile == "") {
			
			LogHelper.error ("You must have a \"project.xml\" file or specify another valid project file when using the '" + command + "' command");
			return null;
			
		} else {
			
			LogHelper.info ("", "\x1b[32;1mUsing project file: " + projectFile + "\x1b[0m");
			
		}
		
		var target = null;
		
		switch (targetName) {
			
			case "cpp":
				
				target = PlatformHelper.hostPlatform;
				targetFlags.set ("cpp", "");
				
			case "neko":
				
				target = PlatformHelper.hostPlatform;
				targetFlags.set ("neko", "");
				
			case "iphone", "iphoneos":
				
				target = Platform.IOS;
				
			case "iphonesim":
				
				target = Platform.IOS;
				targetFlags.set ("simulator", "");
			
			default:
				
				try {
					
					target = Type.createEnum (Platform, targetName.toUpperCase ());
					
				} catch (e:Dynamic) {
					
					LogHelper.error ("\"" + targetName + "\" is an unknown target");
					
				}
			
		}
		
		var config = getHXCPPConfig ();
		
		if (PlatformHelper.hostPlatform == Platform.WINDOWS) {
			
			if (config != null && config.environment.exists ("JAVA_HOME")) {
				
				Sys.putEnv ("JAVA_HOME", config.environment.get ("JAVA_HOME"));
				
			}
			
			if (Sys.getEnv ("JAVA_HOME") != null) {
				
				var javaPath = PathHelper.combine (Sys.getEnv ("JAVA_HOME"), "bin");
				
				if (PlatformHelper.hostPlatform == Platform.WINDOWS) {
					
					Sys.putEnv ("PATH", javaPath + ";" + Sys.getEnv ("PATH"));
					
				} else {
					
					Sys.putEnv ("PATH", javaPath + ":" + Sys.getEnv ("PATH"));
					
				}
				
			}
			
		}
		
		HXProject._command = command;
		HXProject._debug = debug;
		HXProject._target = target;
		HXProject._targetFlags = targetFlags;
		
		try { Sys.setCwd (Path.directory (projectFile)); } catch (e:Dynamic) {}
		
		var project:HXProject = null;
		
		if (Path.extension (projectFile) == "lime" || Path.extension (projectFile) == "nmml" || Path.extension (projectFile) == "xml") {
			
			project = new ProjectXMLParser (Path.withoutDirectory (projectFile), userDefines, includePaths);
			
		} else if (Path.extension (projectFile) == "hxp") {
			
			project = HXProject.fromFile (projectFile, userDefines, includePaths);
			
			if (project != null) {
				
				project.command = command;
				project.debug = debug;
				project.target = target;
				project.targetFlags = targetFlags;
				
			} else {
				
				LogHelper.error ("Could not process \"" + projectFile + "\"");
				return null;
				
			}
			
		}
		
		if (project == null) {
			
			LogHelper.error ("You must have a \"project.xml\" file or specify another valid project file when using the '" + command + "' command");
			return null;
			
		}
		
		project.merge (config);
		
		project.haxedefs.set ("tools", version);
		
		/*if (userDefines.exists ("nme")) {
			
			project.haxedefs.set ("nme_install_tool", 1);
			project.haxedefs.set ("nme_ver", version);
			project.haxedefs.set ("nme" + version.split (".")[0], 1);
			
			project.config.cpp.buildLibrary = "hxcpp";
			project.config.cpp.requireBuild = false;
			
		}*/
		
		project.merge (overrides);
		
		if (overrides.architectures.length > 0) {
			
			project.architectures = overrides.architectures;
			
		}
		
		for (key in projectDefines.keys ()) {
			
			var components = key.split ("-");
			var field = components.shift ().toLowerCase ();
			var attribute = "";
			
			if (components.length > 0) {
				
				for (i in 1...components.length) {
					
					components[i] = components[i].substr (0, 1).toUpperCase () + components[i].substr (1).toLowerCase ();
					
				}
				
				attribute = components.join ("");
				
			}
			
			if (field == "template" && attribute == "path") {
				
				project.templatePaths.push (projectDefines.get (key));
				
			} else {
				
				if (Reflect.hasField (project, field)) {
					
					var fieldValue = Reflect.field (project, field);
					
					if (Reflect.hasField (fieldValue, attribute)) {
						
						if (Std.is (Reflect.field (fieldValue, attribute), String)) {
							
							Reflect.setField (fieldValue, attribute, projectDefines.get (key));
							
						} else if (Std.is (Reflect.field (fieldValue, attribute), Float)) {
							
							Reflect.setField (fieldValue, attribute, Std.parseFloat (projectDefines.get (key)));
							
						} else if (Std.is (Reflect.field (fieldValue, attribute), Bool)) {
							
							Reflect.setField (fieldValue, attribute, (projectDefines.get (key).toLowerCase () == "true" || projectDefines.get (key) == "1"));
							
						}
						
					}
					
				}
				
			}
			
		}
		
		StringMapHelper.copyKeys (userDefines, project.haxedefs);
		
		// Better way to do this?
		
		switch (project.target) {
			
			case ANDROID, IOS, BLACKBERRY:
				
				getBuildNumber (project);
				
			default:
			
		}
		
		return project;
		
	}
	
	
	public static function main ():Void {
		
		new CommandLineTools ();
		
	}
	
	
	private function processArguments ():Void {
		
		var arguments = Sys.args ();
		
		if (arguments.length > 0) {
			
			// When the command-line tools are called from haxelib, 
			// the last argument is the project directory and the
			// path to NME is the current working directory 
			
			var lastArgument = "";
			
			for (i in 0...arguments.length) {
				
				lastArgument = arguments.pop ();
				if (lastArgument.length > 0) break;
				
			}
			
			lastArgument = new Path (lastArgument).toString ();
			
			if (((StringTools.endsWith (lastArgument, "/") && lastArgument != "/") || StringTools.endsWith (lastArgument, "\\")) && !StringTools.endsWith (lastArgument, ":\\")) {
				
				lastArgument = lastArgument.substr (0, lastArgument.length - 1);
				
			}
			
			if (FileSystem.exists (lastArgument) && FileSystem.isDirectory (lastArgument)) {
				
				Sys.setCwd (lastArgument);
				
			}
			
		}
		
		var catchArguments = false;
		var catchHaxeFlag = false;
		
		for (argument in arguments) {

			var equals = argument.indexOf ("=");
			
			if (catchHaxeFlag) {
				
				overrides.haxeflags.push (argument);
				catchHaxeFlag = false;
				
			} else if (catchArguments) {
				
				additionalArguments.push (argument);
				
			} else if (equals > 0) {

				var argValue = argument.substr (equals + 1);
				// if quotes remain on the argValue we need to strip them off
				// otherwise the compiler really dislikes the result!
				var r = ~/^['"](.*)['"]$/;
				if (r.match(argValue)) {
					argValue = r.matched(1);
				}
				
				if (argument.substr (0, 2) == "-D") {
					
					userDefines.set (argument.substr (2, equals - 2), argValue);
					
				} else if (argument.substr (0, 2) == "--") {
					
					// this won't work because it assumes there is only ever one of these.
					//projectDefines.set (argument.substr (2, equals - 2), argValue);
					
					var field = argument.substr (2, equals - 2);
					
					if (field == "haxedef") {
						
						overrides.haxedefs.set (argValue, 1);
						
					} else if (field == "haxeflag") {
						
						overrides.haxeflags.push (argValue);
						
					} else if (field == "haxelib") {
						
						var name = argValue;
						var version = "";
						
						if (name.indexOf (":") > -1) {
							
							version = name.substr (name.indexOf (":") + 1);
							name = name.substr (0, name.indexOf (":"));
							
						}
						
						overrides.haxelibs.push (new Haxelib (name, version));
						
					} else if (field == "source") {
						
						overrides.sources.push (argValue);
						
					} else if (field == "dependency") {
						
						overrides.dependencies.push (new Dependency (argValue, ""));
						
					} else if (StringTools.startsWith (field, "certificate-")) {
						
						if (overrides.certificate == null) {
							
							overrides.certificate = new Keystore ();
							
						}
						
						field = StringTools.replace (field, "certificate-", "");
						
						if (field == "alias-password") field = "aliasPassword";
						
						if (Reflect.hasField (overrides.certificate, field)) {
							
							Reflect.setField (overrides.certificate, field, argValue);
							
						}
							
					} else if (StringTools.startsWith (field, "app-") || StringTools.startsWith (field, "meta-") || StringTools.startsWith (field, "window-")) {
						
						var split = field.split ("-");
						
						var fieldName = split[0];
						var property = split[1];
						
						for (i in 2...split.length) {
							
							property += split[i].substr (0, 1).toUpperCase () + split[i].substr (1, split[i].length - 1);
							
						}
						
						var fieldReference = Reflect.field (overrides, fieldName);
						
						if (Reflect.hasField (fieldReference, property)) {
							
							var propertyReference = Reflect.field (fieldReference, property);
							
							if (Std.is (propertyReference, Bool)) {
								
								Reflect.setField (fieldReference, property, argValue == "true");
								
							} else if (Std.is (propertyReference, Int)) {
								
								Reflect.setField (fieldReference, property, Std.parseInt (argValue));
								
							} else if (Std.is (propertyReference, Float)) {
								
								Reflect.setField (fieldReference, property, Std.parseFloat (argValue));
								
							} else if (Std.is (propertyReference, String)) {
								
								Reflect.setField (fieldReference, property, argValue);
								
							}
							
						}
						
					} else if (field == "build-library") {
						
						overrides.config.cpp.buildLibrary = argValue;
						
					} else {
						
						projectDefines.set (field, argValue);
						
					}
					
				} else {
					
					userDefines.set (argument.substr (0, equals), argValue);
					
				}
				
			} else if (argument.substr (0, 4) == "-arm") {
				
				var name = argument.substr (1).toUpperCase ();
				var value = Type.createEnum (Architecture, name);
				
				if (value != null) {
					
					overrides.architectures.push (value);
					
				}
				
			} else if (argument == "-64") {
				
				overrides.architectures.push (Architecture.X64);
				
			} else if (argument == "-32") {
				
				overrides.architectures.push (Architecture.X86);
				
			} else if (argument.substr (0, 2) == "-D") {
				
				userDefines.set (argument.substr (2), "");
				
			} else if (argument.substr (0, 2) == "-l") {
				
				includePaths.push (argument.substr (2));
				
			} else if (argument == "-v" || argument == "-verbose") {
				
				LogHelper.verbose = true;
				
			} else if (argument == "-args") {
				
				catchArguments = true;
				
			} else if (argument == "-notrace") {
				
				traceEnabled = false;
				
			} else if (argument == "-debug") {
				
				debug = true;
				
			} else if (command.length == 0) {
				
				command = argument;
				
			} else if (argument.substr (0, 1) == "-") {
				
				if (argument.substr (1, 1) == "-") {
					
					overrides.haxeflags.push (argument);
					
					if (argument == "--remap" || argument == "--connect") {
						
						catchHaxeFlag = true;
						
					}
					
				} else {
					
					targetFlags.set (argument.substr (1), "");
					
				}
				
			} else {
				
				words.push (argument);
				
			}
			
		}
		
	}
	
	
	private function platformSetup ():Void {
		
		LogHelper.info ("", "\x1b[32;1mRunning command: SETUP\x1b[0m");
		
		if (words.length == 0) {
			
			PlatformSetup.run ("", userDefines, targetFlags);
			
		} else if (words.length == 1) {
			
			PlatformSetup.run (words[0], userDefines, targetFlags);
			
		} else {
			
			LogHelper.error ("Incorrect number of arguments for command 'setup'");
			return;
			
		}
		
	}
	
	
	private function updateLibrary ():Void {
		
		if ((words.length < 1 && command != "upgrade") || words.length > 1) {
			
			LogHelper.error ("Incorrect number of arguments for command '" + command + "'");
			return;
			
		}
		
		LogHelper.info ("", "\x1b[32;1mRunning command: " + command.toUpperCase () + "\x1b[0m");
		
		var name = "lime";
		
		if (words.length > 0) {
			
			name = words[0];
			
		}
		
		var path = PathHelper.getHaxelib (new Haxelib (name));
		
		switch (command) {
			
			case "install":
				
				if (path == null || path == "") {
					
					var haxePath = Sys.getEnv ("HAXEPATH");
					ProcessHelper.runCommand (haxePath, "haxelib", [ "install", name ]);
					
				}
				
				PlatformSetup.run (name, userDefines, targetFlags);
			
			case "remove":
				
				if (path != null && path != "") {
					
					var haxePath = Sys.getEnv ("HAXEPATH");
					ProcessHelper.runCommand (haxePath, "haxelib", [ "remove", name ]);
					
				}
			
			case "upgrade":
				
				if (path != null && path != "") {
					
					var haxePath = Sys.getEnv ("HAXEPATH");
					ProcessHelper.runCommand (haxePath, "haxelib", [ "update", name ]);
					
					var defines = StringMapHelper.copy (userDefines);
					defines.set ("upgrade", 1);
					
					PlatformSetup.run (name, defines, targetFlags);
					
				}
			
		}
		
	}
	
	
}
