package flash.errors;


class EOFError extends Error {
	
	
	public function new () {
		
		super ("End of file was encountered", 2030);
		
	}
	
	
}