package backend;

import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuLayer = {
	var id:String;
	var image:String;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var alpha:Float;
	var angle:Float;
	var scrollX:Float;
	var scrollY:Float;
	var antialiasing:Bool;
	var visible:Bool;
	var behindUI:Bool;
}

typedef MenuSounds = {
	var scroll:String;
	var confirm:String;
	var cancel:String;
	var select:String;
	var music:String;
}

typedef MenuTransition = {
	var enabled:Bool;
	var color:String;
	var duration:Float;
}

typedef MenuConfig = {
	var layers:Array<MenuLayer>;
	var sounds:MenuSounds;
	var transition:MenuTransition;
	var positions:Dynamic;
}

typedef MenuCustomizationData = {
	var mainmenu:MenuConfig;
	var storymenu:MenuConfig;
	var freeplay:MenuConfig;
	var options:MenuConfig;
	var credits:MenuConfig;
}

class MenuCustomization
{
	public static function getDefaultConfig():MenuConfig
	{
		return {
			layers: [],
			sounds: {
				scroll: 'scrollMenu',
				confirm: 'confirmMenu',
				cancel: 'cancelMenu',
				select: 'scrollMenu',
				music: null
			},
			transition: {
				enabled: false,
				color: '000000',
				duration: 0.4
			},
			positions: {}
		};
	}

	public static function getDefault():MenuCustomizationData
	{
		return {
			mainmenu: getDefaultConfig(),
			storymenu: getDefaultConfig(),
			freeplay: getDefaultConfig(),
			options: getDefaultConfig(),
			credits: getDefaultConfig()
		};
	}

	public static function load():MenuCustomizationData
	{
		var data:MenuCustomizationData = getDefault();
		var raw:String = read();

		if (raw == null)
			return data;

		try
		{
			var parsed:Dynamic = Json.parse(raw);

			if (parsed.mainmenu != null) data.mainmenu = mergeConfig(data.mainmenu, parsed.mainmenu);
			if (parsed.storymenu != null) data.storymenu = mergeConfig(data.storymenu, parsed.storymenu);
			if (parsed.freeplay != null) data.freeplay = mergeConfig(data.freeplay, parsed.freeplay);
			if (parsed.options != null) data.options = mergeConfig(data.options, parsed.options);
			if (parsed.credits != null) data.credits = mergeConfig(data.credits, parsed.credits);
		}
		catch (e:Dynamic)
			trace('MenuCustomization: could not parse ($e)');

		return data;
	}

	static function mergeConfig(base:MenuConfig, input:Dynamic):MenuConfig
	{
		if (input.layers != null && Std.isOfType(input.layers, Array))
			base.layers = cast input.layers;
		if (input.positions != null)
			base.positions = input.positions;

		if (input.sounds != null)
		{
			if (input.sounds.scroll != null) base.sounds.scroll = input.sounds.scroll;
			if (input.sounds.confirm != null) base.sounds.confirm = input.sounds.confirm;
			if (input.sounds.cancel != null) base.sounds.cancel = input.sounds.cancel;
			if (input.sounds.select != null) base.sounds.select = input.sounds.select;
			if (input.sounds.music != null) base.sounds.music = input.sounds.music;
		}

		if (input.transition != null)
		{
			if (input.transition.enabled != null) base.transition.enabled = input.transition.enabled;
			if (input.transition.color != null) base.transition.color = input.transition.color;
			if (input.transition.duration != null) base.transition.duration = input.transition.duration;
		}

		return base;
	}

	public static function save(data:MenuCustomizationData):Bool
	{
		#if sys
		try
		{
			var file:String = path();
			var folder:String = Path.directory(file);
			if (folder.length > 0 && !FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			File.saveContent(file, Json.stringify(data, '\t'));
			return true;
		}
		catch (e:Dynamic)
			trace('MenuCustomization: could not save ($e)');
		#end

		return false;
	}

	public static function path():String
	{
		var mod:String = Mods.currentModDirectory;
		if (mod != null && mod.length > 0)
			return 'mods/$mod/data/menu_custom.json';
		return 'mods/data/menu_custom.json';
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
		catch (e:Dynamic) {}
		#end
		return null;
	}
}
