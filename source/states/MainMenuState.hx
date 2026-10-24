package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import backend.MainMenuConfig;
import backend.MainMenuConfig.MainMenuConfigData;
import backend.MenuCustomization;
import backend.MenuCustomization.MenuCustomizationData;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '0.0.1'; // This is also used for Discord RPC
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;
	var customMenuItems:FlxTypedGroup<FlxSprite>;
	var menuLayers:FlxTypedGroup<FlxSprite>;

	var menuConfig:MainMenuConfigData;
	var menuCustom:MenuCustomizationData;
	var menuCustomCfg:backend.MenuCustomization.MenuConfig;
	var optionShit:Array<String> = [];
	var leftOption:String = null;
	var rightOption:String = null;

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static var showOutdatedWarning:Bool = true;
	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		menuConfig = MainMenuConfig.load();
		MainMenuConfig.sanitize(menuConfig);

		menuCustom = MenuCustomization.load();
		menuCustomCfg = menuCustom.mainmenu;

		applyCustomSounds();

		optionShit = menuConfig.items.copy();
		leftOption = (menuConfig.leftOption != null && menuConfig.leftOption.length > 0) ? menuConfig.leftOption : null;
		rightOption = (menuConfig.rightOption != null && menuConfig.rightOption.length > 0) ? menuConfig.rightOption : null;

		var yScroll:Float = menuConfig.bgScrollSpeed;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image(menuConfig.bgImage));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		menuLayers = new FlxTypedGroup<FlxSprite>();
		add(menuLayers);
		addMenuLayers();

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);
		customMenuItems = new FlxTypedGroup<FlxSprite>();
		add(customMenuItems);

		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, (num * 140) + 90);
			item.y += (4 - optionShit.length) * 70; // Offsets for when you have anything other than 4 items
			item.screenCenter(X);
			applySavedPosition(option, item);
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 60, 490);
			applySavedPosition('leftItem', leftItem);
		}
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
			rightItem.x -= rightItem.width;
			applySavedPosition('rightItem', rightItem);
		}

		addCustomButtons();

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "Cheetah Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();

		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	function applySavedPosition(key:String, item:FlxSprite)
	{
		if (menuConfig.positions == null) return;
		try
		{
			var p = Reflect.field(menuConfig.positions, key);
			if (p != null && Reflect.hasField(p, 'x'))
			{
				item.x = Reflect.field(p, 'x');
				if (Reflect.hasField(p, 'y'))
					item.y = Reflect.field(p, 'y');
				item.updateHitbox();
			}
		}
		catch (e:Dynamic) {}
	}

	function addCustomButtons()
	{
		if (menuConfig.customButtons == null) return;
		for (btn in menuConfig.customButtons)
		{
			var spr:FlxSprite = new FlxSprite(btn.x, btn.y);
			try
			{
				spr.frames = Paths.getSparrowAtlas(btn.image);
				spr.animation.addByPrefix('idle', 'idle', 24, true);
				var base:String = btn.image.split('/').pop();
				if (spr.animation.getByName('idle') == null && base != null)
					spr.animation.addByPrefix('idle', StringTools.replace(base, 'menu_', '') + ' idle', 24, true);
				spr.animation.play('idle');
			}
			catch (e:Dynamic)
			{
				spr.makeGraphic(200, 80, FlxColor.CYAN);
				spr.alpha = 0.8;
			}
			spr.scale.set(btn.scale != 0 ? btn.scale : 1, btn.scale != 0 ? btn.scale : 1);
			spr.antialiasing = btn.antialiasing;
			spr.updateHitbox();
			spr.scrollFactor.set();
			customMenuItems.add(spr);
		}
	}

	function addMenuLayers()
	{
		if (menuCustomCfg == null || menuCustomCfg.layers == null) return;
		for (layer in menuCustomCfg.layers)
		{
			if (!layer.visible) continue;
			var spr:FlxSprite = new FlxSprite(layer.x, layer.y);
			try
			{
				spr.loadGraphic(Paths.image(layer.image));
			}
			catch (e:Dynamic)
			{
				spr.makeGraphic(200, 150, FlxColor.PURPLE);
				spr.alpha = 0.5;
			}
			spr.scale.set(layer.scaleX, layer.scaleY);
			spr.alpha = layer.alpha;
			spr.angle = layer.angle;
			spr.scrollFactor.set(layer.scrollX, layer.scrollY);
			spr.antialiasing = layer.antialiasing;
			spr.updateHitbox();
			if (layer.behindUI)
				spr.scrollFactor.set(0, menuConfig.bgScrollSpeed);
			menuLayers.add(spr);
		}
	}

	function applyCustomSounds()
	{
		if (menuCustomCfg == null || menuCustomCfg.sounds == null) return;
		if (menuCustomCfg.sounds.music != null && menuCustomCfg.sounds.music.length > 0)
		{
			try
			{
				FlxG.sound.playMusic(Paths.music(menuCustomCfg.sounds.music), 0.8);
			}
			catch (e:Dynamic) {}
		}
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if(controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if(controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				var cancelSound:String = (menuCustomCfg != null && menuCustomCfg.sounds != null && menuCustomCfg.sounds.cancel != null) ? menuCustomCfg.sounds.cancel : 'cancelMenu';
				try { FlxG.sound.play(Paths.sound(cancelSound)); } catch(e:Dynamic) { FlxG.sound.play(Paths.sound('cancelMenu')); }
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse))
			{
				var confirmSound:String = (menuCustomCfg != null && menuCustomCfg.sounds != null && menuCustomCfg.sounds.confirm != null) ? menuCustomCfg.sounds.confirm : 'confirmMenu';
				try { FlxG.sound.play(Paths.sound(confirmSound)); } catch(e:Dynamic) { FlxG.sound.play(Paths.sound('confirmMenu')); }
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:String;
				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case LEFT:
						option = leftOption;
						item = leftItem;

					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (option)
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(new FreeplayState());

						#if MODS_ALLOWED
						case 'mods':
							MusicBeatState.switchState(new ModsMenuState());
						#end

						#if ACHIEVEMENTS_ALLOWED
						case 'achievements':
							MusicBeatState.switchState(new AchievementsMenuState());
						#end

						case 'credits':
							MusicBeatState.switchState(new CreditsState());
						case 'options':
							MusicBeatState.switchState(new OptionsState());
							OptionsState.onPlayState = false;
							if (PlayState.SONG != null)
							{
								PlayState.SONG.arrowSkin = null;
								PlayState.SONG.splashSkin = null;
								PlayState.stageUI = 'normal';
							}
						case 'donate':
							CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
							selectedSomethin = false;
							item.visible = true;
						default:
							trace('Menu Item ${option} doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
					}
				});
				
				for (memb in menuItems)
				{
					if(memb == item)
						continue;

					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		var scrollSound:String = (menuCustomCfg != null && menuCustomCfg.sounds != null && menuCustomCfg.sounds.scroll != null) ? menuCustomCfg.sounds.scroll : 'scrollMenu';
		try { FlxG.sound.play(Paths.sound(scrollSound)); } catch(e:Dynamic) { FlxG.sound.play(Paths.sound('scrollMenu')); }

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}
