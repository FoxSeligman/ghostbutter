package;


import haxe.io.Path;
import helpers.LogHelper;
import helpers.PathHelper;
import helpers.ProcessHelper;
import sys.FileSystem;


class HLSL {
	
	
	private var file:String;
	private var profile:String;
	private var target:String;
	private var variable:String;
	
	
	public function new (inFile:String, inProfile:String, inVariable:String, inTarget:String) {
		
		file = inFile;
		profile = inProfile;
		variable = inVariable;
		target = inTarget;
		
	}
	
	
	public function build () {
		
		if (!FileSystem.exists (Path.directory (target)))  {
			
			PathHelper.mkdir (Path.directory (target));
			
		}
		
		//DirManager.makeFileDir (target);
		
		var srcStamp = FileSystem.stat (file).mtime.getTime ();
		
		if (!FileSystem.exists (target) || FileSystem.stat (target).mtime.getTime () < srcStamp) {
			
			var exe = "fxc.exe";
			var args =  [ "/nologo", "/T", profile, file, "/Vn", variable, "/Fh", target ];
			
			if (Tools.verbose) {
				
				Sys.println (exe + " " + args.join(" "));
				
			}
			
			var result = ProcessHelper.runCommand ("", exe, args);
			
			if (result != 0) {
				
				LogHelper.error ("Could not compile shader \"" + file + "\"");
				
			}
			
		}
		
	}
	
	
}