package platforms;


import flash.utils.ByteArray;
import flash.utils.CompressionAlgorithm;
import haxe.io.Path;
import haxe.Template;
import helpers.AssetHelper;
import helpers.CPPHelper;
import helpers.FileHelper;
import helpers.HTML5Helper;
import helpers.LogHelper;
import helpers.PathHelper;
import helpers.ProcessHelper;
import project.AssetType;
import project.HXProject;
import sys.io.File;
import sys.FileSystem;


class EmscriptenPlatform implements IPlatformTool {
	
	
	private var outputDirectory:String;
	private var outputFile:String;
	
	
	public function build (project:HXProject):Void {
		
		initialize (project);
		
		var hxml = outputDirectory + "/haxe/" + (project.debug ? "debug" : "release") + ".hxml";
		
		ProcessHelper.runCommand ("", "haxe", [ hxml, "-D", "emscripten", "-D", "webgl" ] );
		CPPHelper.compile (project, outputDirectory + "/obj", [ "-Demscripten", "-Dwebgl" ]);
		
		Sys.putEnv ("EMCC_LLVM_TARGET", "i386-pc-linux-gnu");
		
		ProcessHelper.runCommand ("", "emcc", [ outputDirectory + "/obj/Main.cpp", "-o", outputDirectory + "/obj/Main.o" ], true, false, true);
		
		var args = [ "Main.o" ];
		
		for (ndll in project.ndlls) {
			
			var path = PathHelper.getLibraryPath (ndll, "Emscripten", "", ".a", project.debug);
			args.push (path);
			
		}
		
		args = args.concat ([ "ApplicationMain" + (project.debug ? "-debug" : "") + ".a", "-o", "ApplicationMain.o" ]);
		ProcessHelper.runCommand (outputDirectory + "/obj", "emcc", args, true, false, true);
		
		args = [ "ApplicationMain.o", "-s", "FULL_ES2=1" ];
		
		if (project.targetFlags.exists ("asm")) {
			
			args.push ("-s");
			args.push ("ASM_JS=1");
			
		} else {
			
			args.push ("-s");
			args.push ("ASM_JS=0");
			args.push ("-s");
			args.push ("ALLOW_MEMORY_GROWTH=1");
			
		}
		
		if (!project.debug) {
			
			args.push ("-s");
			args.push ("DISABLE_EXCEPTION_CACHING=0");
			//args.push ("-s");
			//args.push ("OUTLINING_LIMIT=70000");
			
		} else {
			
			args.push ("-s");
			args.push ("DISABLE_EXCEPTION_CACHING=2");
			
		}
		
		if (!project.debug || project.targetFlags.exists ("asm")) {
			
			args.push ("-O2");
			
		} else {
			
			//args.push ("--minify");
			//args.push ("1");
			
		}
		
		if (project.targetFlags.exists ("minify")) {
			
			//args.push ("--minify");
			//args.push ("1");
			//args.push ("--closure");
			//args.push ("1");
			
		}
		
		//args.push ("--memory-init-file");
		//args.push ("1");
		//args.push ("--jcache");
		//args.push ("-g");
		
		if (FileSystem.exists (outputDirectory + "/obj/assets")) {
			
			args.push ("--preload-file");
			args.push ("assets");
			
		}
		
		if (LogHelper.verbose) args.push ("-v");
		
		//if (project.targetFlags.exists ("compress")) {
			//
			//args.push ("--compression");
			//args.push (PathHelper.findTemplate (project.templatePaths, "bin/utils/lzma/compress.exe") + "," + PathHelper.findTemplate (project.templatePaths, "resources/lzma-decoder.js") + ",LZMA.decompress");
			//args.push ("haxelib run openfl compress," + PathHelper.findTemplate (project.templatePaths, "resources/lzma-decoder.js") + ",LZMA.decompress");
			//args.push ("-o");
			//args.push ("../bin/index.html");
			//
		//} else {
			
			args.push ("-o");
			args.push ("../bin/" + project.app.file + ".js");
			
		//}
		
		//args.push ("../bin/index.html");
		
		ProcessHelper.runCommand (outputDirectory + "/obj", "emcc", args, true, false, true);
		
		if (project.targetFlags.exists ("minify")) {
			
			HTML5Helper.minify (project, outputDirectory + "/bin/" + project.app.file + ".js");
			
		}
		
		if (project.targetFlags.exists ("compress")) {
			
			if (FileSystem.exists (outputDirectory + "/bin/" + project.app.file + ".data")) {
				
				var byteArray = ByteArray.readFile (outputDirectory + "/bin/" + project.app.file + ".data");
				byteArray.compress (CompressionAlgorithm.GZIP);
				File.saveBytes (outputDirectory + "/bin/" + project.app.file + ".data.compress", byteArray);
				
			}
			
			var byteArray = ByteArray.readFile (outputDirectory + "/bin/" + project.app.file + ".js");
			byteArray.compress (CompressionAlgorithm.GZIP);
			File.saveBytes (outputDirectory + "/bin/" + project.app.file + ".js.compress", byteArray);
			
		} else {
			
			File.saveContent (outputDirectory + "/bin/.htaccess", "SetOutputFilter DEFLATE");
			
		}
		
	}
	
	
	public function clean (project:HXProject):Void {
		
		var targetPath = project.app.path + "/emscripten";
		
		if (FileSystem.exists (targetPath)) {
			
			PathHelper.removeDirectory (targetPath);
			
		}
		
	}
	
	
	public function display (project:HXProject):Void {
		
		initialize (project);
		
		var hxml = PathHelper.findTemplate (project.templatePaths, "emscripten/hxml/" + (project.debug ? "debug" : "release") + ".hxml");
		
		var context = project.templateContext;
		context.OUTPUT_DIR = outputDirectory;
		context.OUTPUT_FILE = outputFile;
		
		var template = new Template (File.getContent (hxml));
		Sys.println (template.execute (context));
		
	}
	
	
	private function initialize (project:HXProject):Void {
		
		outputDirectory = project.app.path + "/emscripten";
		outputFile = outputDirectory + "/bin/" + project.app.file + ".js";
		
	}
	
	
	public function run (project:HXProject, arguments:Array <String>):Void {
		
		initialize (project);
		
		HTML5Helper.launch (project, project.app.path + "/emscripten/bin");
		
	}
	
	
	public function update (project:HXProject):Void {
		
		initialize (project);
		
		project = project.clone ();
		
		for (asset in project.assets) {
			
			asset.resourceName = "assets/" + asset.resourceName;
			
		}
		
		var destination = outputDirectory + "/bin/";
		PathHelper.mkdir (destination);
		
		//for (asset in project.assets) {
			//
			//if (asset.type == AssetType.FONT) {
				//
				//project.haxeflags.push (HTML5Helper.generateFontData (project, asset));
				//
			//}
			//
		//}
		
		if (project.targetFlags.exists ("xml")) {
			
			project.haxeflags.push ("-xml " + project.app.path + "/emscripten/types.xml");
			
		}
		
		var context = project.templateContext;
		
		context.WIN_FLASHBACKGROUND = StringTools.hex (project.window.background, 6);
		context.OUTPUT_DIR = outputDirectory;
		context.OUTPUT_FILE = outputFile;
		context.CPP_DIR = project.app.path + "/emscripten/obj";
		context.USE_COMPRESSION = project.targetFlags.exists ("compress");
		
		for (asset in project.assets) {
			
			var path = PathHelper.combine (outputDirectory + "/obj/assets", asset.targetPath);
			
			if (asset.type != AssetType.TEMPLATE) {
				
				//if (asset.type != AssetType.FONT) {
					
					PathHelper.mkdir (Path.directory (path));
					FileHelper.copyAssetIfNewer (asset, path);
					
				//}
				
			}
			
		}
		
		FileHelper.recursiveCopyTemplate (project.templatePaths, "emscripten/template", destination, context);
		FileHelper.recursiveCopyTemplate (project.templatePaths, "haxe", outputDirectory + "/haxe", context);
		FileHelper.recursiveCopyTemplate (project.templatePaths, "emscripten/hxml", outputDirectory + "/haxe", context);
		FileHelper.recursiveCopyTemplate (project.templatePaths, "emscripten/cpp", outputDirectory + "/obj", context);
		
		for (asset in project.assets) {
			
			var path = PathHelper.combine (destination, asset.targetPath);
			
			if (asset.type == AssetType.TEMPLATE) {
				
				PathHelper.mkdir (Path.directory (path));
				FileHelper.copyAsset (asset, path, context);
				
			}
			
		}
		
		AssetHelper.createManifest (project, PathHelper.combine (outputDirectory + "/obj/assets", "manifest"));
		
	}
	
	
	public function new () {}
	@ignore public function install (project:HXProject):Void {}
	@ignore public function trace (project:HXProject):Void {}
	@ignore public function uninstall (project:HXProject):Void {}
	
	
}