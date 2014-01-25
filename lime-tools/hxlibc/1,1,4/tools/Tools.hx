package;


import haxe.io.Path;
import haxe.xml.Fast;
import helpers.LogHelper;
import helpers.PathHelper;
import helpers.ProcessHelper;
import project.Haxelib;
import sys.io.Process;
import sys.FileSystem;

#if cpp
import cpp.vm.Mutex;
import cpp.vm.Thread;
#elseif neko
import neko.vm.Mutex;
import neko.vm.Thread;
#end


class Tools {
	
	
	public static var sAllowNumProcs = true;
	public static var HXCPP = "";
	public static var verbose = false;
	public static var isWindows = false;
	public static var isLinux = false;
	public static var isMac = false;
	
	private static var mVarMatch = new EReg ("\\${(.*?)}", "");
	
	private var mDefines:Map<String, String>;
	private var mIncludePath:Array<String>;
	private var mCompiler:Compiler;
	private var mStripper:Stripper;
	private var mLinkers:Map <String, Linker>;
	private var mFileGroups:Map <String, FileGroup>;
	private var mTargets:Map <String, Target>;
	
	
	public function new (inMakefile:String, inDefines:Map<String, String>, inTargets:Array<String>, inIncludePath:Array<String>) {
		
		mDefines = inDefines;
		mFileGroups = new Map<String, FileGroup> ();
		mCompiler = null;
		mStripper = null;
		mTargets = new Map<String, Target> ();
		mLinkers = new Map<String, Linker> ();
		mIncludePath = inIncludePath;
		var make_contents = sys.io.File.getContent (inMakefile);
		var xml_slow = Xml.parse (make_contents);
		var xml = new Fast (xml_slow.firstElement ());
		
		parseXML (xml, "");
		
		if (mTargets.exists ("default")) {
			
			buildTarget ("default");
			
		} else {
			
			for (target in inTargets) {
				
				buildTarget (target);
				
			}
			
		}
		
	}
	
	
	public function buildTarget (inTarget:String) {
		
		// Sys.println("Build : " + inTarget );
		if (!mTargets.exists(inTarget)) {
			
			LogHelper.error ("Could not find build target \"" + inTarget + "\"");
			
		}
		
		if (mCompiler == null) {
			
			LogHelper.error ("No compiler defined for the current build target");
			
		}
		
		var target = mTargets.get (inTarget);
		target.checkError ();
		
		for (sub in target.mSubTargets) {
			
			buildTarget (sub);
			
		}
		
		var threads = 1;
		
		// Old compiler can't use multi-threads because of pdb conflicts
		if (sAllowNumProcs) {
			
			var thread_var = mDefines.exists ("HXCPP_COMPILE_THREADS") ? mDefines.get ("HXCPP_COMPILE_THREADS") : Sys.getEnv ("HXCPP_COMPILE_THREADS");
			
			if (thread_var != null) {
				
				threads = Std.parseInt (thread_var) < 2 ? 1 : Std.parseInt (thread_var);
				
			} else {
				
				threads = ProcessHelper.processorCores;
				
			}
			
		}
		
		// Sys.println("Using " + threads + " threads.");
		
		var objs = new Array<String> ();
		
		for (group in target.mFileGroups) {
			
			group.checkOptions (mCompiler.mObjDir);
			group.checkDependsExist ();
			group.preBuild ();
			
			var to_be_compiled = new Array<File> ();
			
			for (file in group.mFiles) {
				
				var path = new Path (mCompiler.mObjDir + "/" + file.mName);
				var obj_name = path.dir + "/" + path.file + mCompiler.mExt;
				PathHelper.mkdir (path.dir);
				objs.push (obj_name);
				
				if (file.isOutOfDate (obj_name)) {
					
					to_be_compiled.push (file);
					
				}
				
			}
			
			if (group.mPrecompiledHeader != "") {
				
				if (to_be_compiled.length > 0) {
					
					mCompiler.precompile (mCompiler.mObjDir, group.mPrecompiledHeader, group.mPrecompiledHeaderDir, group);
					
				}
				
				if (mCompiler.needsPchObj ()) {
					
					var pchDir = group.getPchDir ();
					
					if (pchDir != "") {
						
						objs.push (mCompiler.mObjDir + "/" + pchDir + "/" + group.mPrecompiledHeader + mCompiler.mExt);
						
					}
					
				}
				
			}
		
			if (threads < 2) {
				
				for (file in to_be_compiled) {
					
					mCompiler.compile (file);
					
				}
				
			} else {
				
				var mutex = new Mutex ();
				var main_thread = Thread.current ();
				var compiler = mCompiler;
				
				for (t in 0...threads) {
					
					Thread.create (function() {
						
						try {
							
							while (true) {
								
								mutex.acquire ();
								
								if (to_be_compiled.length == 0) {
									
									mutex.release ();
									break;
									
								}
								
								var file = to_be_compiled.shift ();
								mutex.release ();
								compiler.compile (file);
								
							}
							
						} catch (error:Dynamic) {
							
							main_thread.sendMessage ("Error");
							
						}
						
						main_thread.sendMessage ("Done");
						
					});
					
				}
				
				// Wait for theads to finish...
				for (t in 0...threads) {
					
					var result = Thread.readMessage (true);
					if (result == "Error") {
						
						Sys.exit (1);
						//throw "Error in building thread";
						
					}
					
				}
				
			}
			
		}
		
		switch (target.mTool) {
			
			case "linker":
				
				if (!mLinkers.exists (target.mToolID)) {
					
					LogHelper.error ("Could not find linker for \"" + target.mToolID + "\"");
					
				}
				
				var exe = mLinkers.get (target.mToolID).link (target, objs);
				
				if (exe != "" && mStripper != null) {
					
					if (target.mToolID == "exe" || target.mToolID == "dll") {
						
						mStripper.strip (exe);
						
					}
					
				}
			
			case "clean":
				
				target.clean ();
			
		}
		
	}
	
	
	public function createCompiler (inXML:Fast, inBase:Compiler):Compiler {
		
		var c = inBase;
		
		if (inBase == null || inXML.has.replace) {
			
			c = new Compiler (substitute (inXML.att.id), substitute (inXML.att.exe), mDefines.exists ("USE_GCC_FILETYPES"));
			
			if (mDefines.exists ("USE_PRECOMPILED_HEADERS")) {
				
				c.setPCH (mDefines.get ("USE_PRECOMPILED_HEADERS"));
				
			}
			
		}
		
		for (el in inXML.elements) {
			
			if (valid (el, "")) {
				
				switch (el.name) {
					
					case "flag": c.mFlags.push (substitute (el.att.value));
					case "cflag": c.mCFlags.push (substitute (el.att.value));
					case "cppflag": c.mCPPFlags.push (substitute (el.att.value));
					case "objcflag": c.mOBJCFlags.push (substitute (el.att.value));
					case "mmflag": c.mMMFlags.push (substitute (el.att.value));
					case "pchflag": c.mPCHFlags.push (substitute (el.att.value));
					case "objdir": c.mObjDir = substitute ((el.att.value));
					case "outflag": c.mOutFlag = substitute ((el.att.value));
					case "exe": c.mExe = substitute ((el.att.name));
					case "ext": c.mExt = substitute ((el.att.value));
					case "pch": c.setPCH (substitute ((el.att.value)));
					case "section": createCompiler (el, c);
					
					case "include":
						
						var name = substitute (el.att.name);
						var full_name = findIncludeFile (name);
						
						if (full_name != "") {
							
							var make_contents = sys.io.File.getContent (full_name);
							var xml_slow = Xml.parse (make_contents);
							createCompiler (new Fast (xml_slow.firstElement ()), c);
							
						} else if (!el.has.noerror) {
							
							LogHelper.error ("Could not find include file \"" + name + "\"");
							
						}
					
					default:
						
						LogHelper.error ("Unknown compiler option \"" + el.name + "\"");
					
				}
				
			}
			
		}
		
		return c;
		
	}
	
	
	public function createFileGroup (inXML:Fast, inFiles:FileGroup, inName:String):FileGroup {
		
		var dir = inXML.has.dir ? substitute (inXML.att.dir) : ".";
		var group = (inFiles == null ? new FileGroup (dir, inName) : inFiles);
		
		for (el in inXML.elements) {
			
			if (valid (el, "")) {
				
				switch (el.name) {
					
					case "file" :
						
						var file = new File (substitute (el.att.name), group);
						
						for (f in el.elements) {
							
							if (valid (f, "") && f.name == "depend") {
								
								file.mDepends.push (substitute (f.att.name));
								
							}
							
						}
						
						group.mFiles.push (file);
					
					case "depend": group.addDepend (substitute (el.att.name));
					case "hlsl": group.addHLSL (substitute (el.att.name), substitute (el.att.profile), substitute (el.att.variable), substitute (el.att.target));
					case "options": group.addOptions (substitute(el.att.name) );
					case "compilerflag": group.addCompilerFlag (substitute (el.att.value));
					
					case "compilervalue":
						
						group.addCompilerFlag (substitute (el.att.name));
						group.addCompilerFlag (substitute (el.att.value));
					
					case "precompiledheader":
						
						group.setPrecompiled (substitute (el.att.name), substitute (el.att.dir));
					
				}
				
			}
			
		}
		
		return group;
		
	}
	
	
	public function createLinker (inXML:Fast, inBase:Linker):Linker {
		
		var l = (inBase != null && !inXML.has.replace) ? inBase : new Linker (inXML.att.exe);
		
		for (el in inXML.elements) {
			
			if (valid (el, "")) {
				
				switch (el.name) {
					
					case "flag": l.mFlags.push (substitute (el.att.value));
					case "ext": l.mExt = (substitute (el.att.value));
					case "outflag": l.mOutFlag = (substitute (el.att.value));
					case "libdir": l.mLibDir = (substitute (el.att.name));
					case "lib": l.mLibs.push (substitute (el.att.name) );
					case "prefix": l.mNamePrefix = substitute (el.att.value);
					case "ranlib": l.mRanLib = (substitute (el.att.name));
					case "recreate": l.mRecreate = (substitute (el.att.value)) != "";
					case "fromfile": l.mFromFile = (substitute (el.att.value));
					case "exe": l.mExe = (substitute (el.att.name));
					case "section": createLinker (el, l);
					
				}
				
			}
			
		}
		
		return l;
		
	}
	
	
	public function createStripper (inXML:Fast, inBase:Stripper):Stripper {
		
		var s = (inBase != null && !inXML.has.replace) ? inBase : new Stripper (inXML.att.exe);
		
		for (el in inXML.elements) {
			
			if (valid (el, "")) {
				
				switch (el.name) {
					
					case "flag": s.mFlags.push (substitute (el.att.value));
					case "exe": s.mExe = substitute ((el.att.name));
					
				}
				
			}
			
		}
		
		return s;
		
	}
	
	
	public function createTarget (inXML:Fast):Target {
		
		var output = inXML.has.output ? substitute (inXML.att.output) : "";
		var tool = inXML.has.tool ? inXML.att.tool : "";
		var toolid = inXML.has.toolid ? substitute (inXML.att.toolid) : "";
		var target = new Target (output, tool, toolid);
		
		for (el in inXML.elements) {
			
			if (valid (el, "")) {
				
				switch (el.name) {
					
					case "target": target.mSubTargets.push (substitute (el.att.id));
					case "lib": target.mLibs.push (substitute (el.att.name));
					case "flag": target.mFlags.push (substitute (el.att.value));
					case "depend": target.mDepends.push (substitute (el.att.name));
					
					case "vflag":
						
						target.mFlags.push (substitute (el.att.name));
						target.mFlags.push (substitute (el.att.value));
					
					case "dir": target.mDirs.push (substitute (el.att.name));
					case "outdir": target.mOutputDir = substitute (el.att.name) + "/";
					case "ext": target.mExt = (substitute (el.att.value));
					
					case "files":
						
						var id = el.att.id;
						if (!mFileGroups.exists (id)) {
							
							target.addError ("Could not find filegroup " + id);
							
						} else {
							
							target.addFiles (mFileGroups.get (id));
							
						}
					
				}
				
			}
			
		}
		
		return target;
		
	}
	
	
	public function defined (inString:String):Bool {
		
		return mDefines.exists (inString);
		
	}
	
	
	private function findIncludeFile (inBase:String):String {
		
		if (inBase == null || inBase == "") return "";
		
		if (StringTools.startsWith (inBase, HXCPP) && StringTools.endsWith (inBase, "BuildCommon.xml")) {
			
			inBase = HXCPP + "/toolchain/BuildCommon.xml";
			
		}
		
		var c0 = inBase.substr (0,1);
		
		if (c0 != "/" && c0 != "\\") {
			
			var c1 = inBase.substr (1, 1);
			
			if (c1 != ":") {
				
				for (p in mIncludePath) {
					
					var name = p + "/" + inBase;
					if (FileSystem.exists (name)) {
						
						return name;
						
					}
					
				}
				
				return "";
				
			}
			
		}
		
		if (FileSystem.exists (inBase)) {
			
			return inBase;
			
		}
		
		return "";
		
	}
	
	
	// Setting HXCPP_COMPILE_THREADS to 2x number or cores can help with hyperthreading
	
	
	
	// Process args and environment.
	public static function main () {
		
		var targets = new Array<String> ();
		var defines = new Map<String, String> ();
		var include_path = new Array<String> ();
		var makefile:String = "";
		
		include_path.push (".");
		
		var args = Sys.args ();
		// Check for calling from haxelib ...
		
		if (args.length > 0) {
			
			var last:String = (new Path (args[args.length - 1])).toString ();
			var slash = last.substr ( -1);
			
			if (slash == "/" || slash == "\\") {
				
				last = last.substr (0, last.length - 1);
				
			}
			
			if (FileSystem.exists (last) && FileSystem.isDirectory (last)) {
				
				// When called from haxelib, the last arg is the original directory, and
				//  the current direcory is the library directory.
				HXCPP = PathHelper.standardize (Sys.getCwd ());
				defines.set ("HXCPP", HXCPP);
				args.pop ();
				Sys.setCwd (last);
				
			}
			
		}
		
		var os = Sys.systemName ();
		isWindows = (new EReg ("window", "i")).match (os);
		
		if (isWindows) {
			
			defines.set ("windows_host", "1");
			
		}
		
		isMac = (new EReg ("mac", "i")).match (os);
		
		if (isMac) {
			
			defines.set ("mac_host", "1");
			
		}
		
		isLinux = (new EReg ("linux", "i")).match (os);
		
		if (isLinux) {
			
			defines.set ("linux_host", "1");
			
		}
		
		var isRPi = isLinux && Setup.isRaspberryPi ();
		
		for (arg in args) {
			
			if (arg.substr (0, 2) == "-D") {
				
				var val = arg.substr (2);
				var equals = val.indexOf ("=");
				
				if (equals > 0) {
					
					defines.set (val.substr (0, equals), val.substr (equals + 1));
					
				} else {
					
					defines.set (val, "");
					
				}
				
				if (val == "verbose") {
					
					verbose = true;
					
				}
				
			}
			
			if (arg.substr (0, 2) == "-I") {
				
				include_path.push (arg.substr (2));
				
			} else if (makefile.length == 0) {
				
				makefile = arg;
				
			} else {
				
				targets.push (arg);
				
			}
			
		}
		
		Setup.initHXCPPConfig (defines);
		
		var env = Sys.environment ();
		
		if (HXCPP == "" && env.exists ("HXCPP")) {
			
			HXCPP = PathHelper.standardize (env.get ("HXCPP"));
			defines.set ("HXCPP", HXCPP);
			
		}
		
		if (HXCPP == "") {
			
			if (!defines.exists ("HXCPP")) {
				
				LogHelper.error ("Please run hxlibc using haxelib");
				
			}
			
			HXCPP = PathHelper.standardize (defines.get ("HXCPP"));
			defines.set ("HXCPP", HXCPP);
			
		}
		
		include_path.push (".");
		
		if (env.exists ("HOME")) {
			
			include_path.push (env.get ("HOME"));
			
		}
		
		if (env.exists ("USERPROFILE")) {
			
			include_path.push (env.get ("USERPROFILE"));
			
		}
		
		include_path.push (HXCPP + "/toolchain");
		
		var m64 = defines.exists ("HXCPP_M64");
		var msvc = false;
		
		if (defines.exists ("emulator")) {
			
			defines.set ("simulator", "simulator");
			
		}
		
		if (defines.exists ("ios")) {
			
			if (defines.exists ("simulator")) {
				
				defines.set ("iphonesim", "iphonesim");
				
			} else if (!defines.exists ("iphonesim")) {
				
				defines.set ("iphoneos", "iphoneos");
				
			}
			
			defines.set ("iphone", "iphone");
			
		}
		
		if (defines.exists ("toolchain")) {
			
			if (!defines.exists ("BINDIR")) {
				
				defines.set ("BINDIR", Path.withoutDirectory (Path.withoutExtension (defines.get ("toolchain"))));
				
			}
			
		} else if (defines.exists ("iphoneos")) {
			
			defines.set ("toolchain", "iphoneos");
			defines.set ("iphone", "iphone");
			defines.set ("apple", "apple");
			defines.set ("BINDIR", "iPhone");
			
		} else if (defines.exists ("iphonesim")) {
			
			defines.set ("toolchain", "iphonesim");
			defines.set ("iphone", "iphone");
			defines.set ("apple", "apple");
			defines.set ("BINDIR", "iPhone");
			
		} else if (defines.exists ("android")) {
			
			defines.set ("toolchain", "android");
			defines.set ("android", "android");
			defines.set ("BINDIR", "Android");
			
			if (!defines.exists ("ANDROID_HOST")) {
				
				if ((new EReg ("mac", "i")).match (os)) {
					
					defines.set ("ANDROID_HOST", "darwin-x86");
					
				} else if ((new EReg ("window", "i")).match (os)) {
					
					defines.set ("ANDROID_HOST", "windows");
					
				} else if ((new EReg ("linux", "i")).match (os)) {
					
					defines.set ("ANDROID_HOST", "linux-x86");
					
				} else {
					
					LogHelper.error ("Unknown android host \"" + os + "\"");
					
				}
				
			}
			
		} else if (defines.exists ("webos")) {
			
			defines.set ("toolchain", "webos");
			defines.set ("webos", "webos");
			defines.set ("BINDIR", "webOS");
			
		} else if (defines.exists ("blackberry")) {
			
			if (defines.exists ("simulator")) {
				
				defines.set ("toolchain", "blackberry-x86");
				
			} else {
				
				defines.set ("toolchain", "blackberry");
				
			}
			
			defines.set ("blackberry", "blackberry");
			defines.set ("BINDIR", "BlackBerry");
			
		} else if (defines.exists ("emcc") || defines.exists ("emscripten")) {
			
			defines.set ("toolchain", "emscripten");
			defines.set ("emcc", "emcc");
			defines.set ("emscripten", "emscripten");
			defines.set ("BINDIR", "Emscripten");
			
		} else if (defines.exists ("tizen")) {
			
			if (defines.exists ("simulator")) {
				
				defines.set ("toolchain", "tizen-x86");
				
			} else {
				
				defines.set ("toolchain", "tizen");
				
			}
			
			defines.set ("tizen", "tizen");
			defines.set ("BINDIR", "Tizen");
			
		} else if (defines.exists ("gph")) {
			
			defines.set ("toolchain", "gph");
			defines.set ("gph", "gph");
			defines.set ("BINDIR", "GPH");
			
		} else if (defines.exists ("mingw") || env.exists ("HXCPP_MINGW")) {
			
			defines.set ("toolchain", "mingw");
			defines.set ("mingw", "mingw");
			defines.set ("BINDIR", m64 ? "Windows64" : "Windows");
			
		} else if (defines.exists ("cygwin") || env.exists ("HXCPP_CYGWIN")) {
			
			defines.set ("toolchain", "cygwin");
			defines.set ("cygwin", "cygwin");
			defines.set ("linux", "linux");
			defines.set ("BINDIR", m64 ? "Cygwin64" : "Cygwin");
			
		} else if ((new EReg ("window", "i")).match (os)) {
			
			defines.set ("toolchain", "msvc");
			defines.set ("windows", "windows");
			msvc = true;
			
			if (defines.exists ("winrt")) {
				
				defines.set ("BINDIR", m64 ? "WinRTx64" : "WinRTx86");
				
			} else {
				
				defines.set ("BINDIR", m64 ? "Windows64" : "Windows");
				
			}
			
		} else if (isRPi) {
			
			defines.set ("toolchain", "linux");
			defines.set ("linux", "linux");
			defines.set ("rpi", "1");
			defines.set ("hardfp", "1");
			defines.set ("BINDIR", "RPi");
			
		} else if ((new EReg ("linux", "i")).match (os)) {
			
			defines.set ("toolchain", "linux");
			defines.set ("linux", "linux");
			defines.set ("BINDIR", m64 ? "Linux64" : "Linux");
			
		} else if ((new EReg ("mac", "i")).match (os)) {
			
			defines.set ("toolchain", "mac");
			defines.set ("macos", "macos");
			defines.set ("apple", "apple");
			defines.set ("BINDIR", m64 ? "Mac64" : "Mac");
			
		}
		
		if (defines.exists ("dll_import")) {
			
			var path = new Path (defines.get ("dll_import"));
			
			if (!defines.exists ("dll_import_include")) {
				
				defines.set ("dll_import_include", path.dir + "/include");
				
			}
			
			if (!defines.exists ("dll_import_link")) {
				
				defines.set ("dll_import_link", defines.get ("dll_import"));
				
			}
			
		}
		
		if (defines.exists ("apple") && !defines.exists ("DEVELOPER_DIR")) {
			
			var proc = new Process ("xcode-select", [ "--print-path" ]);
			var developer_dir = proc.stdout.readLine ();
			proc.close ();
			
			if (developer_dir == null || developer_dir == "" || developer_dir.indexOf ("Run xcode-select") > -1) {
				
			 	developer_dir = "/Applications/Xcode.app/Contents/Developer";
				
			}
			
			if (developer_dir == "/Developer") {
				
				defines.set ("LEGACY_XCODE_LOCATION", "1");
				
			}
			
			defines.set ("DEVELOPER_DIR", developer_dir);
			
		}
		
		if (defines.exists ("iphone") && !defines.exists ("IPHONE_VER")) {
			
			var dev_path = defines.get ("DEVELOPER_DIR") + "/Platforms/iPhoneOS.platform/Developer/SDKs/";
			
			if (FileSystem.exists (dev_path)) {
				
				var best = "";
				var files = FileSystem.readDirectory (dev_path);
				var extract_version = ~/^iPhoneOS(.*).sdk$/;
				
				for (file in files) {
					
					if (extract_version.match (file)) {
						
						var ver = extract_version.matched (1);
						
						if (Std.parseFloat (ver) > Std.parseFloat (best)) {
							
							best = ver;
							
						}
						
					}
					
				}
				
				if (best != "") {
					
					defines.set ("IPHONE_VER", best);
					
				}
				
			}
			
		}
		
		if (defines.exists ("macos") && !defines.exists ("MACOSX_VER")) {
			
			var dev_path = defines.get ("DEVELOPER_DIR") + "/Platforms/MacOSX.platform/Developer/SDKs/";
			
			if (FileSystem.exists (dev_path)) {
				
				var best="";
				var files = FileSystem.readDirectory (dev_path);
				var extract_version = ~/^MacOSX(.*).sdk$/;
				
				for (file in files) {
					
					if (extract_version.match (file)) {
						
						var ver = extract_version.matched (1);
						
						if (Std.parseFloat (ver) > Std.parseFloat (best)) {
							
							best = ver;
							
						}
						
					}
					
				}
				
				if (best != "") {
					
					defines.set ("MACOSX_VER", best);
					
				}
				
			}
			
		}
		
		if (!FileSystem.exists (defines.get ("DEVELOPER_DIR") + "/Platforms/MacOSX.platform/Developer/SDKs/")) {
			
			defines.set ("LEGACY_MACOSX_SDK", "1");
			
		}
		
		if (targets.length == 0) {
			
			targets.push ("default");
			
		}
		
		if (makefile == "") {
			
			Sys.println ("Usage :  BuildTool makefile.xml [-DFLAG1] ...  [-DFLAGN] ... [target1]...[targetN]");
			
		} else {
			
			for (e in env.keys ()) {
				
				defines.set (e, Sys.getEnv (e));
				
			}
			
			new Tools (makefile, defines, targets, include_path);
			
		}
		
	}
	
	
	private function parseXML (inXML:Fast, inSection:String) {
		
		for (el in inXML.elements) {
			
			if (valid (el, inSection)) {
				
				switch (el.name) {
					
					case "set":
						
						var name = el.att.name;
						var value = substitute (el.att.value);
						mDefines.set (name, value);
						
						if (name == "BLACKBERRY_NDK_ROOT") {
							
							Setup.setupBlackBerryNativeSDK (mDefines);
							
						}
						
					case "unset":
						
						var name = el.att.name;
						mDefines.remove (name);
					
					case "setup":
						
						var name = substitute (el.att.name);
						Setup.setup (name, mDefines);
					
					case "echo":
						
						Sys.println (substitute (el.att.value));
					
					case "setenv":
						
						var name = el.att.name;
						var value = substitute (el.att.value);
						mDefines.set (name, value);
						Sys.putEnv (name, value);
					
					case "error":
						
						var error = substitute (el.att.value);
						LogHelper.error (error);
					
					case "path":
						
						var path = substitute (el.att.name);
						var os = Sys.systemName ();
						var sep = mDefines.exists ("windows_host") ? ";" : ":";
						
						Sys.putEnv ("PATH", path + sep + Sys.getEnv ("PATH"));
						//trace(Sys.getEnv("PATH"));
					
					case "compiler":
						
						mCompiler = createCompiler (el, mCompiler);
					
					case "stripper":
						
						mStripper = createStripper (el, mStripper);
					
					case "linker":
						
						if (mLinkers.exists (el.att.id)) {
							
							createLinker (el, mLinkers.get (el.att.id));
							
						} else {
							
							mLinkers.set (el.att.id, createLinker (el, null));
							
						}
					
					case "files":
						
						var name = el.att.id;
						
						if (mFileGroups.exists (name)) {
							
							createFileGroup (el, mFileGroups.get (name), name);
							
						} else {
							
							mFileGroups.set (name, createFileGroup (el, null, name));
							
						}
					
					case "include":
						
						var name = substitute (el.att.name);
						var full_name = findIncludeFile (name);
						
						if (full_name != "") {
							
							var make_contents = sys.io.File.getContent (full_name);
							var xml_slow = Xml.parse (make_contents);
							var section = el.has.section ? el.att.section : "";
							
							parseXML (new Fast (xml_slow.firstElement ()), section);
							
						} else if (!el.has.noerror) {
							
							LogHelper.error ("Could not find include file \"" + name + "\"");
							
						}
					
					case "target":
						
						var name = el.att.id;
						mTargets.set (name, createTarget (el));
					
					case "section" : 
						
						parseXML (el, "");
					
				}
				
			}
			
		}
		
	}
	
	
	public function substitute (str:String):String {
		
		while (mVarMatch.match (str)) {
			
			var sub = mVarMatch.matched (1);
			
			if (sub.substr (0, 8) == "haxelib:") {
				
				var path = PathHelper.getHaxelib (new Haxelib (sub.substr (8)), true);
				
				sub = PathHelper.standardize (path);
				
			} else {
				
				sub = mDefines.get (sub);
				
			}
			
			if (sub == null) {
				
				sub = "";
				
			}
			
			str = mVarMatch.matchedLeft () + sub + mVarMatch.matchedRight ();
			
		}
		
		return str;
		
	}
	
	
	public function valid (element:Fast, section:String):Bool {
		
		if (element.x.get ("if") != null) {
			
			var value = element.x.get ("if");
			var optionalDefines = value.split ("||");
			var matchOptional = false;
			
			for (optional in optionalDefines) {
				
				var requiredDefines = optional.split (" ");
				var matchRequired = true;
				
				for (required in requiredDefines) {
					
					var check = StringTools.trim (required);
					
					if (check != "" && !defined (check)) {
						
						matchRequired = false;
						
					}
					
				}
				
				if (matchRequired) {
					
					matchOptional = true;
					
				}
				
			}
			
			if (optionalDefines.length > 0 && !matchOptional) {
				
				return false;
				
			}
			
		}
		
		if (element.has.unless) {
			
			var value = substitute (element.att.unless);
			var optionalDefines = value.split ("||");
			var matchOptional = false;
			
			for (optional in optionalDefines) {
				
				var requiredDefines = optional.split (" ");
				var matchRequired = true;
				
				for (required in requiredDefines) {
					
					var check = StringTools.trim (required);
					
					if (check != "" && !defined (check)) {
						
						matchRequired = false;
						
					}
					
				}
				
				if (matchRequired) {
					
					matchOptional = true;
					
				}
				
			}
			
			if (optionalDefines.length > 0 && matchOptional) {
				
				return false;
				
			}
			
		}
		
		if (section != "") {
			
			if (element.name != "section" || !element.has.id || substitute (element.att.id) != section) {
				
				return false;
				
			}
			
		}
		
		return true;
		
	}
	
	
}