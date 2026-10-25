package states;

import backend.Mods;
import backend.ModBrowser;
import backend.ModBrowser.ModEntry;
import backend.ModBrowser.ModTask;

import backend.ui.PsychUIButton;
import sys.thread.Thread;

import flixel.util.FlxSpriteUtil;

class ModBrowserState extends MusicBeatState
{
	static inline var PER_PAGE:Int = 10;
	static inline var ROW_HEIGHT:Int = 48;

	static var warnedThisSession:Bool = false;

	var entries:Array<ModEntry> = [];
	var page:Int = 1;
	var total:Int = 0;
	var selected:Int = 0;

	var listTask:ModTask = null;
	var installTask:ModTask = null;
	var confirmingEntry:ModEntry = null;
	var warningGroup:FlxSpriteGroup;
	var lastInstalled:String = null;

	var rowNames:Array<FlxText> = [];
	var rowAuthors:Array<FlxText> = [];
	var rowStats:Array<FlxText> = [];

	var pageText:FlxText;
	var detailTitle:FlxText;
	var detailInfo:FlxText;
	var statusText:FlxText;
	var hintText:FlxText;

	var prevButton:PsychUIButton;
	var nextButton:PsychUIButton;
	var installButton:PsychUIButton;
	var backButton:PsychUIButton;

	var listX:Float = 40;
	var listY:Float = 90;
	var listWidth:Float = 760;
	var listHeight:Float = 520;
	var rowsY:Float = 100;

	override function create()
	{
		super.create();
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF2F6B4F;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		var title:FlxText = new FlxText(40, 20, 900, 'GAMEBANANA MOD BROWSER', 30);
		title.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		add(title);

		pageText = new FlxText(40, 56, 1200, 'Category: Psych Mod Folders', 16);
		pageText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pageText.borderSize = 1;
		add(pageText);

		var listBg:FlxSprite = FlxSpriteUtil.drawRoundRect(new FlxSprite(listX, listY).makeGraphic(Std.int(listWidth), Std.int(listHeight), FlxColor.TRANSPARENT), 0, 0,
			Std.int(listWidth), Std.int(listHeight), 15, 15, FlxColor.BLACK);
		listBg.alpha = 0.55;
		add(listBg);

		var detailX:Float = listX + listWidth + 20;
		var detailWidth:Int = Std.int(FlxG.width - detailX - 40);
		var detailBg:FlxSprite = FlxSpriteUtil.drawRoundRect(new FlxSprite(detailX, listY).makeGraphic(detailWidth, Std.int(listHeight), FlxColor.TRANSPARENT), 0, 0,
			detailWidth, Std.int(listHeight), 15, 15, FlxColor.BLACK);
		detailBg.alpha = 0.55;
		add(detailBg);

		for (i in 0...PER_PAGE)
		{
			var y:Float = rowsY + i * ROW_HEIGHT;

			var name:FlxText = new FlxText(listX + 15, y, 420, '', 18);
			name.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			name.borderSize = 1;
			add(name);
			rowNames.push(name);

			var author:FlxText = new FlxText(listX + 460, y, 190, '', 16);
			author.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
			add(author);
			rowAuthors.push(author);

			var stats:FlxText = new FlxText(listX + 660, y, 90, '', 16);
			stats.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, RIGHT);
			add(stats);
			rowStats.push(stats);
		}

		detailTitle = new FlxText(detailX + 15, listY + 12, FlxG.width - detailX - 70, '', 22);
		detailTitle.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailTitle.borderSize = 1;
		detailTitle.wordWrap = true;
		add(detailTitle);

		detailInfo = new FlxText(detailX + 15, listY + 110, FlxG.width - detailX - 70, '', 16);
		detailInfo.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
		detailInfo.wordWrap = true;
		add(detailInfo);

		var note:FlxText = new FlxText(detailX + 15, listY + 330, FlxG.width - detailX - 70,
			'Only .zip files can be installed.\nMods are third-party code: they can run\nLua/HScript and change the game.\nInstall only mods you trust.', 14);
		note.setFormat(Paths.font('vcr.ttf'), 14, 0xFFFFCC66, LEFT);
		note.wordWrap = true;
		add(note);

		statusText = new FlxText(detailX + 15, listY + 430, FlxG.width - detailX - 70, '', 16);
		statusText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
		statusText.wordWrap = true;
		add(statusText);

		prevButton = new PsychUIButton(listX, 640, 'PREV PAGE', prevPage, 150, 40);
		add(prevButton);
		styleButton(prevButton);

		nextButton = new PsychUIButton(listX + 165, 640, 'NEXT PAGE', nextPage, 150, 40);
		add(nextButton);
		styleButton(nextButton);

		installButton = new PsychUIButton(detailX, 640, 'DOWNLOAD & INSTALL', startInstall, 260, 40);
		installButton.normalStyle.bgColor = 0xFF4CAF50;
		installButton.normalStyle.textColor = FlxColor.WHITE;
		installButton.hoverStyle.bgColor = 0xFF66BB6A;
		add(installButton);
		styleButton(installButton);

		backButton = new PsychUIButton(FlxG.width - 185, 640, 'BACK', exit, 145, 40);
		add(backButton);
		styleButton(backButton);

		hintText = new FlxText(40, 690, 1200,
			'UP/DOWN select  ·  LEFT/RIGHT change page  ·  ACCEPT download & install  ·  BACK exit', 14);
		hintText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintText.borderSize = 1;
		add(hintText);

		// Session warning shown before the first install (S6)
		warningGroup = new FlxSpriteGroup();
		warningGroup.visible = false;
		var warningBg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		warningBg.alpha = 0.9;
		warningGroup.add(warningBg);

		var warningTitle:FlxText = new FlxText(0, 200, FlxG.width, 'SECURITY WARNING', 48);
		warningTitle.setFormat(Paths.font('vcr.ttf'), 48, 0xFFFF6666, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		warningTitle.borderSize = 3;
		warningGroup.add(warningTitle);

		var warningText:FlxText = new FlxText(0, 290, FlxG.width,
			'Mods are third-party code: they can run Lua/HScript\nand change the game in any way.\n\nOnly install mods you trust.', 24);
		warningText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
		warningText.alignment = CENTER;
		warningGroup.add(warningText);

		var warningHint:FlxText = new FlxText(0, 520, FlxG.width,
			'ACCEPT: install the selected mod\nBACK: cancel', 20);
		warningHint.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFF66, CENTER);
		warningHint.alignment = CENTER;
		warningGroup.add(warningHint);
		add(warningGroup);

		FlxG.mouse.visible = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Browsing Mods', null);
		#end

		loadPage(1);
	}

	// ------------------------------------------------------------------ network

	function loadPage(newPage:Int):Void
	{
		if(listTask != null || installTask != null || confirmingEntry != null) return;
		if(newPage < 1) newPage = 1;

		var task:ModTask = new ModTask();
		listTask = task;
		setStatus('Loading page ' + newPage + '...', FlxColor.WHITE);
		Thread.create(function() ModBrowser.fetchIndex(task, newPage, PER_PAGE));
	}

	function startInstall():Void
	{
		if(installTask != null || listTask != null || confirmingEntry != null || entries.length < 1) return;
		if(selected < 0 || selected >= entries.length) return;

		var entry:ModEntry = entries[selected];
		if(!warnedThisSession)
		{
			warnedThisSession = true;
			confirmingEntry = entry;
			warningGroup.visible = true;
			return;
		}
		doInstall(entry);
	}

	function doInstall(entry:ModEntry):Void
	{
		if(installTask != null) return;

		var task:ModTask = new ModTask();
		installTask = task;
		lastInstalled = null;
		setStatus('Preparing "' + entry.name + '"...', FlxColor.WHITE);
		Thread.create(function() ModBrowser.install(task, entry.id, entry.name));
	}

	// ------------------------------------------------------------------ update

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(listTask != null)
		{
			var snap = listTask.snapshot();
			if(!snap.done)
			{
				if(snap.stage != null && snap.stage.length > 0) setStatus(snap.stage, FlxColor.WHITE);
			}
			else
			{
				listTask = null;
				if(snap.error != null)
				{
					setStatus('Could not load the mod list:\n' + snap.error, FlxColor.RED);
				}
				else
				{
					entries = snap.entries != null ? snap.entries : [];
					total = snap.total;
					page = snap.page;
					selected = 0;
					refreshRows();
					refreshDetails();
					if(entries.length < 1) setStatus('No mods on this page.', FlxColor.RED);
					else setStatus('', FlxColor.WHITE);
				}
			}
		}

		if(installTask != null)
		{
			var snap = installTask.snapshot();
			if(!snap.done)
			{
				var text:String = snap.stage != null ? snap.stage : 'Installing...';
				if(snap.stage != null && snap.stage.startsWith('Extracting')) text = 'Extracting... ' + Math.round(snap.progress * 100) + '%';
				setStatus(text, FlxColor.WHITE);
			}
			else
			{
				installTask = null;
				if(snap.error != null)
				{
					setStatus('Install failed:\n' + snap.error, FlxColor.RED);
				}
				else
				{
					lastInstalled = snap.installedFolder;
					@:privateAccess Mods.updateModList();
					Mods.parseList();
					setStatus('Installed to mods/' + lastInstalled + '.\nRestart the game to load it.', 0xFF66FF66);
				}
				refreshButtons();
			}
		}

		var busy:Bool = installTask != null || listTask != null;
		if(busy) return;

		if(confirmingEntry != null)
		{
			if(controls.ACCEPT)
			{
				var entry:ModEntry = confirmingEntry;
				confirmingEntry = null;
				warningGroup.visible = false;
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
				doInstall(entry);
			}
			else if(controls.BACK)
			{
				confirmingEntry = null;
				warningGroup.visible = false;
				setStatus('Install cancelled.', FlxColor.WHITE);
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			}
			return;
		}

		if(controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			exit();
			return;
		}

		if(controls.ACCEPT)
		{
			startInstall();
			return;
		}

		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);
		if(controls.UI_LEFT_P) prevPage();
		if(controls.UI_RIGHT_P) nextPage();

		if(FlxG.mouse.wheel != 0) changeSelection(FlxG.mouse.wheel > 0 ? -1 : 1);

		if(FlxG.mouse.justPressed && FlxG.mouse.x >= listX && FlxG.mouse.x <= listX + listWidth
			&& FlxG.mouse.y >= rowsY && FlxG.mouse.y < rowsY + PER_PAGE * ROW_HEIGHT)
		{
			var index:Int = Std.int((FlxG.mouse.y - rowsY) / ROW_HEIGHT);
			if(index >= 0 && index < entries.length)
			{
				selected = index;
				refreshRows();
				refreshDetails();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
		}
	}

	// ------------------------------------------------------------------ ui

	function changeSelection(amount:Int):Void
	{
		if(entries.length < 1) return;
		var newSelected:Int = selected + amount;
		if(newSelected < 0) newSelected = 0;
		if(newSelected > entries.length - 1) newSelected = entries.length - 1;
		if(newSelected == selected) return;

		selected = newSelected;
		refreshRows();
		refreshDetails();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function prevPage():Void
	{
		if(page <= 1) return;
		loadPage(page - 1);
	}

	function nextPage():Void
	{
		if(page * PER_PAGE >= total) return;
		loadPage(page + 1);
	}

	function refreshRows():Void
	{
		for (i in 0...PER_PAGE)
		{
			var name:FlxText = rowNames[i];
			var author:FlxText = rowAuthors[i];
			var stats:FlxText = rowStats[i];

			if(i >= entries.length)
			{
				name.visible = author.visible = stats.visible = false;
				continue;
			}

			var entry:ModEntry = entries[i];
			var selectedNow:Bool = i == selected;
			name.visible = author.visible = stats.visible = true;
			name.text = (selectedNow ? '> ' : '  ') + entry.name;
			name.color = selectedNow ? 0xFFFFFF66 : FlxColor.WHITE;
			author.text = 'by ' + entry.author;
			author.color = selectedNow ? 0xFFFFFF66 : 0xFFBBBBBB;
			stats.text = 'V:' + entry.views;
			stats.color = selectedNow ? 0xFFFFFF66 : 0xFFBBBBBB;
		}

		var totalPages:Int = total > 0 ? Std.int(Math.ceil(total / PER_PAGE)) : 1;
		pageText.text = 'Category: Psych Mod Folders  ·  Page ' + page + '/' + totalPages + '  ·  ' + total + ' mods';
		refreshButtons();
	}

	function refreshDetails():Void
	{
		if(selected < 0 || selected >= entries.length)
		{
			detailTitle.text = '';
			detailInfo.text = '';
			return;
		}

		var entry:ModEntry = entries[selected];
		detailTitle.text = entry.name;
		detailInfo.text = 'Author: ' + entry.author
			+ (entry.category != null && entry.category.length > 0 ? '\nCategory: ' + entry.category : '')
			+ '\nViews: ' + entry.views
			+ '\nGameBanana ID: ' + entry.id;
	}

	function refreshButtons():Void
	{
		if(prevButton != null) prevButton.visible = page > 1;
		if(nextButton != null) nextButton.visible = page * PER_PAGE < total;
		if(installButton != null) installButton.visible = entries.length > 0;
	}

	function styleButton(btn:PsychUIButton, size:Int = 18):Void
	{
		btn.text.setFormat(Paths.font('vcr.ttf'), size, btn.text.color, CENTER);
		btn.text.y = btn.bg.y + btn.bg.height / 2 - btn.text.height / 2;
	}

	function setStatus(text:String, color:Int):Void
	{
		if(statusText == null) return;
		statusText.text = text;
		statusText.color = color;
	}

	function exit():Void
	{
		if(listTask != null || installTask != null || confirmingEntry != null) return;

		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxG.mouse.visible = false;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new ModsMenuState());
	}
}
