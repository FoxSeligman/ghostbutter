package;


import haxe.io.Path;
import helpers.LogHelper;
import helpers.PathHelper;
import sys.FileSystem;


class FileGroup {
	
	
	public var mNewest:Float;
	public var mCompilerFlags:Array<String>;
	public var mMissingDepends:Array<String>;
	public var mOptions:Array<String>;
	public var mPrecompiledHeader:String;
	public var mPrecompiledHeaderDir:String;
	public var mFiles:Array<File>;
	public var mHLSLs:Array<HLSL>;
	public var mDir:String;
	public var mId:String;
	
	
	public function new (inDir:String, inId:String) {
		
		mNewest = 0;
		mFiles = [];
		mCompilerFlags = [];
		mPrecompiledHeader = "";
		mMissingDepends = [];
		mOptions = [];
		mHLSLs = [];
		mDir = inDir;
		mId = inId;
		
	}
	
	
	public function addCompilerFlag (inFlag:String) {
		
		mCompilerFlags.push (inFlag);
		
	}
	
	
	public function addDepend (inFile:String) {
		
		if (!FileSystem.exists (inFile)) {
			
			if (StringTools.startsWith (inFile, Tools.HXCPP) && inFile.indexOf ("build-tool/") > -1) {
				
				inFile = StringTools.replace (inFile, "build-tool/", "toolchain/");
				
				if (!FileSystem.exists (inFile)) {
					
					mMissingDepends.push (inFile);
					return;
					
				}
				
			} else {
				
				mMissingDepends.push (inFile);
				return;
				
			}
			
		}
		
		var stamp = FileSystem.stat (inFile).mtime.getTime ();
		
		if (stamp > mNewest) {
			
			mNewest = stamp;
			
		}
		
	}
	

	public function addHLSL (inFile:String, inProfile:String, inVariable:String, inTarget:String) {
		
		addDepend (inFile);
		mHLSLs.push (new HLSL (inFile, inProfile, inVariable, inTarget));
		
	}
	
	
	public function addOptions (inFile:String) {
		
		mOptions.push (inFile);
		
	}
	
	
	public function checkDependsExist () {
		
		if (mMissingDepends.length > 0) {
			
			LogHelper.error ("Could not find dependencies: [ " + mMissingDepends.join (", ") + " ]");
			
		}
		
	}
	
	
	public function checkOptions (inObjDir:String) {
		
		var changed = false;
		
		for (option in mOptions) {
			
			if (!FileSystem.exists (option)) {
				
				mMissingDepends.push (option);
				
			} else {
				
				var contents = sys.io.File.getContent (option);
				
				var dest = inObjDir + "/" + Path.withoutDirectory (option);
				var skip = false;
				
				if (FileSystem.exists (dest)) {
					
					var dest_content = sys.io.File.getContent (dest);
					
					if (dest_content == contents) {
						
						skip = true;
						
					}
					
				}
				
				if (!skip) {
					
					PathHelper.mkdir (inObjDir);
					var stream = sys.io.File.write (dest, true);
					stream.writeString (contents);
					stream.close ();
					changed = true;
					
				}
				
				addDepend (dest);
				
			}
			
		}
		
		return changed;
		
	}
	
	
	public function getPchDir () {
		
		return "__pch/" + mId;
		
	}
	
	
	public function isOutOfDate (inStamp:Float) {
		
		return inStamp < mNewest;
		
	}
	
	
	public function preBuild () {
		
		for (hlsl in mHLSLs) {
			
			hlsl.build ();
			
		}
		
	}
	
	
	public function setPrecompiled (inFile:String, inDir:String) {
		
		mPrecompiledHeader = inFile;
		mPrecompiledHeaderDir = inDir;
		
	}
	
	
}