package;


import helpers.LogHelper;
import helpers.PathHelper;
import helpers.ProcessHelper;
import sys.io.File;
import sys.FileSystem;


class Linker {
	
	
	public var mExe:String;
	public var mFlags:Array<String>;
	public var mOutFlag:String;
	public var mExt:String;
	public var mNamePrefix:String;
	public var mLibDir:String;
	public var mRanLib:String;
	public var mFromFile:String;
	public var mLibs:Array<String>;
	public var mRecreate:Bool;
	
	
	public function new (inExe:String) {
		
		mFlags = [];
		mOutFlag = "-o";
		mExe = inExe;
		mNamePrefix = "";
		mLibDir = "";
		mRanLib = "";
		// Default to on...
		mFromFile = "@";
		mLibs = [];
		mRecreate = false;
		
	}
	
	
	private function isOutOfDate (inName:String, inObjs:Array<String>) {
		
		if (!FileSystem.exists (inName)) {
			
			return true;
			
		}
		
		var stamp = FileSystem.stat (inName).mtime.getTime ();
		
		for (obj in inObjs) {
			
			if (!FileSystem.exists (obj)) {
				
				LogHelper.error ("Could not find \"" + obj + "\" required by \"" + inName + "\"");
				
			}
			
			var obj_stamp =  FileSystem.stat (obj).mtime.getTime ();
			
			if (obj_stamp > stamp) {
				
				return true;
				
			}
			
		}
		
		return false;
		
	}
	
	
	public function link (inTarget:Target, inObjs:Array<String>) {
		
		var ext = (inTarget.mExt == "" ? mExt : inTarget.mExt);
		var file_name = mNamePrefix + inTarget.mOutput + ext;
		
		try {
			
			PathHelper.mkdir (inTarget.mOutputDir);
			
		} catch (e:Dynamic) {
			
			LogHelper.error ("Unable to create output directory \"" + inTarget.mOutputDir + "\"");
			
		}
		
		var out_name = inTarget.mOutputDir + file_name;
		
		if (isOutOfDate (out_name, inObjs) || isOutOfDate (out_name, inTarget.mDepends)) {
			
			var args = new Array<String> ();
			var out = mOutFlag;
			
			if (out.substr ( -1) == " ") {
				
				args.push (out.substr (0, out.length - 1));
				out = "";
				
			}
			
			// Build in temp dir, and then move out so all the crap windows
			//  creates stays out of the way
			
			if (mLibDir != "") {
				
				PathHelper.mkdir (mLibDir);
				args.push (out + mLibDir + "/" + file_name);
				
			} else {
				
				if (mRecreate && FileSystem.exists (out_name)) {
					
					Sys.println (" clean " + out_name );
					FileSystem.deleteFile (out_name);
					
				}
				
				args.push (out + out_name);
				
			}
			
			args = args.concat (mFlags).concat (inTarget.mFlags);
			
			// Place list of obj files in a file called "all_objs"
			if (mFromFile == "@") {
				
				var fname = "all_objs";
				var fout = File.write (fname,false);
				for (obj in inObjs) {
					
					fout.writeString (obj + "\n");
					
				}
				fout.close ();
				args.push ("@" + fname);
				
			} else {
				
				args = args.concat (inObjs);
				
			}
			
			args = args.concat (inTarget.mLibs);
			args = args.concat (mLibs);
			
			Sys.println (mExe + " " + args.join (" "));
			
			var split = mExe.split (" ");
			var exe = split.shift ();
			args = split.concat (args);
			
			var result = ProcessHelper.runCommand ("", exe, args);
			
			if (result != 0) {
				
				Sys.exit (result);
				//throw "Error : " + result + " - build cancelled";
				
			}
			
			if (mRanLib != "") {
				
				args = [out_name];
				Sys.println (mRanLib + " " + args.join (" "));
				var result = ProcessHelper.runCommand ("", mRanLib, args);
				
				if (result != 0) {
					
					Sys.exit (result);
					//throw "Error : " + result + " - build cancelled";
					
				}
				
			}
			
			if (mLibDir != "") {
				
				File.copy (mLibDir + "/" + file_name, out_name);
				FileSystem.deleteFile (mLibDir + "/" + file_name);
				
			}
			
			return  out_name;
			
		}
		
		return "";
		
	}
	
	
}