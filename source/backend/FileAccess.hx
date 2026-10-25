package backend;

/**
 * Central policy for every file a script is allowed to touch.
 *
 * The Lua callbacks ask here before calling `sys.io` / `sys.FileSystem`, so the
 * rules live in one place instead of being scattered per callback.
 *
 * Two layers:
 *  - `safeMode` on: writes and deletes must stay inside the mods folder, reads
 *    may also reach the game folder. The file type switches are ignored.
 *  - `safeMode` off: the per type switches decide, and location is not checked.
 *
 * HScript is a different problem: it is arbitrary code compiled at runtime, and
 * `Type`/`Reflect`/`import` let it reach any class. `hscriptSourceAllowed` and
 * `hscriptClassAllowed` close the obvious doorways, but a determined script can
 * still escape them. See `odd/tasks/file-access.md`.
 */
enum abstract FileOp(String) from String to String
{
	var READ = 'read';
	var WRITE = 'write';
	var DELETE = 'delete';
	var LIST = 'list';
}

class FileAccess
{
	/** Op constants, so callers do not have to import the module subtype. */
	public static inline var OP_READ:FileOp = READ;
	public static inline var OP_WRITE:FileOp = WRITE;
	public static inline var OP_DELETE:FileOp = DELETE;
	public static inline var OP_LIST:FileOp = LIST;

	public static inline var CATEGORY_DATA:String = 'data';
	public static inline var CATEGORY_SCRIPTS:String = 'scripts';
	public static inline var CATEGORY_IMAGES:String = 'images';
	public static inline var CATEGORY_AUDIO:String = 'audio';
	public static inline var CATEGORY_OTHER:String = 'other';

	public static var categories:Array<String> = [
		CATEGORY_DATA,
		CATEGORY_SCRIPTS,
		CATEGORY_IMAGES,
		CATEGORY_AUDIO,
		CATEGORY_OTHER
	];

	static var extensions:Map<String, String> = [
		'txt' => CATEGORY_DATA, 'json' => CATEGORY_DATA, 'xml' => CATEGORY_DATA,
		'csv' => CATEGORY_DATA, 'lang' => CATEGORY_DATA, 'ini' => CATEGORY_DATA,
		'md' => CATEGORY_DATA, 'frag' => CATEGORY_DATA, 'vert' => CATEGORY_DATA,
		'lua' => CATEGORY_SCRIPTS, 'hx' => CATEGORY_SCRIPTS, 'hscript' => CATEGORY_SCRIPTS, 'hxs' => CATEGORY_SCRIPTS,
		'png' => CATEGORY_IMAGES, 'jpg' => CATEGORY_IMAGES, 'jpeg' => CATEGORY_IMAGES,
		'webp' => CATEGORY_IMAGES, 'gif' => CATEGORY_IMAGES,
		'ogg' => CATEGORY_AUDIO, 'mp3' => CATEGORY_AUDIO, 'wav' => CATEGORY_AUDIO, 'flac' => CATEGORY_AUDIO
	];

	/** Packages HScript may not resolve while Safe Mode is on. */
	static var blockedPackages:Array<String> = ['sys.io', 'sys.filesystem', 'sys.net', 'sys.ssl', 'lime.system'];

	/** File classes HScript may not reach through `addHaxeLibrary`. */
	static var blockedClasses:Array<String> = ['file', 'filesystem', 'process', 'socket'];

	/** Tokens that give a script raw disk access. Matched lowercased. */
	static var blockedSourceTokens:Array<String> = ['sys.io', 'sys.filesystem', 'sys.net', 'sys.ssl', 'lime.system', 'process.'];

	public static function categoryOf(path:String):String
	{
		var norm:String = normalize(path);
		var dot:Int = norm.lastIndexOf('.');
		var slash:Int = norm.lastIndexOf('/');
		if (dot < 0 || dot < slash) return CATEGORY_OTHER;

		var ext:String = norm.substr(dot + 1);
		return extensions.exists(ext) ? extensions.get(ext) : CATEGORY_OTHER;
	}

	public static function isCategoryAllowed(category:String):Bool
	{
		switch (category)
		{
			case CATEGORY_DATA: return ClientPrefs.data.fileAccessData;
			case CATEGORY_SCRIPTS: return ClientPrefs.data.fileAccessScripts;
			case CATEGORY_IMAGES: return ClientPrefs.data.fileAccessImages;
			case CATEGORY_AUDIO: return ClientPrefs.data.fileAccessAudio;
			default: return ClientPrefs.data.fileAccessOther;
		}
	}

	public static function isAllowed(op:FileOp, path:String):Bool
	{
		if (path == null || path.length < 1) return false;

		var norm:String = normalize(path);
		if (norm.contains('..')) return false;

		// Paths reaching here are often relative ("mods/foo.txt"), because that is
		// what Paths.mods() returns. Compare absolute to absolute.
		norm = absolute(norm);

		if (!ClientPrefs.data.safeMode)
			return isCategoryAllowed(categoryOf(norm));

		switch (op)
		{
			case WRITE, DELETE:
				return isInside(modsFolder(), norm);
			default:
				return isInside(modsFolder(), norm) || isInside(gameFolder(), norm);
		}
	}

	/**
	 * Gate used by the Lua callbacks: same decision as `isAllowed`, and it logs
	 * the denial so a blocked mod is diagnosable instead of silently broken.
	 */
	public static function check(op:FileOp, path:String, scriptName:String = null):Bool
	{
		if (isAllowed(op, path)) return true;

		var who:String = (scriptName != null && scriptName.length > 0) ? scriptName : 'unknown script';
		FlxG.log.warn('[$who] Blocked $op on "$path" (' + describeRule() + ')');
		return false;
	}

	public static function describeRule():String
	{
		if (ClientPrefs.data.safeMode) return 'Safe Mode: outside the mods folder';

		var denied:Array<String> = [];
		for (category in categories)
			if (!isCategoryAllowed(category)) denied.push(category);

		return denied.length < 1 ? 'no restriction' : 'file types off: ' + denied.join(', ');
	}

	/**
	 * Rejects HScript source that reaches for the filesystem directly.
	 * Returns null when the source is acceptable, or the reason it was refused.
	 *
	 * This is a speed bump, not a wall: it only runs while Safe Mode is on, and it
	 * cannot stop a script that resolves File through `Type.resolveClass`.
	 */
	public static function hscriptSourceAllowed(source:String):String
	{
		if (!ClientPrefs.data.safeMode || source == null) return null;

		var lower:String = source.toLowerCase();
		for (token in blockedSourceTokens)
			if (lower.contains(token)) return '"$token" is not allowed in Safe Mode';

		return null;
	}

	/**
	 * Rejects `addHaxeLibrary` calls that would hand a script the filesystem.
	 * Returns null when the class may be resolved, or the reason it may not.
	 */
	public static function hscriptClassAllowed(libName:String, ?libPackage:String = ''):String
	{
		if (!ClientPrefs.data.safeMode || libName == null) return null;

		var full:String = (libPackage != null && libPackage.length > 0) ? libPackage + '.' + libName : libName;
		full = normalize(full);

		for (blocked in blockedPackages)
			if (full == blocked || full.startsWith(blocked + '.'))
				return '"$full" is not allowed in Safe Mode';

		for (blocked in blockedClasses)
			if (full == blocked || full.endsWith('.' + blocked))
				return '"$full" is not allowed in Safe Mode';

		return null;
	}

	public static function normalize(path:String):String
	{
		if (path == null) return '';
		return path.replace('\\', '/').toLowerCase();
	}

	/** Turns a relative path into an absolute one, based on the process directory. */
	public static function absolute(path:String):String
	{
		var norm:String = normalize(path);
		if (norm.length < 1) return '';

		var isAbsolute:Bool = norm.startsWith('/') || (norm.length > 2 && norm.charAt(1) == ':');
		if (isAbsolute) return norm;

		#if sys
		try
		{
			return normalize(FileSystem.absolutePath(path));
		}
		catch (e:Dynamic) {}
		#end
		return norm;
	}

	public static function isInside(folder:String, path:String):Bool
	{
		var base:String = normalize(folder);
		if (base.length < 1) return false;

		if (!base.endsWith('/')) base += '/';

		var norm:String = normalize(path);
		if (norm.endsWith('/')) norm = norm.substr(0, norm.length - 1);

		return norm == base.substr(0, base.length - 1) || norm.startsWith(base);
	}

	/** Absolute mods folder, where a sandboxed script is free to work. */
	public static function modsFolder():String
	{
		#if MODS_ALLOWED
		return absolute(Paths.mods());
		#else
		return '';
		#end
	}

	/** Folder the executable lives in, used to allow reading the game's own assets. */
	public static function gameFolder():String
	{
		#if sys
		try
		{
			var exe:String = normalize(Sys.programPath());
			var slash:Int = exe.lastIndexOf('/');
			if (slash > 0) return exe.substr(0, slash);
		}
		catch (e:Dynamic) {}
		#end
		return '';
	}
}
