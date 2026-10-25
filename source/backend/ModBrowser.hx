package backend;

import haxe.Json;
import haxe.io.Bytes;
import haxe.zip.Reader;
import sys.thread.Mutex;
import sys.thread.Thread;

typedef ModEntry = {
	var id:Int;
	var name:String;
	var author:String;
	var views:Int;
	var category:String;
	var dateAdded:Int;
}

typedef ModTaskSnapshot = {
	var done:Bool;
	var error:String;
	var stage:String;
	var progress:Float;
	var entries:Array<ModEntry>;
	var total:Int;
	var page:Int;
	var installedFolder:String;
}

/**
 * GameBanana "Psych Mod Folders" (category 28367) browser + installer.
 * All network and zip work runs on a background thread; the UI polls `ModTask.snapshot()`.
 */
class ModBrowser
{
	public static inline var CATEGORY_ID:Int = 28367;
	public static inline var API_URL:String = 'https://gamebanana.com/apiv11';
	public static inline var USER_AGENT:String = 'PsychEngineModBrowser/1.0 (+https://gamebanana.com/mods/cats/28367)';
	public static inline var MAX_DOWNLOAD:Int = 400 * 1024 * 1024; // 400 MB, the zip is kept in memory
	static inline var MAX_ENTRIES:Int = 20000;
	static inline var MAX_UNCOMPRESSED:Float = 2.0 * 1024 * 1024 * 1024; // 2 GB, zip bomb guard

	public static function indexUrl(page:Int, perPage:Int):String
	{
		if(page < 1) page = 1;
		if(perPage < 1) perPage = 1;
		return API_URL + '/Mod/Index?_nPage=' + page + '&_nPerpage=' + perPage + '&_csvModelInclusions=Mod&_aFilters%5BGeneric_Category%5D=' + CATEGORY_ID;
	}

	public static function fetchIndex(task:ModTask, page:Int, perPage:Int):Void
	{
		try
		{
			task.setStage('Loading page $page...', 0);
			var json:Dynamic = parseJson(httpGet(indexUrl(page, perPage)));
			if(json._aErrorCode != null) throw 'GameBanana error: ' + json._aErrorCode;

			var list:Array<ModEntry> = [];
			var records:Array<Dynamic> = json._aRecords;
			if(records != null)
			{
				for(record in records)
				{
					if(record == null || record._idRow == null) continue;
					list.push({
						id: Std.int(record._idRow),
						name: record._sName != null ? Std.string(record._sName) : 'Unknown mod',
						author: record._aSubmitter != null && record._aSubmitter._sName != null ? Std.string(record._aSubmitter._sName) : 'Unknown',
						views: record._nViewCount != null ? Std.int(record._nViewCount) : 0,
						category: record._aSubCategory != null && record._aSubCategory._sName != null ? Std.string(record._aSubCategory._sName) : '',
						dateAdded: record._tsDateAdded != null ? Std.int(record._tsDateAdded) : 0
					});
				}
			}

			var total:Int = 0;
			if(json._aMetadata != null && json._aMetadata._nRecordCount != null)
				total = Std.int(json._aMetadata._nRecordCount);

			task.setEntries(list, total, page);
			task.finish();
		}
		catch(e:Dynamic)
		{
			task.fail(errorText(e));
		}
	}

	public static function install(task:ModTask, modId:Int, fallbackName:String):Void
	{
		try
		{
			task.setStage('Reading mod info...', 0);
			var json:Dynamic = parseJson(httpGet(API_URL + '/Mod/' + modId + '/ProfilePage'));

			var files:Array<Dynamic> = json._aFiles;
			var chosen:Dynamic = null;
			if(files != null)
			{
				for(file in files)
				{
					if(file == null || file._sFile == null || file._sDownloadUrl == null) continue;
					if(file._bIsArchived == true) continue;
					if(!Std.string(file._sFile).toLowerCase().endsWith('.zip')) continue;
					chosen = file;
					break;
				}
			}
			if(chosen == null) throw 'This mod has no .zip file. Only .zip mods can be installed automatically.';

			var fileName:String = Std.string(chosen._sFile);
			var fileSize:Int = chosen._nFilesize != null ? Std.int(chosen._nFilesize) : 0;
			if(fileSize > MAX_DOWNLOAD) throw 'File is too large (' + prettySize(fileSize) + '). Limit is ' + prettySize(MAX_DOWNLOAD) + '.';

			task.setStage('Downloading ' + fileName + '...', 0);
			var data:Bytes = httpGet(Std.string(chosen._sDownloadUrl));
			if(data.length > MAX_DOWNLOAD) throw 'File is too large (' + prettySize(data.length) + '). Limit is ' + prettySize(MAX_DOWNLOAD) + '.';

			task.setStage('Extracting...', 0);
			var apiName:String = json._sName != null ? Std.string(json._sName) : fallbackName;
			var folder:String = extractZip(data, apiName, function(progress:Float) task.setStage('Extracting...', progress));

			task.setInstalled(folder);
			task.finish();
		}
		catch(e:Dynamic)
		{
			task.fail(errorText(e));
		}
	}

	// ---------------------------------------------------------------- HTTP

	public static function httpGet(url:String):Bytes
	{
		var current:String = url;
		var redirects:Int = 0;
		while(true)
		{
			if(redirects > 5) throw 'Too many redirects.';

			var req:haxe.Http = new haxe.Http(current);
			req.cnxTimeout = 20;
			req.setHeader('User-Agent', USER_AGENT);
			req.setHeader('Accept', '*/*');
			req.setHeader('Accept-Encoding', 'identity');

			var err:String = null;
			var status:Int = 0;
			var location:String = null;
			var data:Bytes = null;

			req.onError = function(msg:String) err = msg;
			req.onStatus = function(s:Int)
			{
				status = s;
				if(req.responseHeaders != null)
				{
					location = req.responseHeaders.get('Location');
					if(location == null) location = req.responseHeaders.get('location');

					var length:String = req.responseHeaders.get('Content-Length');
					if(length == null) length = req.responseHeaders.get('content-length');
					if(length != null)
					{
						var parsed:Null<Int> = Std.parseInt(length);
						if(parsed != null && parsed > MAX_DOWNLOAD)
							throw 'File is too large (' + prettySize(parsed) + '). Limit is ' + prettySize(MAX_DOWNLOAD) + '.';
					}
				}
			};
			req.onBytes = function(bytes:Bytes) data = bytes;

			try req.request() catch(e:Dynamic) err = errorText(e);
			if(err != null) throw 'Network error: ' + err;

			if(status == 301 || status == 302 || status == 303 || status == 307 || status == 308)
			{
				if(location == null || location.length < 1) throw 'Server redirect without a Location header.';
				if(location.startsWith('/'))
				{
					var hostRegex = ~/^(https?:\/\/[^\/]+)/;
					if(!hostRegex.match(current)) throw 'Invalid redirect target.';
					location = hostRegex.matched(1) + location;
				}
				current = location;
				redirects++;
				continue;
			}

			if(status < 200 || status >= 300) throw 'HTTP error ' + status + '.';
			if(data == null || data.length < 1) throw 'Empty response from the server.';
			return data;
		}
	}

	static function parseJson(bytes:Bytes):Dynamic
	{
		try
		{
			return Json.parse(bytes.toString());
		}
		catch(e:Dynamic)
		{
			throw 'Invalid response from GameBanana (not JSON).';
		}
	}

	// ----------------------------------------------------------- zip install

	public static function extractZip(bytes:Bytes, preferredName:String, ?onProgress:Float->Void):String
	{
		var files:Array<{entry:haxe.zip.Entry, path:String}> = [];
		var root:String = '';

		var entries = null;
		try
		{
			var zip:Reader = new Reader(new haxe.io.BytesInput(bytes));
			entries = zip.read();
		}
		catch(e:Dynamic)
		{
			throw 'Invalid or corrupted .zip archive (' + errorText(e) + ').';
		}

		var totalSize:Float = 0;
		for(entry in entries)
		{
			if(entry == null || entry.fileName == null) continue;
			if(entry.fileName.endsWith('/')) continue;
			if(isJunk(entry.fileName)) continue;

			var safe:String = safePath(entry.fileName);
			if(safe == null) continue;

			files.push({entry: entry, path: safe});
			totalSize += entry.fileSize;
			if(files.length > MAX_ENTRIES) throw 'Archive has too many files.';
			if(totalSize > MAX_UNCOMPRESSED) throw 'Archive is too large when uncompressed.';
		}

		if(files.length < 1) throw 'The .zip archive is empty.';

		// Some mods are packed as "mods/<folder>/..."
		var allUnderMods:Bool = true;
		for(file in files)
			if(!file.path.startsWith('mods/')) allUnderMods = false;

		if(allUnderMods)
			for(file in files)
				file.path = file.path.substr(5);

		var paths:Array<String> = [];
		for(file in files) paths.push(file.path);
		root = findRoot(paths);

		var folderName:String = root.length > 0 ? root.substr(0, root.length - 1) : preferredName;
		var slash:Int = folderName.lastIndexOf('/');
		if(slash >= 0) folderName = folderName.substr(slash + 1);
		folderName = sanitizeFolder(folderName);
		folderName = uniqueFolder(folderName);

		var target:String = Paths.mods(folderName);
		var written:Int = 0;
		var total:Int = 0;
		for(file in files)
			if(root.length < 1 || file.path.startsWith(root)) total++;

		if(total < 1) throw 'Could not find a mod folder inside the .zip archive.';

		try
		{
			for(file in files)
			{
				if(root.length > 0 && !file.path.startsWith(root)) continue;

				var relative:String = file.path.substr(root.length);
				var safeRelative:String = safePath(relative);
				if(safeRelative == null) continue;

				var outPath:String = target + '/' + safeRelative;
				createDirectories(haxe.io.Path.directory(outPath));
				File.saveBytes(outPath, file.entry.data);
				written++;

				if(onProgress != null && total > 0) onProgress(written / total);
			}
		}
		catch(e:Dynamic)
		{
			deleteDirectory(target);
			throw 'Failed to extract the .zip archive (' + errorText(e) + ').';
		}

		if(written < 1) throw 'Could not extract any file from the .zip archive.';
		return folderName;
	}

	static function deleteDirectory(path:String):Void
	{
		if(!FileSystem.exists(path)) return;
		if(!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}

		for(entry in FileSystem.readDirectory(path))
		{
			var child:String = path + '/' + entry;
			if(FileSystem.isDirectory(child)) deleteDirectory(child);
			else FileSystem.deleteFile(child);
		}
		FileSystem.deleteDirectory(path);
	}

	/**
	 * Decides which folder inside the archive is the mod itself.
	 * Returns a prefix ending with '/' ('' when the archive root is the mod).
	 */
	static function findRoot(paths:Array<String>):String
	{
		var packFiles:Array<String> = [];
		for(path in paths)
			if(path == 'pack.json' || path.endsWith('/pack.json')) packFiles.push(path);

		if(packFiles.length > 0)
		{
			packFiles.sort(function(a, b) return segmentCount(a) - segmentCount(b));
			var pack:String = packFiles[0];
			var slash:Int = pack.lastIndexOf('/');
			return slash < 0 ? '' : pack.substr(0, slash + 1);
		}

		var top:String = null;
		for(path in paths)
		{
			var slash:Int = path.indexOf('/');
			if(slash < 0) return ''; // file at archive root
			var current:String = path.substr(0, slash);
			if(top == null) top = current;
			else if(top != current) return '';
		}
		return top == null ? '' : top + '/';
	}

	static function segmentCount(path:String):Int
	{
		var count:Int = 1;
		for(i in 0...path.length)
			if(path.charAt(i) == '/') count++;
		return count;
	}

	static function isJunk(path:String):Bool
	{
		var normalized:String = path.replace('\\', '/');
		if(normalized.startsWith('__MACOSX/') || normalized.indexOf('/__MACOSX/') >= 0) return true;
		var name:String = normalized.substr(normalized.lastIndexOf('/') + 1).toLowerCase();
		return name == '.ds_store' || name == 'thumbs.db' || name == 'desktop.ini';
	}

	// Returns a safe relative path, or null when the entry must be skipped (zip-slip / absolute).
	static function safePath(path:String):String
	{
		if(path == null) return null;
		var normalized:String = path.replace('\\', '/');
		while(normalized.startsWith('./')) normalized = normalized.substr(2);

		var parts:Array<String> = normalized.split('/');
		var out:Array<String> = [];
		for(part in parts)
		{
			if(part == null || part == '' || part == '.') continue;
			if(part == '..') return null;
			if(part.indexOf(':') >= 0) return null;
			out.push(part);
		}
		return out.length < 1 ? null : out.join('/');
	}

	static function sanitizeFolder(name:String):String
	{
		if(name == null) name = '';
		var invalid = ~/[\\\/:*?"<>|]/g;
		name = invalid.replace(name, '_');
		name = StringTools.trim(name);
		while(name.length > 0 && (name.charAt(name.length - 1) == '.' || name.charAt(name.length - 1) == ' '))
			name = name.substr(0, name.length - 1);
		if(name.length < 1 || name == '.' || name == '..') name = 'mod';
		return name;
	}

	static function uniqueFolder(name:String):String
	{
		var candidate:String = name;
		var index:Int = 2;
		while(FileSystem.exists(Paths.mods(candidate)))
		{
			candidate = name + '-' + index;
			index++;
			if(index > 999) throw 'Too many folders named "' + name + '".';
		}
		return candidate;
	}

	static function createDirectories(path:String):Void
	{
		if(path == null || path.length < 1 || path == '.') return;
		if(FileSystem.exists(path)) return;

		var parent:String = haxe.io.Path.directory(path);
		if(parent != path && parent.length > 1) createDirectories(parent);
		if(!FileSystem.exists(path)) FileSystem.createDirectory(path);
	}

	public static function prettySize(bytes:Float):String
	{
		if(bytes >= 1024 * 1024 * 1024) return Std.string(Math.round(bytes / (1024 * 1024 * 1024) * 10) / 10) + ' GB';
		if(bytes >= 1024 * 1024) return Std.string(Math.round(bytes / (1024 * 1024) * 10) / 10) + ' MB';
		if(bytes >= 1024) return Std.string(Math.round(bytes / 1024)) + ' KB';
		return Std.string(Math.round(bytes)) + ' B';
	}

	// Threads report through this object; the state reads immutable snapshots from update().
	static function errorText(e:Dynamic):String
	{
		if(e == null) return 'Unknown error.';
		var text:String = Std.string(e);
		return text == null || text.length < 1 ? 'Unknown error.' : text;
	}
}

class ModTask
{
	var mutex:Mutex = new Mutex();

	var _done:Bool = false;
	var _error:String = null;
	var _stage:String = 'idle';
	var _progress:Float = 0;
	var _entries:Array<ModEntry> = null;
	var _total:Int = 0;
	var _page:Int = 1;
	var _installedFolder:String = null;

	public function new() {}

	public function setStage(stage:String, progress:Float = 0):Void
	{
		mutex.acquire();
		_stage = stage;
		_progress = progress;
		mutex.release();
	}

	public function setEntries(entries:Array<ModEntry>, total:Int, page:Int):Void
	{
		mutex.acquire();
		_entries = entries;
		_total = total;
		_page = page;
		mutex.release();
	}

	public function setInstalled(folder:String):Void
	{
		mutex.acquire();
		_installedFolder = folder;
		mutex.release();
	}

	public function finish():Void
	{
		mutex.acquire();
		_done = true;
		mutex.release();
	}

	public function fail(error:String):Void
	{
		mutex.acquire();
		_error = error != null ? error : 'Unknown error.';
		_done = true;
		mutex.release();
	}

	public function snapshot():ModTaskSnapshot
	{
		mutex.acquire();
		var snap:ModTaskSnapshot = {
			done: _done,
			error: _error,
			stage: _stage,
			progress: _progress,
			entries: _entries,
			total: _total,
			page: _page,
			installedFolder: _installedFolder
		};
		mutex.release();
		return snap;
	}
}
