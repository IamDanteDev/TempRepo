package options;

import backend.StageData;
import backend.MenuCustomization;
import states.MainMenuState;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals',
		'Accessibility',
		'File Access',
		'Gameplay',
		'Customization'
		#if TRANSLATIONS_ALLOWED , 'Language' #end
	];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	var menuLayers:FlxTypedGroup<FlxSprite>;
	var menuCustom:MenuCustomizationData;
	var menuCustomCfg:backend.MenuCustomization.MenuConfig;

	function openSelectedSubstate(label:String) {
		switch(label)
		{
			case 'Note Colors':
				openSubState(new options.NotesColorSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new options.VisualsSettingsSubState());
			case 'Accessibility':
				openSubState(new options.AccessibilitySubState());
			case 'File Access':
				openSubState(new options.FileAccessSubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'Language':
				openSubState(new options.LanguageSubState());
        
			case 'Customization':
			    openSubState(new options.CustomizationSubState());
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		menuCustom = MenuCustomization.load();
		menuCustomCfg = menuCustom.options;
		applyCustomSoundsOptions();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		menuLayers = new FlxTypedGroup<FlxSprite>();
		add(menuLayers);
		addOptionsLayers();

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$option', option), true);
			optionText.screenCenter();
			// scroll like the main menu: the selected item stays centered, the rest slide
			optionText.isMenuItem = true;
			optionText.distancePerItem.set(0, 60);
			optionText.targetY = num;
			optionText.startPosition.set(optionText.x, optionText.y);
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();

		super.create();
	}

	function applyCustomSoundsOptions()
	{
		if (menuCustomCfg == null || menuCustomCfg.sounds == null) return;
		if (menuCustomCfg.sounds.music != null && menuCustomCfg.sounds.music.length > 0)
		{
			try { FlxG.sound.playMusic(Paths.music(menuCustomCfg.sounds.music), 0.8); } catch(e:Dynamic) {}
		}
	}

	function addOptionsLayers()
	{
		if (menuCustomCfg == null || menuCustomCfg.layers == null) return;
		for (layer in menuCustomCfg.layers)
		{
			if (!layer.visible) continue;
			var spr:FlxSprite = new FlxSprite(layer.x, layer.y);
			try { spr.loadGraphic(Paths.image(layer.image)); } catch(e:Dynamic) { spr.makeGraphic(200, 150, 0xFFea71fd); spr.alpha = 0.4; }
			spr.scale.set(layer.scaleX, layer.scaleY);
			spr.alpha = layer.alpha;
			spr.angle = layer.angle;
			spr.scrollFactor.set(layer.scrollX, layer.scrollY);
			spr.antialiasing = layer.antialiasing;
			spr.updateHitbox();
			menuLayers.add(spr);
		}
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		// arrows follow the selected entry while the list slides
		var selected:Alphabet = grpOptions.members[curSelected];
		if (selected != null)
		{
			selectorLeft.x = selected.x - 63;
			selectorLeft.y = selected.y;
			selectorRight.x = selected.x + selected.width + 15;
			selectorRight.y = selected.y;
		}

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else MusicBeatState.switchState(new MainMenuState());
		}
		else if (controls.ACCEPT) openSelectedSubstate(options[curSelected]);
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}