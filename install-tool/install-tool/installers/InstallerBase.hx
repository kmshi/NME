package installers;


import data.Asset;
import data.Icon;
import data.NDLL;
import haxe.Template;
import haxe.xml.Fast;
import neko.io.File;
import neko.io.FileOutput;
import neko.io.Path;
import neko.FileSystem;
import neko.Lib;
import neko.Sys;


class InstallerBase {
	
	
	private var assets:Array <Asset>;
	private var buildDirectory:String;
	private var command:String;
	private var compilerFlags:Array <String>;
	private var context:Dynamic;
	private var debug:Bool;
	private var defines:Hash <String>;
	private var icons:Array <Icon>;
	private var includePaths:Array <String>;
	private var ndlls:Array <NDLL>;
	private var nme:String;
	private var projectFile:String;
	private var target:String;
	private var verbose:Bool;
	
	private static var usedFlatNames:Hash <String> = new Hash <String> ();
	private static var varMatch = new EReg("\\${(.*?)}","");
	
	
	public function new (nme:String, command:String, defines:Hash <String>, includePaths:Array <String>, projectFile:String, target:String, verbose:Bool, debug:Bool) {
		
		this.nme = nme;
		this.command = command;
		this.defines = defines;
		this.includePaths = includePaths;
		this.projectFile = projectFile;
		this.target = target;
		this.verbose = verbose;
		this.debug = debug;
		
		assets = new Array <Asset> ();
		compilerFlags = new Array <String> ();
		icons = new Array <Icon> ();
		ndlls = new Array <NDLL> ();
		
		initializeTool ();
		parseProjectFile ();
		
		// Strip off 0x ....
		setDefault ("WIN_FLASHBACKGROUND", defines.get ("WIN_BACKGROUND").substr (2));
		setDefault ("APP_VERSION_SHORT", defines.get ("APP_VERSION").substr (2));
		
		if (defines.exists ("NME_64")) {
			
			compilerFlags.push ("-D HXCPP_M64");
			
		}
		
		buildDirectory = defines.get ("BUILD_DIR");
		
		generateContext ();
		
	}
	
	
	private function copyIfNewer (source:String, destination:String, verbose:Bool) {
		
		if (!isNewer (source, destination)) {
			
			return;
			
		}
		
		if (verbose) {
			
			Lib.println ("Copy " + source + " to " + destination);
			
		}
		
		File.copy (source, destination);
		
	}
	
	
	private function copyFile (source:String, destination:String, process:Bool = true) {
		
		var extension:String = Path.extension (source);
		
		if (process && (extension == "xml" || extension == "java" || extension == "hx" || extension == "hxml" || extension == "ini" || extension == "gpe" || extension == "pbxproj" || extension == "plist" || extension == "json" || extension == "properties")) {
			
			if (verbose) {
				
				Lib.println ("process " + source + " " + destination);
				
			}
			
			var fileContents:String = File.getContent (source);
			var template:Template = new Template (fileContents);
			var result:String = template.execute (context);
			var fileOutput:FileOutput = File.write (destination, true);
			fileOutput.writeString (result);
			fileOutput.close ();
			
		} else {
			
			copyIfNewer (source, destination, verbose);
			
		}
		
	}
	
	
	private function filter (text:String, include:String = "*", exclude:String = ""):Bool {
		
		include = StringTools.replace (include, ".", "\\.");
		exclude = StringTools.replace (exclude, ".", "\\.");
		include = StringTools.replace (include, "*", ".*");
		exclude = StringTools.replace (exclude, "*", ".*");
		
		var includeFilters:Array <String> = include.split ("|");
		var excludeFilters:Array <String> = exclude.split ("|");
		
		for (filter in excludeFilters) {
			
			if (filter != "") {
				
				var regexp:EReg = new EReg ("^" + filter, "i");
				
				if (regexp.match (text)) {
					
					return false;
					
				}
				
			}
			
		}
		
		for (filter in includeFilters) {
			
			if (filter != "") {
				
				var regexp:EReg = new EReg ("^" + filter, "i");
				
				if (!regexp.match (text)) {
					
					return false;
					
				}
				
			}
			
		}
		
		return true;
		
	}
	
	
	private function findIncludeFile (base:String):String {
		
		if (base == "") {
			
			return "";
			
		}
		
		if (base.substr (0, 1) != "/" && base.substr (0, 1) != "\\") {
			
			if (base.substr (1, 1) != ":") {
				
				for (path in includePaths) {
					
					if (FileSystem.exists (path + "/" + base)) {
						
						return path + "/" + base;
						
					}
					
				}
				
				return "";
				
			}
			
			if (FileSystem.exists (base)) {
				
				return base;
				
			}
			
		}
		
		return "";
		
	}
	
	
	private function generateContext ():Void {
		
		context = { };
		
		for (key in defines.keys ()) {
			
			Reflect.setField (context, key, defines.get (key));
			Reflect.setField (context, "ndlls", ndlls);
			Reflect.setField (context, "assets", assets);
			
		}
		
		if (compilerFlags.length == 0) {
			
			context.HAXE_FLAGS = "";
			
		} else {
			
			context.HAXE_FLAGS = "\n" + compilerFlags.join ("\n");
			
		}
		
	}
	
	
	private function generateFlatName (id:String):String {
		
		var chars:String = id.toLowerCase ();
		var flatName:String = "";
		
		for (i in 0...chars.length) {
			
			var code = chars.charCodeAt (i);
			
			if ((i > 0 && code >= "0".charCodeAt (0) && code <= "9".charCodeAt (0)) || (code >= "a".charCodeAt (0) && code <= "z".charCodeAt (0)) || (code == "_".charCodeAt (0))) {
				
				flatName += chars.charAt (i);
				
			} else {
				
				flatName += "_";
				
			}
			
		}
		
		if (flatName == "") {
			
			flatName = "_";
			
		}
		
		while (usedFlatNames.exists (flatName)) {
			
			flatName += "_";
		 
		}
		
		usedFlatNames.set (flatName, "1");
		
		return flatName;
		
	}
	
	
	private function initializeTool ():Void {
		
		compilerFlags.push ("-D nme_install_tool");
		
		setDefault ("WIN_WIDTH", "640");
		setDefault ("WIN_HEIGHT", "480");
		setDefault ("WIN_ORIENTATION", "");
		setDefault ("WIN_FPS", "60");
		setDefault ("WIN_BACKGROUND", "0xffffff");
		setDefault ("WIN_HARDWARE", "true");
		setDefault ("WIN_RESIZEABLE", "true");
		setDefault ("APP_FILE", "MyApplication");
		setDefault ("APP_PACKAGE", "com.example.myapp");
		setDefault ("APP_VERSION", "1.0.0");
		setDefault ("APP_COMPANY", "Example Inc.");
		setDefault ("SWF_VERSION", "9");
		setDefault ("PRELOADER_NAME", "NMEPreloader");
		setDefault ("BUILD_DIR", "bin");
		defines.set ("target_" + target, "1");
		defines.set ("target" , target);
		
	}
	
	
	private static function isNewer (source:String, destination:String):Bool {
		
		if (source == null || !FileSystem.exists (source)) {
			
			throw ("Error: Source path \"" + source + "\" does not exist");
			return false;
			
		}
		
		if (FileSystem.exists (destination)) {
			
			if (FileSystem.stat (source).mtime.getTime () < FileSystem.stat (destination).mtime.getTime ()) {
				
				return false;
				
			}
			
		}
		
		return true;
		
	}
	
	
	private function isValidElement (element:Fast, section:String):Bool {
		
		if (element.x.get ("if") != null) {
			
			if (!defines.exists (element.x.get ("if"))) {
				
				return false;
				
			}
			
		}
		
		if (element.has.unless) {
			
			if (defines.exists (element.att.unless)) {
				
				return false;
				
			}
			
		}
		
		if (section != "") {
			
			if (element.name != "section") {
				
				return false;
				
			}
			
			if (!element.has.id) {
				
				return false;
				
			}
			
			if (element.att.id != section) {
				
				return false;
				
			}
			
		}
		
		return true;
		
	}
	
	
	private function mkdir (directory:String):Void {
		
		var parts = directory.split("/");
		var total = "";
		
		for (part in parts) {
			
			if (part != "." && part != "") {
				
				if (total != "") {
					
					total += "/";
					
				}
				
				total += part;
				
				if (!FileSystem.exists (total)) {
					
					if (verbose) {
						
						Lib.println ("mkdir " + total);
						
					}
					
					FileSystem.createDirectory (total);
					
				}
				
			}
			
		}
		
	}
	
	
	private function parseAppElement (element:Fast):Void {
		
		for (attribute in element.x.attributes ()) {
			
			defines.set ("APP_" + attribute.toUpperCase (), substitute (element.att.resolve (attribute)));
			
		}
		
	}
	
	
	private function parseAssetsElement (element:Fast):Void {
		
		var path:String = "";
		var embed:String = "";
		var rename:String = "";
		var type:String = "";
		
		if (element.has.path) {
			
			path = substitute (element.att.path);
			
		}
		
		if (element.has.embed) {
			
			embed = substitute (element.att.embed);
			
		}
		
		if (element.has.rename) {
			
			rename = substitute (element.att.rename);
			
		}
		
		if (element.has.type) {
			
			type = substitute (element.att.type);
			
		}
		
		if (!element.elements.hasNext ()) {
			
			if (path == "" || !FileSystem.exists (path)) {
				
				throw ("Could not find asset directory \"" + path + "\"");
				return;
				
			}
			
			var exclude:String = ".*|cvs|thumbs.db|desktop.ini";
			var include:String = "*";
			
			if (element.has.exclude) {
				
				exclude += "|" + element.att.exclude;
				
			}
			
			if (element.has.include) {
				
				include = element.att.include;
				
			}
			
			parseAssetsElementDirectory (path, rename, include, exclude, type, embed);
			
		} else {
			
			if (path != "") {
				
				path += "/";
				
			}
			
			if (rename != "") {
				
				rename += "/";
				
			}
			
			for (childElement in element.elements) {
				
				var childPath:String = substitute (childElement.att.path);
				var childRename:String = childPath;
				var childEmbed:String = embed;
				var childType:String = type;
				
				if (childElement.has.rename) {
					
					childRename = childElement.att.rename;
					
				}
				
				if (childElement.has.embed) {
					
					childEmbed = substitute (childElement.att.embed);
					
				}
				
				switch (childElement.name) {
					
					case "image", "sound", "music", "font":
						
						childType == childElement.name;
					
					default:
						
						if (childElement.has.type) {
							
							childType = substitute (childElement.att.type);
							
						}
					
				}
				
				var id:String = "";
				
				if (childElement.has.id) {
					
					id = substitute (childElement.att.id);
					
				}
				
				assets.push (new Asset (path + childPath, rename + childRename, childType, id, childEmbed));
				
			}
			
		}
		
	}
	
	
	private function parseAssetsElementDirectory (path:String, rename:String, include:String, exclude:String, type:String, embed:String):Void {
		
		var files:Array <String> = FileSystem.readDirectory (path);
		
		for (file in files) {
			
			if (FileSystem.isDirectory (path + "/" + file)) {
				
				if (filter (file, "*", exclude)) {
					
					parseAssetsElementDirectory (path + "/" + file, rename + "/" + file, include, exclude, type, embed);
					
				}
				
			} else {
				
				if (filter (file, include, exclude)) {
					
					assets.push (new Asset (path + "/" + file, rename + "/" + file, type, "", embed));
					
				}
				
			}
			
		}
		
	}
	
	
	private function parseProjectFile ():Void {
		
		parseXML (new Fast (Xml.parse (File.getContent (projectFile)).firstElement ()), "");
		
	}
	
	
	private function parseXML (xml:Fast, section:String):Void {
		
		for (element in xml.elements) {
			
			if (isValidElement (element, section)) {
				
				switch (element.name) {
					
					case "set":
						
						defines.set (element.att.name, substitute (element.att.value));
					
					case "unset":
						
						defines.remove (element.att.name);
					
					case "setenv":
						
						var name:String = element.att.name;
						var value:String = substitute (element.att.value);
						
						defines.set (name, value);
						Sys.putEnv (name, value);
					
					case "error":
						
						throw (substitute (element.att.value));
					
					case "path":
						
						if (defines.get ("HOST") == "windows") {
							
							Sys.putEnv ("PATH", substitute (element.att.name) + ";" + Sys.getEnv ("PATH"));
							
						} else {
							
							Sys.putEnv ("PATH", substitute (element.att.name) + ":" + Sys.getEnv ("PATH"));
							
						}
					
					case "include":
						
						var name:String = findIncludeFile (substitute (element.att.name));
						
						if (name != "") {
							
							var xml:Fast = new Fast (Xml.parse (File.getContent (name)).firstElement ());
							
							if (element.has.section) {
								
								parseXML (xml, element.att.section);
								
							} else {
								
								parseXML (xml, "");
								
							}
							
						} else if (!element.has.noerror) {
							
							throw ("Could not find include file " + name);
							
						}
					
					case "app":
						
						parseAppElement (element);
					
					case "haxelib":
						
						var name:String = substitute (element.att.name);
						compilerFlags.push ("-lib " + name);
					
					case "ndll":
						
						var name:String = substitute (element.att.name);
						var haxelib:String = "";
						
						if (element.has.haxelib) {
							
							haxelib = substitute (element.att.haxelib);
							
						}
						
						var needsNekoAPI:Bool = false;
						
						if (element.has.nekoapi && (element.att.nekoapi == "1" || element.att.nekoapi == "true")) {
							
							needsNekoAPI = true;
							
						}
						
						ndlls.push (new NDLL (name, haxelib, needsNekoAPI));
					
					case "icon":
						
						var name:String = substitute(element.att.name);
						var width:String = "";
						var height:String = "";
						
						if (element.has.width) {
							
							width = substitute (element.att.width);
							
						}
						
						if (element.has.height) {
							
							height = substitute (element.att.height);
							
						}
						
						icons.push (new Icon (name, width, height));
					
					case "classpath":
						
						compilerFlags.push ("-cp " + substitute (element.att.name));
					
					case "haxedef":
						
						compilerFlags.push("-D " + substitute (substitute (element.att.name)));
					
					case "compilerflag":
						
						compilerFlags.push(substitute (substitute (element.att.name)));
					
					case "window":
						
						parseWindowElement (element);
					
					case "assets":
						
						parseAssetsElement (element);
					
					case "preloader":
						
						defines.set ("PRELOADER_NAME", substitute (element.att.name));
					
					case "section":
						
						parseXML (element, "");
					
				}
				
			}
			
		}
		
	}	
	
	
	private function parseWindowElement (element:Fast):Void {
		
		for (attribute in element.x.attributes ()) {
			
			defines.set ("WIN_" + attribute.toUpperCase (), substitute (element.att.resolve (attribute)));
			
		}
		
	}
	
	
	public function recursiveCopy (source:String, destination:String, process:Bool = true) {
		
		mkdir (destination);
		var files = FileSystem.readDirectory (source);
		
		for (file in files) {
			
			if (file.substr (0, 1) != ".") {
				
				var itemDestination:String = destination + "/" + file;
				var itemSource:String = source + "/" + file;
				
				if (FileSystem.isDirectory (itemSource)) {
					
					recursiveCopy (itemSource, itemDestination, process);
					
				} else {
					
					copyFile (itemSource, itemDestination, process);
					
				}
				
			}
			
		}
		
	}
	
	
	function runCommand (path:String, command:String, args:Array<String>) {
		
		var oldPath:String = "";
		
		if (path != "") {
			
			if (verbose) {
				
				Lib.println ("cd " + path);
				
			}
			
			oldPath = Sys.getCwd ();
			Sys.setCwd (path);
			
		}
		
		if (verbose) {
			
			Lib.println (command + " " + args.join (" "));
			
		}
		
		var result:Dynamic = Sys.command (command, args);
		
		if (result == 0 && verbose) {
			
			Lib.println ("Ok.");
			
		}
		
		if (oldPath != "") {
			
			Sys.setCwd (oldPath);
			
		}
		
		if (result != 0) {
			
			throw ("Error running: " + command + " " + args.join (" ") + path);
			
		}
		
	}
	
	
	private function setDefault (name:String, value:String) {
		
		if (!defines.exists (name)) {
			
			defines.set (name, value);
			
		}
		
	}
	
	
	private function substitute (string:String):String {
		
		var newString:String = string;
		
		while (varMatch.match (string)) {
			
			var newString = defines.get (varMatch.matched (1));
			
			if (newString == null) {
				
				newString = "";
				
			}
			
			newString = varMatch.matchedLeft () + newString + varMatch.matchedRight ();
			
		}
		
		return newString;
		
	}
	
	
}