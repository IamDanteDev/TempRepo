package states.editors;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxAxes;
import flixel.util.FlxTimer;

import states.MainMenuState;

#if sys
import sys.FileSystem;
#end

class ModChartEditorState extends MusicBeatState
{
	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("ModChart Editor", null);
		#end

		var txt:FlxText = new FlxText(0, 0, FlxG.width,
			"MODCHART EDITOR\n\n" +
			"FNF Lua Modchart Editor\n\n" +
			"Place the downloaded tool in:\n" +
			"tools/ModChartEditor/\n\n" +
			"Searching for executable...\n\n" +
			"Press BACK to return to the Editor Menu",
		24);
		txt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.screenCenter(FlxAxes.XY);
		txt.borderSize = 2;
		add(txt);

		#if desktop
		#if sys
		var paths:Array<String> = [
			"/home/dante/Descargas/FNF-CheetahEngineDevbuildv1/ModChartEditor/",
			Sys.getCwd() + "/ModChartEditor/",
			Sys.getCwd() + "/../../../ModChartEditor/",
			"../../../ModChartEditor/",
			"../../ModChartEditor/",
			"../ModChartEditor/",
			"ModChartEditor/",
			"../../../../ModChartEditor/",
			"tools/ModChartEditor/",
			"./ModChartEditor/"
		];
		var launched:Bool = false;

		for (toolPath in paths)
		{
			if (launched) break;
			if (!FileSystem.exists(toolPath)) continue;

			var exe:String = toolPath + "ModChartEditor.exe";
			if (!FileSystem.exists(exe)) exe = toolPath + "FNF Lua Modchart Editor.exe";
			if (!FileSystem.exists(exe)) exe = toolPath + "Modchart Editor.exe";
			if (!FileSystem.exists(exe)) exe = toolPath + "Lua Modchart Editor.exe";
			if (!FileSystem.exists(exe)) exe = toolPath + "modchart_editor";

			if (!FileSystem.exists(exe))
			{
				try
				{
					var files:Array<String> = FileSystem.readDirectory(toolPath);
					for (file in files)
					{
						if (StringTools.endsWith(file.toLowerCase(), ".exe"))
						{
							exe = toolPath + file;
							break;
						}
						if (!StringTools.contains(file, ".") && !FileSystem.isDirectory(toolPath + file))
						{
							exe = toolPath + file;
							break;
						}
					}
				}
				catch(e:Dynamic) {}
			}

			if (FileSystem.exists(exe) && !FileSystem.isDirectory(exe))
			{
				txt.text = "MODCHART EDITOR\n\n" +
					"Launching ModChartEditor.exe...\n\n" +
					"Opening in a new window.\n\n" +
					"Press BACK to return to the Editor Menu";
				txt.screenCenter(FlxAxes.XY);

				#if windows
				Sys.command("cmd", ["/c", "start", "", exe]);
				#elseif linux
				Sys.command("wine", [exe]);
				#elseif mac
				Sys.command("open", ["-a", "Wine", exe]);
				#end

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MasterEditorMenu());
				});
				super.create();
				return;
			}
		}

		txt.text = "MODCHART EDITOR\n\n" +
			"ModChartEditor.exe not found.\n\n" +
			"Place it in:\n" +
			"./ModChartEditor/ModChartEditor.exe\n\n" +
			"Press BACK to return to the Editor Menu";
		txt.screenCenter(FlxAxes.XY);
		#else
		CoolUtil.browserLoad("https://gamebanana.com/tools/10566#Files");
		#end
		#end

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
		}

		super.update(elapsed);
	}
}
