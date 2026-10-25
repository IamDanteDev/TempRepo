package states.editors;

import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import states.MainMenuState;

class MenuHubEditorState extends MusicBeatState
{
	var options:Array<String> = [
		'Main Menu'
	];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var curSelected:Int = 0;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Menu Customization Hub", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF4A148C;
		add(bg);

		var title:FlxText = new FlxText(0, 60, FlxG.width, "MENU CUSTOMIZATION");
		title.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 3;
		title.scrollFactor.set();
		add(title);

		var desc:FlxText = new FlxText(0, title.y + title.height + 10, FlxG.width, "Edit layers, sounds, transitions and more per menu");
		desc.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		desc.borderSize = 1.5;
		desc.scrollFactor.set();
		add(desc);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
			leText.snapToPosition();
		}

		changeSelection();
		FlxG.mouse.visible = false;
		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.BACK)
			MusicBeatState.switchState(new MasterEditorMenu());

		if (controls.ACCEPT)
		{
			switch(options[curSelected])
			{
				case 'Main Menu':
					MainMenuEditorState.currentMenu = 'mainmenu';
					MusicBeatState.switchState(new MainMenuEditorState());
			}
		}

		for (num => item in grpTexts.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
				item.alpha = 1;
		}

		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
	}
}
