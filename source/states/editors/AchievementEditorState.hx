package states.editors;

import backend.Achievements;
import backend.ui.PsychUIBox;
import backend.ui.PsychUIButton;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIInputText;
import backend.ui.PsychUINumericStepper;

import states.editors.content.Prompt;

// Create, modify and remove custom achievements. They are stored in the save file
// (see Achievements.customAchievements) so they survive restarts without touching any mod.
class AchievementEditorState extends MusicBeatState
{
	static final LIST_X:Float = 20;
	static final LIST_Y:Float = 150;
	static final LIST_WIDTH:Float = 300;
	static final MAX_VISIBLE:Int = 14;
	static final ITEM_HEIGHT:Int = 34;

	var listItems:Array<FlxText> = [];
	var customList:Array<Achievement> = [];
	var curSelected:Int = -1;
	var listScroll:Int = 0;

	var saveInput:PsychUIInputText;
	var nameInput:PsychUIInputText;
	var descInput:PsychUIInputText;
	var imageInput:PsychUIInputText;
	var hiddenCheck:PsychUICheckBox;
	var maxScoreStepper:PsychUINumericStepper;
	var decimalsStepper:PsychUINumericStepper;
	var iconPreview:FlxSprite;
	var previewText:FlxText;
	var statusText:FlxText;
	var emptyText:FlxText;

	override function create()
	{
		FlxG.mouse.visible = true;
		FlxG.sound.volumeUpKeys = [];
		FlxG.sound.volumeDownKeys = [];
		FlxG.sound.muteKeys = [];

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Achievement Editor", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF1B5E20;
		add(bg);

		var title:FlxText = new FlxText(0, 20, FlxG.width, "ACHIEVEMENT EDITOR");
		title.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 3;
		title.scrollFactor.set();
		add(title);

		var listBg:FlxSprite = new FlxSprite(LIST_X, 90).makeGraphic(Std.int(LIST_WIDTH), 540, FlxColor.BLACK);
		listBg.alpha = 0.6;
		listBg.scrollFactor.set();
		add(listBg);

		var listTitle:FlxText = new FlxText(LIST_X + 15, 100, LIST_WIDTH - 30, "CUSTOM ACHIEVEMENTS", 20);
		listTitle.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		listTitle.borderSize = 1.5;
		listTitle.scrollFactor.set();
		add(listTitle);

		emptyText = new FlxText(LIST_X + 15, LIST_Y, LIST_WIDTH - 30, "No custom achievements yet.", 16);
		emptyText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER);
		emptyText.scrollFactor.set();
		add(emptyText);

		var properties:PsychUIBox = new PsychUIBox(340, 90, 620, 540, ["Achievement"]);
		properties.canMove = properties.canMinimize = false;
		add(properties);

		var menu = properties.getTab('Achievement').menu;

		menu.add(new FlxText(15, 40, 300, 'Save Key (letters, numbers, "_" and "-")', 16));
		saveInput = new PsychUIInputText(15, 58, 220, '', 16);
		saveInput.maxLength = 40;
		saveInput.onChange = function(old:String, cur:String) updatePreview();
		menu.add(saveInput);

		menu.add(new FlxText(15, 110, 300, 'Display Name', 16));
		nameInput = new PsychUIInputText(15, 128, 420, '', 16);
		nameInput.maxLength = 60;
		menu.add(nameInput);

		menu.add(new FlxText(15, 180, 300, 'Description', 16));
		descInput = new PsychUIInputText(15, 198, 570, '', 16);
		descInput.maxLength = 140;
		menu.add(descInput);

		menu.add(new FlxText(15, 250, 300, 'Image (path under images/, no .png)', 16));
		imageInput = new PsychUIInputText(15, 268, 290, '', 16);
		imageInput.maxLength = 120;
		imageInput.onChange = function(old:String, cur:String) updatePreview();
		menu.add(imageInput);

		hiddenCheck = new PsychUICheckBox(15, 310, "Hidden until unlocked", 220);
		menu.add(hiddenCheck);

		menu.add(new FlxText(15, 355, 400, 'Max Score (0 = score disabled)', 16));
		maxScoreStepper = new PsychUINumericStepper(15, 373, 1, 0, 0, 10000, 0);
		menu.add(maxScoreStepper);

		menu.add(new FlxText(165, 361, 200, 'Max Decimals', 16));
		decimalsStepper = new PsychUINumericStepper(165, 379, 1, 0, 0, 3, 0);
		menu.add(decimalsStepper);

		menu.add(new FlxText(330, 40, 200, 'Preview', 16));
		iconPreview = new FlxSprite(330, 62);
		iconPreview.visible = false;
		menu.add(iconPreview);

		previewText = new FlxText(330, 200, 270, '', 14);
		previewText.wordWrap = true;
		previewText.fieldWidth = 270;
		previewText.color = FlxColor.WHITE;
		menu.add(previewText);

		var newButton:PsychUIButton = new PsychUIButton(15, 440, "New", newForm, 90, 28);
		menu.add(newButton);

		var saveButton:PsychUIButton = new PsychUIButton(115, 440, "Save", saveForm, 90, 28);
		saveButton.normalStyle.bgColor = 0xFF4CAF50;
		saveButton.normalStyle.textColor = FlxColor.WHITE;
		menu.add(saveButton);

		var deleteButton:PsychUIButton = new PsychUIButton(215, 440, "Delete", deleteSelected, 90, 28);
		deleteButton.normalStyle.bgColor = 0xFFB71C1C;
		deleteButton.normalStyle.textColor = FlxColor.WHITE;
		menu.add(deleteButton);

		statusText = new FlxText(340, 638, 620, '', 18);
		statusText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 1.5;
		statusText.scrollFactor.set();
		add(statusText);

		var hint:FlxText = new FlxText(0, FlxG.height - 26, FlxG.width, "Up/Down or click: select  |  ESC: back");
		hint.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.borderSize = 1;
		hint.scrollFactor.set();
		add(hint);

		refreshList();
		newForm();

		super.create();
	}

	override function update(elapsed:Float)
	{
		if(controls.BACK && PsychUIInputText.focusOn == null)
		{
			PsychUIInputText.focusOn = null;
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}

		if(PsychUIInputText.focusOn == null)
		{
			if(controls.UI_DOWN_P) changeSelection(1);
			if(controls.UI_UP_P) changeSelection(-1);
			if(FlxG.mouse.justPressed) checkClick();
		}

		super.update(elapsed);
	}

	function checkClick()
	{
		for (i in 0...listItems.length)
		{
			var item:FlxText = listItems[i];
			if(!item.visible) continue;

			if(FlxG.mouse.overlaps(item))
			{
				if(curSelected != i)
				{
					curSelected = i;
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					applySelection();
				}
				return;
			}
		}
	}

	function changeSelection(change:Int = 0)
	{
		if(listItems.length < 1) return;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, listItems.length - 1);
		applySelection();
	}

	function refreshList()
	{
		for (item in listItems)
		{
			remove(item);
			item.destroy();
		}
		listItems = [];
		customList = Achievements.getCustomList();

		for (i in 0...customList.length)
		{
			var item:FlxText = new FlxText(LIST_X + 15, LIST_Y + i * ITEM_HEIGHT, LIST_WIDTH - 30, '', 18);
			item.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			item.borderSize = 1;
			item.scrollFactor.set();
			add(item);
			listItems.push(item);
		}

		emptyText.visible = customList.length < 1;

		updateListVisuals();
	}

	function updateListVisuals()
	{
		if(curSelected >= 0)
		{
			if(curSelected < listScroll) listScroll = curSelected;
			else if(curSelected >= listScroll + MAX_VISIBLE) listScroll = curSelected - MAX_VISIBLE + 1;
		}
		else listScroll = 0;

		for (i in 0...listItems.length)
		{
			var item:FlxText = listItems[i];
			var achieve:Achievement = customList[i];
			var selected:Bool = (i == curSelected);

			item.visible = i >= listScroll && i < listScroll + MAX_VISIBLE;
			item.y = LIST_Y + (i - listScroll) * ITEM_HEIGHT;
			item.color = selected ? FlxColor.YELLOW : FlxColor.WHITE;
			item.text = (selected ? '> ' : '  ') + achieve.name + (achieve.hidden == true ? ' [H]' : '');
		}
	}

	function applySelection()
	{
		updateListVisuals();
		if(curSelected < 0 || curSelected >= customList.length) return;

		var achieve:Achievement = customList[curSelected];
		saveInput.text = achieve.save;
		nameInput.text = achieve.name;
		descInput.text = achieve.description;
		imageInput.text = achieve.image != null ? achieve.image : '';
		hiddenCheck.checked = achieve.hidden == true;
		maxScoreStepper.value = achieve.maxScore == null ? 0 : achieve.maxScore;
		decimalsStepper.value = achieve.maxDecimals == null ? 0 : achieve.maxDecimals;

		setStatus('Editing "' + achieve.save + '"', FlxColor.WHITE);
		updatePreview();
	}

	function newForm()
	{
		curSelected = -1;
		listScroll = 0;
		updateListVisuals();

		saveInput.text = '';
		nameInput.text = '';
		descInput.text = '';
		imageInput.text = '';
		hiddenCheck.checked = false;
		maxScoreStepper.value = 0;
		decimalsStepper.value = 0;

		setStatus('Creating a new achievement', FlxColor.WHITE);
		updatePreview();
	}

	function updatePreview()
	{
		if(iconPreview == null) return;

		var path:String = Achievements.normalizeImagePath(imageInput.text);
		if(path == null)
		{
			var key:String = saveInput.text != null ? saveInput.text.trim() : '';
			path = 'achievements/' + (key.length > 0 ? key : 'unknown');
		}

		var graphic:Dynamic = null;
		var hasAntialias:Bool = ClientPrefs.data.antialiasing;
		if(Paths.fileExists('images/$path-pixel.png', IMAGE))
		{
			graphic = Paths.image('$path-pixel');
			hasAntialias = false;
		}
		else if(Paths.fileExists('images/$path.png', IMAGE))
			graphic = Paths.image(path);

		if(graphic == null)
		{
			iconPreview.visible = false;
			previewText.text = 'Image not found:\nimages/' + path + '.png';
			previewText.color = FlxColor.RED;
		}
		else
		{
			iconPreview.visible = true;
			iconPreview.loadGraphic(graphic);
			iconPreview.setGraphicSize(128, 128);
			iconPreview.updateHitbox();
			iconPreview.antialiasing = hasAntialias;
			previewText.text = 'images/' + path + '.png';
			previewText.color = FlxColor.WHITE;
		}
	}

	function saveForm()
	{
		var key:String = saveInput.text != null ? saveInput.text.trim() : '';
		var displayName:String = nameInput.text != null ? nameInput.text.trim() : '';
		if(displayName.length < 1) displayName = key;

		var data:Achievement = {
			name: displayName,
			description: descInput.text != null ? descInput.text.trim() : '',
			hidden: hiddenCheck.checked,
			maxScore: maxScoreStepper.value,
			maxDecimals: Std.int(decimalsStepper.value),
			image: imageInput.text != null ? imageInput.text.trim() : null
		};

		if(curSelected >= 0 && curSelected < customList.length)
		{
			var oldKey:String = customList[curSelected].save;
			if(key != oldKey)
			{
				if(Achievements.exists(key))
				{
					setStatus('The save key "$key" is already in use', FlxColor.RED);
					return;
				}

				var wasUnlocked:Bool = Achievements.isUnlocked(oldKey);
				var score:Float = Achievements.variables.exists(oldKey) ? Achievements.variables.get(oldKey) : 0;
				Achievements.removeCustom(oldKey);
				var error:String = Achievements.createCustom(key, data);
				if(error != null)
				{
					setStatus(error, FlxColor.RED);
					refreshList();
					return;
				}

				Achievements.variables.set(key, score);
				if(wasUnlocked && !Achievements.isUnlocked(key)) Achievements.achievementsUnlocked.push(key);
				Achievements.save();
				FlxG.save.flush();
			}
			else
			{
				var error:String = Achievements.createCustom(oldKey, data);
				if(error != null)
				{
					setStatus(error, FlxColor.RED);
					return;
				}
			}
		}
		else
		{
			var error:String = Achievements.createCustom(key, data);
			if(error != null)
			{
				setStatus(error, FlxColor.RED);
				return;
			}
		}

		refreshList();
		for (i in 0...customList.length)
		{
			if(customList[i].save == key)
			{
				curSelected = i;
				break;
			}
		}
		applySelection();
		setStatus('Saved "$key"', 0xFF4CAF50);
	}

	function deleteSelected()
	{
		if(curSelected < 0 || curSelected >= customList.length) return;

		var key:String = customList[curSelected].save;
		openSubState(new Prompt('Delete the custom achievement\n"' + key + '"?', function()
		{
			Achievements.removeCustom(key);
			refreshList();
			newForm();
			setStatus('Deleted "' + key + '"', FlxColor.ORANGE);
		}, function()
		{
			setStatus('Edition of "' + key + '" cancelled', FlxColor.WHITE);
		}, 'Delete'));
	}

	function setStatus(text:String, color:FlxColor)
	{
		statusText.text = text;
		statusText.color = color;
	}
}
