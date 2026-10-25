package options;

import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;

class AccessibilitySubState extends BaseOptionsMenu
{
	/** Preview widgets shrink so a full lane (note + arrow + splash) fits above the option list. */
	static inline var PREVIEW_SCALE:Float = 0.6;
	static inline var PREVIEW_LANE_GAP:Float = 30;
	static inline var PREVIEW_NOTE_Y:Float = 88;
	static inline var PREVIEW_STRUM_Y:Float = 170;
	static inline var PREVIEW_HIDDEN_Y:Float = -200;

	var strums:FlxTypedGroup<StrumNote>;
	var fallingNotes:FlxTypedGroup<Note>;
	var splashes:FlxTypedGroup<NoteSplash>;

	var notesShown:Bool = false;
	/** Scale the currently displayed text was laid out with, before this option changed. */
	var lastTextScale:Float = 1;

	public function new()
	{
		title = Language.getPhrase('accessibility_menu', 'Accessibility');
		rpcTitle = 'Accessibility Settings';

		createPreview();

		var option:Option = new Option('Colorblind Mode:',
			'Replaces lane colors with a palette that stays readable\nif you have color vision deficiency.\nWhen enabled, it overrides the Note Colors menu.\nThe preview shows the note, arrow and splash of every lane.',
			'colorblindMode',
			STRING,
			Accessibility.colorblindModes);
		addOption(option);
		option.onChange = onChangeColorblindMode;

		var option:Option = new Option('Reduce Motion',
			"If checked, camera shake during gameplay is damped\ninstead of playing at full intensity.",
			'reduceMotion',
			BOOL);
		addOption(option);

		var option:Option = new Option('Text Size',
			'Scales menu text as you change it.\nText that is already on screen updates immediately.',
			'textScale',
			FLOAT);
		option.minValue = 0.8;
		option.maxValue = 1.3;
		option.changeValue = 0.05;
		option.scrollSpeed = 0.8;
		option.decimals = 2;
		option.displayFormat = '%vx';
		addOption(option);
		option.onChange = onChangeTextScale;

		lastTextScale = ClientPrefs.data.textScale;

		super();
		add(fallingNotes);
		add(strums);
		add(splashes);
	}

	/**
	 * Builds one preview lane per column: the note that would be falling, the arrow
	 * it lands on, and the splash it triggers. All three read their colors from the
	 * shared lane palettes, so they follow a colorblind change on their own.
	 */
	function createPreview():Void
	{
		strums = new FlxTypedGroup<StrumNote>();
		fallingNotes = new FlxTypedGroup<Note>();
		splashes = new FlxTypedGroup<NoteSplash>();

		var laneWidth:Float = Note.swagWidth * PREVIEW_SCALE;
		var lanes:Int = Note.colArray.length;
		var totalWidth:Float = laneWidth * lanes + PREVIEW_LANE_GAP * (lanes - 1);
		var startX:Float = (FlxG.width - totalWidth) / 2;

		for (i in 0...lanes)
		{
			var laneCenter:Float = startX + laneWidth / 2 + i * (laneWidth + PREVIEW_LANE_GAP);

			var strum:StrumNote = new StrumNote(laneCenter - laneWidth / 2, PREVIEW_HIDDEN_Y, i, 0);
			changeNoteSkin(strum);
			strum.scale.set(PREVIEW_SCALE);
			strums.add(strum);

			// A real Note shares the lane palette, so it recolors with the strum.
			var note:Note = new Note(0, i);
			note.reloadNote();
			note.scale.set(PREVIEW_SCALE);
			note.x = laneCenter;
			note.y = PREVIEW_HIDDEN_Y;
			fallingNotes.add(note);

			var splash:NoteSplash = new NoteSplash(0, 0);
			splash.scale.set(PREVIEW_SCALE);
			splash.spawnSplashNote(0, 0, i, null, false);
			splashes.add(splash);
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);

		// The preview is the reference for every row here, not only for the palette row,
		// so it stays on screen once the menu opens instead of sliding away on scroll.
		if (!notesShown)
		{
			notesShown = true;
			tweenPreview(true);
		}
	}

	function tweenPreview(show:Bool):Void
	{
		for (i in 0...strums.length)
		{
			var strum:StrumNote = strums.members[i];
			var note:Note = fallingNotes.members[i];

			FlxTween.cancelTweensOf(strum);
			FlxTween.cancelTweensOf(note);

			FlxTween.tween(strum, {y: show ? PREVIEW_STRUM_Y : PREVIEW_HIDDEN_Y}, 0.35, {ease: FlxEase.quadInOut});
			FlxTween.tween(note, {y: show ? PREVIEW_NOTE_Y : PREVIEW_HIDDEN_Y}, 0.35, {ease: FlxEase.quadInOut});
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateSplashPositions();
	}

	/** Splashes are centered on their arrow so the preview always reads as a hit. */
	function updateSplashPositions():Void
	{
		for (i in 0...splashes.length)
		{
			var splash:NoteSplash = splashes.members[i];
			var strum:StrumNote = strums.members[i];
			if (splash == null || strum == null) continue;

			var strumSize:Float = Note.swagWidth * strum.scale.x;
			var splashWidth:Float = splash.frameWidth * splash.scale.x;
			var splashHeight:Float = splash.frameHeight * splash.scale.y;

			splash.x = strum.x + (strumSize - splashWidth) / 2 + splash.offset.x;
			splash.y = strum.y + (strumSize - splashHeight) / 2 + splash.offset.y;
		}
	}

	function onChangeColorblindMode()
	{
		// Recolors the shared palettes in place, which covers strums and notes already alive.
		Accessibility.applyColorblindMode();

		// Splashes bake the palette into their own shader on spawn, so they are re-spawned.
		for (i in 0...splashes.length)
			splashes.members[i].spawnSplashNote(0, 0, i, null, false);
	}

	function onChangeTextScale()
	{
		var newScale:Float = ClientPrefs.data.textScale;
		Accessibility.applyTextScale(lastTextScale, newScale);
		lastTextScale = newScale;
	}

	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		note.texture = skin;
		note.reloadNote();
		note.playAnim('static');
	}

	override function destroy()
	{
		Note.clearGlobalRGBShaders();
		super.destroy();
	}
}
