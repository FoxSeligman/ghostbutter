package;


import haxe.io.Path;
import helpers.LogHelper;
import helpers.PathHelper;
import helpers.ProcessHelper;
import sys.FileSystem;


class Compiler {
	
	
	public var mFlags:Array<String>;
	public var mCFlags:Array<String>;
	public var mMMFlags:Array<String>;
	public var mCPPFlags:Array<String>;
	public var mOBJCFlags:Array<String>;
	public var mPCHFlags:Array<String>;
	public var mAddGCCIdentity:Bool;
	public var mExe:String;
	public var mOutFlag:String;
	public var mObjDir:String;
	public var mExt:String;
	
	public var mPCHExt:String;
	public var mPCHCreate:String;
	public var mPCHUse:String;
	public var mPCHFilename:String;
	public var mPCH:String;
	
	public var mID:String;
	
	
	public function new (inID, inExe:String, inGCCFileTypes:Bool) {
		
		mFlags = [];
		mCFlags = [];
		mCPPFlags = [];
		mOBJCFlags = [];
		mMMFlags = [];
		mPCHFlags = [];
		mAddGCCIdentity = inGCCFileTypes;
		mObjDir = "obj";
		mOutFlag = "-o";
		mExe = inExe;
		mID = inID;
		mExt = ".o";
		mPCHExt = ".pch";
		mPCHCreate = "-Yc";
		mPCHUse = "-Yu";
		mPCHFilename = "/Fp";
		
	}
	
	
	private function addIdentity (ext:String, ioArgs:Array<String>) {
		
		if (mAddGCCIdentity) {
			
			var identity = switch (ext) {
				
				case "c": "c";
				case "m": "objective-c";
				case "mm": "objective-c++";
				case "cpp": "c++";
				case "c++": "c++";
				default: "";
				
			}
			
			if (identity != "") {
				
				ioArgs.push ("-x");
				ioArgs.push (identity);
				
			}
			
		}
		
	}
	
	
	public function compile (inFile:File) {
		
		var path = new Path (mObjDir + "/" + inFile.mName);
		var obj_name = path.dir + "/" + path.file + mExt;
		
		var args = new Array <String> ();
		args = args.concat (inFile.mCompilerFlags).concat (inFile.mGroup.mCompilerFlags).concat (mFlags);
		
		var ext = path.ext.toLowerCase ();
		addIdentity (ext, args);
		
		if (ext == "c") {
			
			args = args.concat (mCFlags);
			
		} else if (ext == "m") {
			
			args = args.concat (mOBJCFlags);
			
		} else if (ext == "mm") {
			
			args = args.concat (mMMFlags);
			
		} else if (ext == "cpp" || ext == "c++") {
			
			args = args.concat (mCPPFlags);
			
		}
		
		if (inFile.mGroup.mPrecompiledHeader != "") {
			
			var pchDir = inFile.mGroup.getPchDir ();
			
			if (mPCHUse != "") {
				
				args.push (mPCHUse + inFile.mGroup.mPrecompiledHeader + ".h");
				args.push (mPCHFilename + mObjDir + "/" + pchDir + "/" + inFile.mGroup.mPrecompiledHeader + mPCHExt);
				
			} else {
				
				args.push ("-I" + mObjDir + "/" + pchDir);
				
			}
			
		}
		
		args.push ((new Path (inFile.mDir + inFile.mName)).toString ());
		
		var out = mOutFlag;
		if (out.substr ( -1) == " ") {
			
			args.push (out.substr (0, out.length - 1));
			out = "";
			
		}
		
		args.push (out + obj_name);
		
		Sys.println (mExe + " " + args.join (" "));
		
		var split = mExe.split (" ");
		var exe = split.shift ();
		args = split.concat (args);
		
		var result = ProcessHelper.runCommand ("", exe, args);
		
		if (result != 0) {
			
			if (FileSystem.exists (obj_name)) {
				
				FileSystem.deleteFile (obj_name);
				
			}
			
			Sys.exit (result);
			//throw "Error : " + result + " - build cancelled";
			
		}
		
		return obj_name;
		
	}
	
	
	public function needsPchObj () {
		
		return mPCH != "gcc";
		
	}
	
	
	public function precompile (inObjDir:String, inHeader:String, inDir:String, inGroup:FileGroup) {
		
		var args = inGroup.mCompilerFlags.concat (mFlags).concat (mCPPFlags).concat (mPCHFlags);
		
		var dir = inObjDir + "/" + inGroup.getPchDir () + "/";
		var pch_name = dir + inHeader + mPCHExt;
		
		PathHelper.mkdir (dir);
		
		if (mPCH != "gcc") {
			
			args.push (mPCHCreate + inHeader + ".h");
			
			// Create a temp file for including ...
			var tmp_cpp = dir + inHeader + ".cpp";
			var file = sys.io.File.write (tmp_cpp, false);
			file.writeString ("#include <" + inHeader + ".h>\n");
			file.close ();
			
			args.push (tmp_cpp);
			args.push (mPCHFilename + pch_name);
			args.push (mOutFlag + dir + inHeader + mExt);
			
		} else {
			
			args.push ("-o");
			args.push (pch_name);
			args.push (inDir + "/"  + inHeader + ".h");
			
		}
		
		Sys.println ("Creating " + pch_name + "...");
		Sys.println (mExe + " " + args.join (" "));
		
		var split = mExe.split (" ");
		var exe = split.shift ();
		args = split.concat (args);
		
		var result = ProcessHelper.runCommand ("", exe, args);
		
		if (result != 0) {
			
			if (FileSystem.exists (pch_name)) {
				
				FileSystem.deleteFile (pch_name);
				
			}
			
			LogHelper.error ("Could not create PCH");
			
		}
		
	}
	
	
	public function setPCH (inPCH:String) {
		
		mPCH = inPCH;
		
		if (mPCH == "gcc") {
			
			mPCHExt = ".h.gch";
			mPCHUse = "";
			mPCHFilename = "";
			
		}
		
	}
	
	
}