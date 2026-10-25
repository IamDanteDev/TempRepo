package backend;

#if ACHIEVEMENTS_ALLOWED
import objects.AchievementPopup;
import haxe.Exception;
import haxe.Json;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

typedef Achievement =
{
	var name:String;
	var description:String;
	@:optional var hidden:Bool;
	@:optional var maxScore:Float;
	@:optional var maxDecimals:Int;
	@:optional var image:String; // path relative to images/ without extension, defaults to achievements/<save>

	//handled automatically, ignore these
	@:optional var mod:String;
	@:optional var ID:Int;
	@:optional var save:String;
}

enum abstract AchievementOp(String)
{
	var GET = 'get';
	var SET = 'set';
	var ADD = 'add';
}

class Achievements {
	public static function init()
	{
		createAchievement('friday_night_play',		{name: "Freaky on a Friday Night", description: "Play on a Friday... Night.", hidden: true});
		#if BASE_GAME_FILES
		createAchievement('week1_nomiss',			{name: "She Calls Me Daddy Too", description: "Beat Week 1 on Hard with no Misses."});
		createAchievement('week2_nomiss',			{name: "No More Tricks", description: "Beat Week 2 on Hard with no Misses."});
		createAchievement('week3_nomiss',			{name: "Call Me The Hitman", description: "Beat Week 3 on Hard with no Misses."});
		createAchievement('week4_nomiss',			{name: "Lady Killer", description: "Beat Week 4 on Hard with no Misses."});
		createAchievement('week5_nomiss',			{name: "Missless Christmas", description: "Beat Week 5 on Hard with no Misses."});
		createAchievement('week6_nomiss',			{name: "Highscore!!", description: "Beat Week 6 on Hard with no Misses."});
		createAchievement('week7_nomiss',			{name: "God Effing Damn It!", description: "Beat Week 7 on Hard with no Misses."});
		createAchievement('weekend1_nomiss',		{name: "Just a Friendly Sparring", description: "Beat Weekend 1 on Hard with no Misses."});
		#end
		createAchievement('ur_bad',					{name: "What a Funkin' Disaster!", description: "Complete a Song with a rating lower than 20%."});
		createAchievement('ur_good',				{name: "Perfectionist", description: "Complete a Song with a rating of 100%."});
		#if BASE_GAME_FILES
		createAchievement('roadkill_enthusiast',	{name: "Roadkill Enthusiast", description: "Watch the Henchmen die 50 times.", maxScore: 50, maxDecimals: 0});
		#end
		createAchievement('oversinging', 			{name: "Oversinging Much...?", description: "Sing for 10 seconds without going back to Idle."});
		createAchievement('hype',					{name: "Hyperactive", description: "Finish a Song without going back to Idle."});
		createAchievement('two_keys',				{name: "Just the Two of Us", description: "Finish a Song pressing only two keys."});
		createAchievement('toastie',				{name: "Toaster Gamer", description: "Have you tried to run the game on a toaster?"});
		#if BASE_GAME_FILES
		createAchievement('debugger',				{name: "Debugger", description: "Beat the \"Test\" Stage from the Chart Editor.", hidden: true});
		#end
		#if (TITLE_SCREEN_EASTER_EGG || PSYCH_WATERMARKS)
		createAchievement('pessy_easter_egg',		{name: "Engine Gal Pal", description: "Teehee, you found me~!", hidden: true});
		#end

		//dont delete this thing below
		_originalLength = _sortID + 1;
	}

	public static var achievements:Map<String, Achievement> = new Map<String, Achievement>();
	public static var variables:Map<String, Float> = [];
	public static var achievementsUnlocked:Array<String> = [];
	// Save keys of the achievements created with the in-game Achievement Editor.
	public static var customAchievements:Array<String> = [];
	private static var _firstLoad:Bool = true;

	public static function get(name:String):Achievement
		return achievements.get(name);
	public static function exists(name:String):Bool
		return achievements.exists(name);

	public static function load():Void
	{
		if(!_firstLoad) return;

		if(_originalLength < 0) init();

		if(FlxG.save.data != null) {
			if(FlxG.save.data.achievementsUnlocked != null)
				achievementsUnlocked = FlxG.save.data.achievementsUnlocked;

			var savedMap:Map<String, Float> = cast FlxG.save.data.achievementsVariables;
			if(savedMap != null)
			{
				for (key => value in savedMap)
				{
					variables.set(key, value);
				}
			}
			_firstLoad = false;
			loadCustomAchievements();
		}
	}

	public static function save():Void
	{
		FlxG.save.data.achievementsUnlocked = achievementsUnlocked;
		FlxG.save.data.achievementsVariables = variables;
	}
	
	public static function getScore(name:String):Float
		return _scoreFunc(name, GET);

	public static function setScore(name:String, value:Float, saveIfNotUnlocked:Bool = true):Float
		return _scoreFunc(name, SET, value, saveIfNotUnlocked);

	public static function addScore(name:String, value:Float = 1, saveIfNotUnlocked:Bool = true):Float
		return _scoreFunc(name, ADD, value, saveIfNotUnlocked);

	static function _scoreFunc(name:String, mode:AchievementOp, addOrSet:Float = 1, saveIfNotUnlocked:Bool = true):Float
	{
		if(!variables.exists(name))
			variables.set(name, 0);

		if(achievements.exists(name))
		{
			var achievement:Achievement = achievements.get(name);
			if(achievement.maxScore < 1) throw new Exception('Achievement has score disabled or is incorrectly configured: $name');

			if(achievementsUnlocked.contains(name)) return achievement.maxScore;

			var val = addOrSet;
			switch(mode)
			{
				case GET: return variables.get(name); //get
				case ADD: val += variables.get(name); //add
				default:
			}

			if(val >= achievement.maxScore)
			{
				unlock(name);
				val = achievement.maxScore;
			}
			variables.set(name, val);

			Achievements.save();
			if(saveIfNotUnlocked || val >= achievement.maxScore) FlxG.save.flush();
			return val;
		}
		return -1;
	}

	static var _lastUnlock:Int = -999;
	public static function unlock(name:String, autoStartPopup:Bool = true):String {
		if(!achievements.exists(name))
		{
			FlxG.log.error('Achievement "$name" does not exists!');
			throw new Exception('Achievement "$name" does not exists!');
			return null;
		}

		if(Achievements.isUnlocked(name)) return null;

		trace('Completed achievement "$name"');
		achievementsUnlocked.push(name);

		// earrape prevention
		var time:Int = openfl.Lib.getTimer();
		if(Math.abs(time - _lastUnlock) >= 100) //If last unlocked happened in less than 100 ms (0.1s) ago, then don't play sound
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
			_lastUnlock = time;
		}

		Achievements.save();
		FlxG.save.flush();

		if(autoStartPopup) startPopup(name);
		return name;
	}

	inline public static function isUnlocked(name:String)
		return achievementsUnlocked.contains(name);

	@:allow(objects.AchievementPopup)
	private static var _popups:Array<AchievementPopup> = [];

	public static var showingPopups(get, never):Bool;
	public static function get_showingPopups()
		return _popups.length > 0;

	public static function startPopup(achieve:String, endFunc:Void->Void = null) {
		for (popup in _popups)
		{
			if(popup == null) continue;
			popup.intendedY += 150;
		}

		var newPop:AchievementPopup = new AchievementPopup(achieve, endFunc);
		_popups.push(newPop);
		//trace('Giving achievement ' + achieve);
	}

	// Map sorting cuz haxe is physically incapable of doing that by itself
	static var _sortID = 0;
	static var _originalLength = -1;
	public static function createAchievement(name:String, data:Achievement, ?mod:String = null)
	{
		data.save = name;
		data.ID = _sortID;
		data.mod = mod;
		achievements.set(name, data);
		_sortID++;
	}

	// ---------------------------------------------------------------------
	// Custom achievements (created, modified and removed with the Achievement Editor)
	// They are stored in the save file, not in a mod JSON, so they can be edited at runtime.
	// ---------------------------------------------------------------------
	public static function isCustom(name:String):Bool
		return customAchievements.contains(name);

	public static function isValidSaveKey(key:String):Bool
		return key != null && ~/^[A-Za-z0-9_-]+$/.match(key);

	// Turns "images/achievements/foo.png" or "achievements/foo" into "achievements/foo"
	public static function normalizeImagePath(path:String):String
	{
		if(path == null) return null;

		path = path.trim().replace('\\', '/');
		if(path.endsWith('.png')) path = path.substr(0, path.length - 4);
		if(path.startsWith('images/')) path = path.substr(7);
		while(path.startsWith('/'))
			path = path.substr(1);

		return path.length < 1 ? null : path;
	}

	// Image path (relative to images/, no extension) used to draw this achievement's icon
	public static function getImagePath(achieve:Achievement):String
	{
		if(achieve == null) return 'achievements/unknown';
		var custom:String = normalizeImagePath(achieve.image);
		if(custom != null) return custom;
		return 'achievements/' + (achieve.save != null ? achieve.save : 'unknown');
	}

	public static function getCustomList():Array<Achievement>
	{
		var list:Array<Achievement> = [];
		for (key in customAchievements)
		{
			var achieve:Achievement = achievements.get(key);
			if(achieve != null) list.push(achieve);
		}
		list.sort(function(a:Achievement, b:Achievement) return a.ID - b.ID);
		return list;
	}

	// Returns null on success, or a human readable error message
	public static function createCustom(save:String, data:Achievement):String
	{
		save = save.trim();
		if(!isValidSaveKey(save)) return 'Invalid save key: use only letters, numbers, "_" and "-".';
		if(achievements.exists(save) && !isCustom(save)) return 'The save key "$save" is already used by another achievement.';

		var existing:Achievement = achievements.get(save);
		data.ID = (existing != null && existing.ID != null) ? existing.ID : _getNextID();
		data.save = save;
		data.mod = null;
		data.image = normalizeImagePath(data.image);
		if(data.ID >= _sortID) _sortID = data.ID + 1;

		achievements.set(save, data);
		if(!customAchievements.contains(save)) customAchievements.push(save);
		saveCustomAchievements();
		return null;
	}

	public static function removeCustom(save:String):Bool
	{
		if(!isCustom(save)) return false;

		achievements.remove(save);
		customAchievements.remove(save);
		achievementsUnlocked.remove(save);
		variables.remove(save);
		Achievements.save();
		saveCustomAchievements();
		return true;
	}

	static function _getNextID():Int
	{
		var next:Int = 0;
		for (achieve in achievements)
			if(achieve.ID != null && achieve.ID >= next) next = achieve.ID + 1;
		return next;
	}

	public static function saveCustomAchievements():Void
	{
		var list:Array<Dynamic> = [];
		for (save in customAchievements)
		{
			var achieve:Achievement = achievements.get(save);
			if(achieve == null) continue;

			list.push({
				save: save,
				name: achieve.name,
				description: achieve.description,
				hidden: achieve.hidden == true,
				maxScore: achieve.maxScore == null ? 0 : achieve.maxScore,
				maxDecimals: achieve.maxDecimals == null ? 0 : achieve.maxDecimals,
				image: achieve.image
			});
		}
		FlxG.save.data.customAchievementsData = list;
		FlxG.save.flush();
	}

	static function loadCustomAchievements():Void
	{
		var saved:Array<Dynamic> = cast FlxG.save.data.customAchievementsData;
		if(saved == null) return;

		for (data in saved)
		{
			if(data == null || data.save == null) continue;

			var save:String = Std.string(data.save).trim();
			if(!isValidSaveKey(save) || achievements.exists(save)) continue;

			createAchievement(save, {
				name: data.name != null ? Std.string(data.name) : save,
				description: data.description != null ? Std.string(data.description) : '',
				hidden: data.hidden == true,
				maxScore: data.maxScore,
				maxDecimals: data.maxDecimals,
				image: data.image != null ? Std.string(data.image) : null
			}, null);
			customAchievements.push(save);
		}
	}

	#if MODS_ALLOWED
	public static function reloadList()
	{
		// remove modded achievements
		if((_sortID + 1) > _originalLength)
			for (key => value in achievements)
				if(value.mod != null)
					achievements.remove(key);

		_sortID = _originalLength-1;
		for (achieve in achievements)
			if(achieve.ID != null && achieve.ID >= _sortID) _sortID = achieve.ID + 1;

		var modLoaded:String = Mods.currentModDirectory;
		Mods.currentModDirectory = null;
		loadAchievementJson(Paths.mods('data/achievements.json'));
		for (i => mod in Mods.parseList().enabled)
		{
			Mods.currentModDirectory = mod;
			loadAchievementJson(Paths.mods('$mod/data/achievements.json'));
		}
		Mods.currentModDirectory = modLoaded;
	}

	inline static function loadAchievementJson(path:String, addMods:Bool = true)
	{
		var retVal:Array<Dynamic> = null;
		if(FileSystem.exists(path)) {
			try {
				var rawJson:String = File.getContent(path).trim();
				if(rawJson != null && rawJson.length > 0) retVal = tjson.TJSON.parse(rawJson); //Json.parse('{"achievements": $rawJson}').achievements;
				
				if(addMods && retVal != null)
				{
					for (i in 0...retVal.length)
					{
						var achieve:Dynamic = retVal[i];
						if(achieve == null)
						{
							var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
							var errorMsg = 'Achievement #${i+1} is invalid.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							trace('$errorTitle - $errorMsg');
							continue;
						}

						var key:String = achieve.save;
						if(key == null || key.trim().length < 1)
						{
							var errorTitle = 'Error on Achievement: ' + (achieve.name != null ? achieve.name : achieve.save);
							var errorMsg = 'Missing valid "save" value.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							trace('$errorTitle - $errorMsg');
							continue;
						}
						key = key.trim();
						if(achievements.exists(key)) continue;

						createAchievement(key, achieve, Mods.currentModDirectory);
					}
				}
			} catch(e:Dynamic) {
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
				var errorMsg = 'Error loading achievements.json: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}
		return retVal;
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "getAchievementScore", function(name:String):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('getAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return getScore(name);
		});
		Lua_helper.add_callback(lua, "setAchievementScore", function(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('setAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return setScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "addAchievementScore", function(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('addAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return addScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "unlockAchievement", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('unlockAchievement: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return unlock(name);
		});
		Lua_helper.add_callback(lua, "isAchievementUnlocked", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('isAchievementUnlocked: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return isUnlocked(name);
		});
		Lua_helper.add_callback(lua, "achievementExists", function(name:String) return achievements.exists(name));
	}
	#end
}
#end