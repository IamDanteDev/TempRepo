package backend;

import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MainMenuCustomButton = {
	var id:String;
	var image:String;
	var label:String;
	var action:String; // 'url' or 'state'
	var url:String;
	var targetState:String;
	var x:Float;
	var y:Float;
	var scale:Float;
	var antialiasing:Bool;
}

typedef MainMenuConfigData = {
	var items:Array<String>;
	var leftOption:String;
	var rightOption:String;
	var bgImage:String;
	var bgScrollSpeed:Float;
	var positions:Dynamic;
	var customButtons:Array<MainMenuCustomButton>;
}

/**
 * Reads and writes the Main Menu layout used by `MainMenuState`.
 * The file lives in the currently loaded mod (or the base `mods/` folder)
 * so each mod can ship its own menu configuration.
 */
class MainMenuConfig
{
	/** Every option the engine knows how to handle, in display order. */
	public static final AVAILABLE_ITEMS:Array<String> = [
		'story_mode',
		'freeplay',
		'mods',
		'credits',
		'achievements',
		'options'
	];

	public static function getDefault():MainMenuConfigData
	{
		return {
			items: ['story_mode', 'freeplay', 'mods', 'credits'],
			leftOption: 'achievements',
			rightOption: 'options',
			bgImage: 'menuBG',
			bgScrollSpeed: 0.25,
			positions: {},
			customButtons: []
		};
	}

	public static function load():MainMenuConfigData
	{
		var config:MainMenuConfigData = getDefault();
		var raw:String = read();

		if (raw == null)
			return config;

		try
		{
			var parsed:Dynamic = Json.parse(raw);

			if (parsed.items != null && Std.isOfType(parsed.items, Array))
			{
				var items:Array<String> = [];
				for (item in cast(parsed.items, Array<Dynamic>))
				{
					if (Std.isOfType(item, String))
						items.push(cast item);
				}
				config.items = items;
			}

			if (parsed.leftOption != null)
				config.leftOption = Std.string(parsed.leftOption);
			if (parsed.rightOption != null)
				config.rightOption = Std.string(parsed.rightOption);

			if (parsed.bgImage != null && Std.string(parsed.bgImage).length > 0)
				config.bgImage = Std.string(parsed.bgImage);
			if (parsed.bgScrollSpeed != null)
				config.bgScrollSpeed = Std.parseFloat(Std.string(parsed.bgScrollSpeed));
			if (parsed.positions != null)
				config.positions = parsed.positions;
			if (parsed.customButtons != null && Std.isOfType(parsed.customButtons, Array))
				config.customButtons = cast parsed.customButtons;
		}
		catch (e:Dynamic)
			trace('MainMenuConfig: could not parse ${path()} ($e)');

		sanitize(config);
		return config;
	}

	public static function save(config:MainMenuConfigData):Bool
	{
		sanitize(config);

		#if sys
		try
		{
			var file:String = path();
			var folder:String = Path.directory(file);
			if (folder.length > 0 && !FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			File.saveContent(file, Json.stringify(config, '\t'));
			return true;
		}
		catch (e:Dynamic)
			trace('MainMenuConfig: could not save ${path()} ($e)');
		#end

		return false;
	}

	/** Drops unknown or duplicated entries so the menu never receives broken data. */
	public static function sanitize(config:MainMenuConfigData):Void
	{
		var clean:Array<String> = [];
		if (config.items != null)
		{
			for (item in config.items)
			{
				if (AVAILABLE_ITEMS.indexOf(item) > -1 && clean.indexOf(item) < 0)
					clean.push(item);
			}
		}

		if (clean.length < 1)
			clean = ['story_mode'];
		config.items = clean;

		if (config.leftOption == null || config.leftOption.length < 1 || clean.indexOf(config.leftOption) > -1)
			config.leftOption = '';
		if (config.rightOption == null || config.rightOption.length < 1 || clean.indexOf(config.rightOption) > -1)
			config.rightOption = '';

		if (config.leftOption != '' && config.leftOption == config.rightOption)
			config.rightOption = '';

		if (config.bgImage == null || config.bgImage.length < 1)
			config.bgImage = 'menuBG';
		config.bgScrollSpeed = Math.max(0, config.bgScrollSpeed);
		if (config.positions == null)
			config.positions = {};
		if (config.customButtons == null)
			config.customButtons = [];
	}

	public static function path():String
	{
		var mod:String = Mods.currentModDirectory;
		if (mod != null && mod.length > 0)
			return 'mods/$mod/data/mainmenu.json';
		return 'mods/data/mainmenu.json';
	}

	static function read():String
	{
		#if sys
		try
		{
			var file:String = path();
			if (FileSystem.exists(file))
				return File.getContent(file);
		}
		catch (e:Dynamic)
			trace('MainMenuConfig: could not read ${path()} ($e)');
		#end

		return null;
	}
}
