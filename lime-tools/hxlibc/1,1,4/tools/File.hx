package;

import helpers.LogHelper;
import sys.FileSystem;


class File {
	
	
	public var mName:String;
	public var mDir:String;
	public var mDepends:Array<String>;
	public var mCompilerFlags:Array<String>;
	public var mGroup:FileGroup;
	
	
	public function new (inName:String, inGroup:FileGroup) {
		
		mName = inName;
		mDir = inGroup.mDir;
		if (mDir != "") mDir += "/";
		// Do not take copy - use reference so it can be updated
		mGroup = inGroup;
		mDepends = [];
		mCompilerFlags = [];
		
	}
	
	
	public function isOutOfDate (inObj:String) {
		
		if (!FileSystem.exists (inObj)) {
			
			return true;
			
		}
		
		var obj_stamp = FileSystem.stat (inObj).mtime.getTime ();
		
		if (mGroup.isOutOfDate (obj_stamp)) {
			
			return true;
			
		}
		
		var source_name = mDir + mName;
		
		if (!FileSystem.exists (source_name)) {
			
			LogHelper.error ("Could not find source file \"" + source_name + "\"");
			
		}
		
		var source_stamp = FileSystem.stat (source_name).mtime.getTime ();
		
		if (obj_stamp < source_stamp) {
			
			return true;
			
		}
		
		for (depend in mDepends) {
			
			if (!FileSystem.exists (depend)) {
				
				LogHelper.error ("Could not find dependency \"" + depend + "\" for \"" + mName + "\"");
				
			}
			
			if (FileSystem.stat (depend).mtime.getTime () > obj_stamp) {
				
				return true;
				
			}
			
		}
		
		return false;
		
	}
	
	
}