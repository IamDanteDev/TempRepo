package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import backend.MainMenuConfig;
import backend.MainMenuConfig.MainMenuConfigData;
import backend.MenuCustomization;
import backend.MenuCustomization.MenuCustomizationData;
import backend.MenuCustomization.MenuLayer;
import backend.ui.PsychUIBox;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIButton;
import backend.ui.PsychUIInputText;
import backend.ui.PsychUINumericStepper;
import backend.ui.PsychUIEventHandler;

import states.editors.content.Prompt;
import states.MainMenuState;

class MainMenuEditorState extends MusicBeatState
{
	public static var currentMenu:String = 'mainmenu';

	var config:MainMenuConfigData;
	var menuCustom:MenuCustomizationData;
	var unsavedProgress:Bool = false;
	var currentConfigKey:String = 'mainmenu';

	var bgSprite:FlxSprite;
	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;
	var customSprites:FlxTypedGroup<FlxSprite>;
	var layersGroup:FlxTypedGroup<FlxSprite>;

	var itemChecks:Array<PsychUICheckBox> = [];
	var leftCheck:PsychUICheckBox;
	var rightCheck:PsychUICheckBox;
	var bgInput:PsychUIInputText;
	var scrollStepper:PsychUINumericStepper;

	var infoText:FlxText;
	var selectedSprite:FlxSprite = null;
	var dragging:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;

		currentConfigKey = currentMenu;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Menu Editor", currentConfigKey);
		#end

		config = MainMenuConfig.load();
		MainMenuConfig.sanitize(config);

		menuCustom = MenuCustomization.load();

		if (currentConfigKey == 'mainmenu')
		{
			bgSprite = new FlxSprite(-80).loadGraphic(Paths.image(config.bgImage));
			bgSprite.antialiasing = ClientPrefs.data.antialiasing;
			bgSprite.scrollFactor.set(0, config.bgScrollSpeed);
			bgSprite.setGraphicSize(Std.int(bgSprite.width * 1.175));
			bgSprite.updateHitbox();
			bgSprite.screenCenter();
		}
		else
		{
			bgSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
			bgSprite.antialiasing = ClientPrefs.data.antialiasing;
			bgSprite.scrollFactor.set();
			bgSprite.color = getMenuColor();
			bgSprite.setGraphicSize(Std.int(bgSprite.width * 1.2));
			bgSprite.updateHitbox();
			bgSprite.screenCenter();
		}
		add(bgSprite);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		customSprites = new FlxTypedGroup<FlxSprite>();
		add(customSprites);

		layersGroup = new FlxTypedGroup<FlxSprite>();
		add(layersGroup);

		if (currentConfigKey == 'mainmenu')
			rebuildMenuPreview();
		rebuildLayers();

		var title:FlxText = new FlxText(0, 8, FlxG.width, "MENU EDITOR - " + getMenuTitle());
		title.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		title.scrollFactor.set();
		add(title);

		infoText = new FlxText(0, title.y + title.height + 2, FlxG.width, "Left click and drag to reposition | Right click to reset position | Edit layers/sounds/transitions");
		infoText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 1.5;
		infoText.scrollFactor.set();
		add(infoText);

		var tabs:Array<String> = ['Layers', 'Sounds', 'Transitions'];
		if (currentConfigKey == 'mainmenu')
			tabs = ['Items', 'Background', 'Custom', 'Layers', 'Sounds', 'Transitions'];
		var uiBox:PsychUIBox = new PsychUIBox(10, 70, 340, 300, tabs);
		uiBox.scrollFactor.set();
		add(uiBox);
		if (currentConfigKey == 'mainmenu')
		{
			addItemsUI(uiBox);
			addBackgroundUI(uiBox);
			addCustomUI(uiBox);
		}
		addLayersUI(uiBox);
		addSoundsUI(uiBox);
		addTransitionsUI(uiBox);

		var saveButton:PsychUIButton = new PsychUIButton(FlxG.width / 2 - 195, FlxG.height - 48, "Save", saveConfig, 120, 24);
		add(saveButton);

		var testButton:PsychUIButton = new PsychUIButton(FlxG.width / 2 - 60, FlxG.height - 48, "Test Menu", testMenu, 120, 24);
		add(testButton);

		var backButton:PsychUIButton = new PsychUIButton(FlxG.width / 2 + 75, FlxG.height - 48, "Back", goBack, 120, 24);
		add(backButton);

		var pathText:FlxText = new FlxText(10, FlxG.height - 22, 0, "MainMenu: " + MainMenuConfig.path() + " | MenuCustom: " + MenuCustomization.path());
		pathText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pathText.borderSize = 1.5;
		pathText.scrollFactor.set();
		add(pathText);

		FlxG.mouse.visible = true;
		super.create();
	}

	function getMenuTitle():String
	{
		switch (currentConfigKey)
		{
			case 'mainmenu': return "MAIN MENU";
			case 'storymenu': return "STORY MODE MENU";
			case 'freeplay': return "FREEPLAY MENU";
			case 'options': return "OPTIONS MENU";
			case 'credits': return "CREDITS MENU";
			default: return currentConfigKey.toUpperCase();
		}
	}

	function getMenuColor():FlxColor
	{
		switch (currentConfigKey)
		{
			case 'storymenu': return 0xFFf9cf51;
			case 'freeplay': return 0xFF9271fd;
			case 'options': return 0xFFea71fd;
			case 'credits': return 0xFF71fd92;
			default: return 0xFF353535;
		}
	}

	function addItemsUI(uiBox:PsychUIBox)
	{
		var tabGroup = uiBox.getTab('Items').menu;
		var y:Float = 12;
		var x:Float = 16;

		var label:FlxText = new FlxText(x, y, 280, "Center items:");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 20;

		for (item in MainMenuConfig.AVAILABLE_ITEMS)
		{
			var checked:Bool = config.items.indexOf(item) > -1;
			var box:PsychUICheckBox = new PsychUICheckBox(x, y, prettyName(item), 250, function()
			{
				toggleCenter(item);
			});
			box.checked = checked;
			itemChecks.push(box);
			tabGroup.add(box);
			y += 22;
		}

		y += 6;
		label = new FlxText(x, y, 280, "Side items:");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 20;

		leftCheck = new PsychUICheckBox(x, y, "Left: " + prettyName(config.leftOption), 250, function() { toggleSide('left'); });
		leftCheck.checked = (config.leftOption != null && config.leftOption.length > 0);
		tabGroup.add(leftCheck);
		y += 22;

		rightCheck = new PsychUICheckBox(x, y, "Right: " + prettyName(config.rightOption), 250, function() { toggleSide('right'); });
		rightCheck.checked = (config.rightOption != null && config.rightOption.length > 0);
		tabGroup.add(rightCheck);
	}

	function addBackgroundUI(uiBox:PsychUIBox)
	{
		var tabGroup = uiBox.getTab('Background').menu;
		var y:Float = 16;
		var x:Float = 16;

		var label:FlxText = new FlxText(x, y, 280, "Background image (without .png):");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 22;

		bgInput = new PsychUIInputText(x, y, 270, config.bgImage);
		tabGroup.add(bgInput);

		y += 38;
		label = new FlxText(x, y, 280, "Scroll speed:");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 22;

		scrollStepper = new PsychUINumericStepper(x, y, 0.05, config.bgScrollSpeed, 0, 1, 2, 80);
		tabGroup.add(scrollStepper);
	}

	function addCustomUI(uiBox:PsychUIBox)
	{
		var tabGroup = uiBox.getTab('Custom').menu;
		var y:Float = 12;
		var x:Float = 16;

		var label:FlxText = new FlxText(x, y, 300, "Custom buttons (drag to place):");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 24;

		var addBtn:PsychUIButton = new PsychUIButton(x, y, "Add Custom Button", function()
		{
			addCustomButton();
		}, 300, 24);
		tabGroup.add(addBtn);
		y += 32;

		var clearBtn:PsychUIButton = new PsychUIButton(x, y, "Clear All", function()
		{
			config.customButtons = [];
			MainMenuConfig.sanitize(config);
			rebuildMenuPreview();
			unsavedProgress = true;
		}, 300, 24);
		tabGroup.add(clearBtn);
	}

	function addLayersUI(uiBox:PsychUIBox)
	{
		var tabGroup = uiBox.getTab('Layers').menu;
		var y:Float = 12;
		var x:Float = 16;

		var label:FlxText = new FlxText(x, y, 300, "Decorative/Image Layers (drag to place):");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 24;

		var addLayer:PsychUIButton = new PsychUIButton(x, y, "Add Layer (menuDesat)", function()
		{
			addLayer();
		}, 300, 24);
		tabGroup.add(addLayer);
		y += 32;

		var resetLayers:PsychUIButton = new PsychUIButton(x, y, "Reset Layers", function()
		{
			getCurrentMenuConfig().layers = [];
			rebuildLayers();
			unsavedProgress = true;
		}, 300, 24);
		tabGroup.add(resetLayers);
	}

	function addSoundsUI(uiBox:PsychUIBox)
	{
		var tabGroup = uiBox.getTab('Sounds').menu;
		var y:Float = 12;
		var x:Float = 16;
		var sounds = getCurrentMenuConfig().sounds;

		var label:FlxText = new FlxText(x, y, 300, "Per-menu Sounds (sound names without .ogg):");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 26;

		tabGroup.add(makeSoundLabel(x, y, "Scroll")); tabGroup.add(makeSoundInput(x + 95, y - 2, sounds.scroll, function(v:String){ sounds.scroll = v; unsavedProgress = true; }));
		y += 26;
		tabGroup.add(makeSoundLabel(x, y, "Confirm")); tabGroup.add(makeSoundInput(x + 95, y - 2, sounds.confirm, function(v:String){ sounds.confirm = v; unsavedProgress = true; }));
		y += 26;
		tabGroup.add(makeSoundLabel(x, y, "Cancel")); tabGroup.add(makeSoundInput(x + 95, y - 2, sounds.cancel, function(v:String){ sounds.cancel = v; unsavedProgress = true; }));
		y += 26;
		tabGroup.add(makeSoundLabel(x, y, "Select")); tabGroup.add(makeSoundInput(x + 95, y - 2, sounds.select, function(v:String){ sounds.select = v; unsavedProgress = true; }));
		y += 26;
		tabGroup.add(makeSoundLabel(x, y, "Music")); tabGroup.add(makeSoundInput(x + 95, y - 2, sounds.music == null ? '' : sounds.music, function(v:String){ sounds.music = (v == null || v.length < 1) ? null : v; unsavedProgress = true; }));
	}

	function makeSoundLabel(x:Float, y:Float, name:String):FlxText
	{
		var lbl:FlxText = new FlxText(x, y, 90, name + ":");
		lbl.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		lbl.borderSize = 1;
		return lbl;
	}

	function makeSoundInput(x:Float, y:Float, val:String, onChange:String->Void):PsychUIInputText
	{
		var input:PsychUIInputText = new PsychUIInputText(x, y, 190, val == null ? '' : val);
		return input;
	}

	function addTransitionsUI(uiBox:PsychUIBox)
	{
		var tabGroup = uiBox.getTab('Transitions').menu;
		var y:Float = 12;
		var x:Float = 16;
		var trans = getCurrentMenuConfig().transition;

		var label:FlxText = new FlxText(x, y, 300, "Custom transition for this menu:");
		label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1;
		tabGroup.add(label);
		y += 24;

		var enable:PsychUICheckBox = new PsychUICheckBox(x, y, "Enable custom transition", 280, function()
		{
			trans.enabled = !trans.enabled;
			unsavedProgress = true;
		});
		enable.checked = trans.enabled;
		tabGroup.add(enable);
		y += 26;

		var colLabel:FlxText = new FlxText(x, y, 280, "Color (hex without #):");
		colLabel.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		colLabel.borderSize = 1;
		tabGroup.add(colLabel);
		y += 20;

		var colInput:PsychUIInputText = new PsychUIInputText(x, y, 150, trans.color);
		tabGroup.add(colInput);
		y += 40;

		var durLabel:FlxText = new FlxText(x, y, 280, "Duration (seconds):");
		durLabel.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		durLabel.borderSize = 1;
		tabGroup.add(durLabel);
		y += 20;

		var durStep:PsychUINumericStepper = new PsychUINumericStepper(x, y, 0.05, trans.duration, 0.1, 1.0, 2, 80);
		tabGroup.add(durStep);
	}

	function getCurrentMenuConfig()
	{
		switch (currentConfigKey)
		{
			case 'storymenu': return menuCustom.storymenu;
			case 'freeplay': return menuCustom.freeplay;
			case 'options': return menuCustom.options;
			case 'credits': return menuCustom.credits;
			default: return menuCustom.mainmenu;
		}
	}

	function addLayer()
	{
		var id:String = "layer_" + Date.now().getTime();
		var cfg = getCurrentMenuConfig();
		cfg.layers.push({
			id: id,
			image: "menuDesat",
			x: FlxG.width / 2,
			y: FlxG.height / 2,
			scaleX: 1,
			scaleY: 1,
			alpha: 0.8,
			angle: 0,
			scrollX: 0,
			scrollY: 0,
			antialiasing: true,
			visible: true,
			behindUI: true
		});
		rebuildLayers();
		unsavedProgress = true;
	}

	function rebuildLayers()
	{
		for (item in layersGroup.members)
			layersGroup.remove(item, true);
		layersGroup.clear();

		var cfg = getCurrentMenuConfig();
		for (layer in cfg.layers)
		{
			var spr:FlxSprite = new FlxSprite(layer.x, layer.y);
			try
			{
				spr.loadGraphic(Paths.image(layer.image));
			}
			catch (e:Dynamic)
			{
				spr.makeGraphic(200, 150, FlxColor.PURPLE);
			}
			spr.scale.set(layer.scaleX, layer.scaleY);
			spr.alpha = layer.alpha;
			spr.angle = layer.angle;
			spr.scrollFactor.set(layer.scrollX, layer.scrollY);
			spr.antialiasing = layer.antialiasing;
			spr.updateHitbox();
			spr.ID = 8888;
			layersGroup.add(spr);
		}
	}

	function addCustomButton()
	{
		var id:String = "custom_" + Date.now().getTime();
		config.customButtons.push({
			id: id,
			image: "mainmenu/menu_story_mode",
			label: "Custom",
			action: "url",
			url: "https://gamebanana.com/",
			targetState: "",
			x: FlxG.width / 2,
			y: FlxG.height / 2,
			scale: 1,
			antialiasing: true
		});
		MainMenuConfig.sanitize(config);
		rebuildMenuPreview();
		unsavedProgress = true;
	}

	function rebuildMenuPreview()
	{
		for (item in menuItems.members)
			menuItems.remove(item, true);
		for (item in customSprites.members)
			customSprites.remove(item, true);

		menuItems.clear();
		customSprites.clear();

		for (num => option in config.items)
		{
			var item:FlxSprite = createMenuItemPreview(option);
			var defX:Float = 0;
			var defY:Float = (num * 140) + 90;
			item.x = getSavedX(option, defX, defY);
			item.y = getSavedY(option, defX, defY);
			item.screenCenter(X);
			item.x = getSavedX(option, item.x, defY);
			item.y = getSavedY(option, item.x, defY);
		}

		if (config.leftOption != null && config.leftOption.length > 0)
		{
			leftItem = createMenuItemPreview(config.leftOption);
			leftItem.x = getSavedX("leftItem", 60, 490);
			leftItem.y = getSavedY("leftItem", leftItem.x, 490);
		}
		if (config.rightOption != null && config.rightOption.length > 0)
		{
			rightItem = createMenuItemPreview(config.rightOption);
			rightItem.x = getSavedX("rightItem", FlxG.width - 60 - 200, 490);
			rightItem.y = getSavedY("rightItem", rightItem.x, 490);
		}

		if (config.customButtons != null)
		{
			for (btn in config.customButtons)
			{
				var spr:FlxSprite = new FlxSprite(btn.x, btn.y);
				try
				{
					spr.frames = Paths.getSparrowAtlas(btn.image);
					spr.animation.addByPrefix('idle', 'idle', 24, true);
					if (spr.animation.getByName('idle') == null)
						spr.animation.addByPrefix('idle', StringTools.replace(btn.image.split('/').pop(), 'menu_', '') + ' idle', 24, true);
					spr.animation.play('idle');
				}
				catch (e:Dynamic)
				{
					spr.makeGraphic(200, 80, FlxColor.CYAN);
					spr.alpha = 0.7;
				}
				spr.scale.set(btn.scale, btn.scale);
				spr.antialiasing = btn.antialiasing;
				spr.updateHitbox();
				spr.ID = 9999;
				customSprites.add(spr);
			}
		}
	}

	function createMenuItemPreview(name:String):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite();
		try
		{
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
			menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
			menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
			menuItem.animation.play('idle');
		}
		catch (e:Dynamic)
		{
			menuItem.makeGraphic(300, 100, FlxColor.GRAY);
			menuItem.alpha = 0.6;
		}
		menuItem.updateHitbox();
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItems.add(menuItem);
		return menuItem;
	}

	function getSavedX(key:String, defX:Float, defY:Float):Float
	{
		if (config.positions == null) return defX;
		try
		{
			var p = Reflect.field(config.positions, key);
			if (p != null && Reflect.hasField(p, 'x'))
				return Reflect.field(p, 'x');
		}
		catch (e:Dynamic) {}
		return defX;
	}

	function getSavedY(key:String, defX:Float, defY:Float):Float
	{
		if (config.positions == null) return defY;
		try
		{
			var p = Reflect.field(config.positions, key);
			if (p != null && Reflect.hasField(p, 'y'))
				return Reflect.field(p, 'y');
		}
		catch (e:Dynamic) {}
		return defY;
	}

	function savePositions()
	{
		if (config.positions == null) config.positions = {};
		var idx:Int = 0;
		for (item in config.items)
		{
			var spr = menuItems.members[idx];
			if (spr != null)
			{
				Reflect.setField(config.positions, item, {x: spr.x, y: spr.y});
			}
			idx++;
		}
		if (leftItem != null) Reflect.setField(config.positions, "leftItem", {x: leftItem.x, y: leftItem.y});
		if (rightItem != null) Reflect.setField(config.positions, "rightItem", {x: rightItem.x, y: rightItem.y});
		for (i in 0...customSprites.members.length)
		{
			if (config.customButtons[i] != null && customSprites.members[i] != null)
			{
				config.customButtons[i].x = customSprites.members[i].x;
				config.customButtons[i].y = customSprites.members[i].y;
			}
		}
	}

	function toggleCenter(item:String)
	{
		unsavedProgress = true;
		if (config.items.indexOf(item) > -1)
		{
			if (config.items.length <= 1) return;
			var filtered:Array<String> = [];
			for (it in config.items) if (it != item) filtered.push(it);
			config.items = filtered;
		}
		else
		{
			if (MainMenuConfig.AVAILABLE_ITEMS.indexOf(item) > -1) config.items.push(item);
		}
		MainMenuConfig.sanitize(config);
		rebuildMenuPreview();
		refreshChecks();
	}

	function toggleSide(side:String)
	{
		unsavedProgress = true;
		if (side == 'left')
		{
			config.leftOption = (config.leftOption != null && config.leftOption.length > 0) ? '' : getFreeSide();
		}
		else
		{
			config.rightOption = (config.rightOption != null && config.rightOption.length > 0) ? '' : getFreeSide();
		}
		MainMenuConfig.sanitize(config);
		rebuildMenuPreview();
		refreshChecks();
	}

	function getFreeSide():String
	{
		for (item in MainMenuConfig.AVAILABLE_ITEMS)
		{
			if (config.items.indexOf(item) > -1) continue;
			if (config.leftOption == item || config.rightOption == item) continue;
			return item;
		}
		return 'options';
	}

	function refreshChecks()
	{
		for (box in itemChecks)
		{
			var name:String = StringTools.replace(box.label, " ", "_").toLowerCase();
			var item:String = null;
			for (a in MainMenuConfig.AVAILABLE_ITEMS) if (a == name) item = a;
			if (item != null) box.checked = config.items.indexOf(item) > -1;
		}
		leftCheck.checked = (config.leftOption != null && config.leftOption.length > 0);
		rightCheck.checked = (config.rightOption != null && config.rightOption.length > 0);
		leftCheck.label = "Left: " + prettyName(config.leftOption);
		rightCheck.label = "Right: " + prettyName(config.rightOption);
	}

	function prettyName(item:String):String
	{
		if (item == null || item.length < 1) return "None";
		switch (item)
		{
			case 'story_mode': return "Story Mode";
			case 'freeplay': return "Freeplay";
			case 'mods': return "Mods";
			case 'credits': return "Credits";
			case 'achievements': return "Achievements";
			case 'options': return "Options";
			default: return item;
		}
	}

	function saveConfig()
	{
		savePositions();
		if (bgInput != null) config.bgImage = bgInput.text;
		if (scrollStepper != null) config.bgScrollSpeed = scrollStepper.value;
		bgSprite.loadGraphic(Paths.image(config.bgImage));
		bgSprite.scrollFactor.set(0, config.bgScrollSpeed);
		bgSprite.setGraphicSize(Std.int(bgSprite.width * 1.175));
		bgSprite.updateHitbox();
		bgSprite.screenCenter();

		saveLayerPositions();
		saveCurrentMenuCustom();

		MainMenuConfig.sanitize(config);
		var saved1 = MainMenuConfig.save(config);
		var saved2 = MenuCustomization.save(menuCustom);

		if (saved1 || saved2)
		{
			unsavedProgress = false;
			infoText.text = "Saved!";
		}
		else
			infoText.text = "Failed to save.";
	}

	function saveLayerPositions()
	{
		var cfg = getCurrentMenuConfig();
		for (i in 0...layersGroup.members.length)
		{
			if (cfg.layers[i] != null && layersGroup.members[i] != null)
			{
				cfg.layers[i].x = layersGroup.members[i].x;
				cfg.layers[i].y = layersGroup.members[i].y;
			}
		}
	}

	function saveCurrentMenuCustom()
	{
		var cfg = getCurrentMenuConfig();
		var sounds = cfg.sounds;
		// sounds updated via direct reference above in simple form
		cfg.sounds = sounds;
	}

	function testMenu()
	{
		savePositions();
		if (bgInput != null) config.bgImage = bgInput.text;
		if (scrollStepper != null) config.bgScrollSpeed = scrollStepper.value;
		bgSprite.loadGraphic(Paths.image(config.bgImage));
		bgSprite.scrollFactor.set(0, config.bgScrollSpeed);
		bgSprite.setGraphicSize(Std.int(bgSprite.width * 1.175));
		bgSprite.updateHitbox();
		bgSprite.screenCenter();
		MainMenuConfig.sanitize(config);
		MainMenuConfig.save(config);
		unsavedProgress = false;
		FlxG.mouse.visible = false;
		MusicBeatState.switchState(new MainMenuState());
	}

	function goBack()
	{
		if (!unsavedProgress)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			return;
		}
		openSubState(new ExitConfirmationPrompt());
	}

	override function update(elapsed:Float)
	{
		if (PsychUIInputText.focusOn == null)
		{
			if (FlxG.mouse.justPressed)
			{
				selectedSprite = getSpriteUnderMouse();
				if (selectedSprite != null)
				{
					dragging = true;
					dragOffsetX = selectedSprite.x - FlxG.mouse.x;
					dragOffsetY = selectedSprite.y - FlxG.mouse.y;
					unsavedProgress = true;
				}
			}
			if (FlxG.mouse.justReleased)
			{
				dragging = false;
				selectedSprite = null;
			}
			if (FlxG.mouse.pressed && dragging && selectedSprite != null)
			{
				selectedSprite.x = FlxG.mouse.x + dragOffsetX;
				selectedSprite.y = FlxG.mouse.y + dragOffsetY;
			}
			if (FlxG.mouse.justPressedRight)
			{
				var spr = getSpriteUnderMouse();
				if (spr != null)
				{
					rebuildMenuPreview();
					unsavedProgress = true;
				}
			}
			if (controls.BACK)
				goBack();
		}
		else
			ClientPrefs.toggleVolumeKeys(false);

		super.update(elapsed);
	}

	function getSpriteUnderMouse():FlxSprite
	{
		for (i in 0...layersGroup.members.length)
		{
			var spr = layersGroup.members[i];
			if (spr != null && FlxG.mouse.overlaps(spr))
				return spr;
		}
		for (i in 0...customSprites.members.length)
		{
			var spr = customSprites.members[i];
			if (spr != null && FlxG.mouse.overlaps(spr))
				return spr;
		}
		for (i in 0...menuItems.members.length)
		{
			var spr = menuItems.members[i];
			if (spr != null && FlxG.mouse.overlaps(spr))
				return spr;
		}
		if (leftItem != null && FlxG.mouse.overlaps(leftItem))
			return leftItem;
		if (rightItem != null && FlxG.mouse.overlaps(rightItem))
			return rightItem;
		return null;
	}
}
