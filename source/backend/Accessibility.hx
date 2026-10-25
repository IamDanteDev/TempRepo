package backend;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import objects.Alphabet;
import objects.Note;

/**
 * Central place for the accessibility preferences.
 *
 * Everything that can be made less hostile goes through here so a mod cannot
 * bypass the user's settings by calling the low level Flixel API directly.
 */
class Accessibility
{
	public static inline var COLORBLIND_OFF:String = 'Off';
	public static inline var COLORBLIND_DEUTERANOPIA:String = 'Deuteranopia';
	public static inline var COLORBLIND_PROTANOPIA:String = 'Protanopia';
	public static inline var COLORBLIND_TRITANOPIA:String = 'Tritanopia';

	public static var colorblindModes:Array<String> = [
		COLORBLIND_OFF,
		COLORBLIND_DEUTERANOPIA,
		COLORBLIND_PROTANOPIA,
		COLORBLIND_TRITANOPIA
	];

	/**
	 * Palette format matches `ClientPrefs.arrowRGB`: one row per lane, each row
	 * is `[main, highlight, shadow]` fed to the note RGB shader.
	 *
	 * Red/green deficiencies collapse the red-green axis, so the deuteranopia and
	 * protanopia sets stay on the blue-yellow axis and separate lanes by
	 * luminance instead. Tritanopia loses the blue-yellow axis, so that set stays
	 * on red-green with the same luminance ladder.
	 */
	private static var PALETTES:Map<String, Array<Array<FlxColor>>> = [
		COLORBLIND_DEUTERANOPIA => [
			[0xFF2979FF, 0xFFFFFFFF, 0xFF0D47A1],
			[0xFFFFE082, 0xFFFFFFFF, 0xFF8F7A1E],
			[0xFF82B1FF, 0xFFFFFFFF, 0xFF3D6BB3],
			[0xFFC77800, 0xFFFFFFFF, 0xFF6D4C00]],
		COLORBLIND_PROTANOPIA => [
			[0xFF2979FF, 0xFFFFFFFF, 0xFF0D47A1],
			[0xFFFFE082, 0xFFFFFFFF, 0xFF8F7A1E],
			[0xFF82B1FF, 0xFFFFFFFF, 0xFF3D6BB3],
			[0xFFC77800, 0xFFFFFFFF, 0xFF6D4C00]],
		COLORBLIND_TRITANOPIA => [
			[0xFFD32F2F, 0xFFFFFFFF, 0xFF7A0010],
			[0xFFFFCDD2, 0xFFFFFFFF, 0xFF8F3F39],
			[0xFF1B5E20, 0xFFFFFFFF, 0xFF0B2E0F],
			[0xFF66BB6A, 0xFFFFFFFF, 0xFF2E8F5A]]
	];

	/** Current palette, or the user's own colors when colorblind mode is off. */
	public static function getNotePalette(pixelStage:Bool):Array<Array<FlxColor>>
	{
		var palette:Array<Array<FlxColor>> = PALETTES.get(ClientPrefs.data.colorblindMode);
		if (palette != null) return palette;
		return pixelStage ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB;
	}

	/** `[main, highlight, shadow]` for one lane, or null when the lane is unknown. */
	public static function getNoteColor(lane:Int, pixelStage:Bool):Array<FlxColor>
	{
		var palette:Array<Array<FlxColor>> = getNotePalette(pixelStage);
		if (palette == null || lane < 0 || lane >= palette.length) return null;
		return palette[lane];
	}

	public static inline function isColorblindModeActive():Bool
	{
		return ClientPrefs.data.colorblindMode != COLORBLIND_OFF && PALETTES.exists(ClientPrefs.data.colorblindMode);
	}

	/**
	 * Damped camera shake. Reduce motion keeps a hint of feedback instead of
	 * removing it, so hits still read without the screen jumping.
	 */
	public static function shake(camera:FlxCamera, intensity:Float, duration:Float):Void
	{
		if (camera == null) return;

		if (ClientPrefs.data.reduceMotion)
		{
			intensity *= 0.2;
			if (duration > 0.15) duration = 0.15;
		}

		if (intensity <= 0 || duration <= 0) return;
		camera.shake(intensity, duration);
	}

	/**
	 * Recolors everything the lane palettes already own, so a colorblind change is
	 * visible in the current song instead of the next one.
	 */
	public static function applyColorblindMode():Void
	{
		Note.refreshGlobalRGBShaders();
	}

	/**
	 * Rescales the `Alphabet` text already on screen, so the Text Size option
	 * previews immediately instead of on the next menu.
	 *
	 * Only text currently sitting at `fromScale` is touched: widgets the game
	 * deliberately scaled (title screens, small labels) keep their own size.
	 */
	public static function applyTextScale(fromScale:Float, toScale:Float):Void
	{
		if (toScale <= 0 || fromScale <= 0) return;

		var state:FlxState = FlxG.state;
		if (state == null) return;

		scaleAlphabetIn(state, fromScale, toScale);

		var sub:FlxState = state.subState;
		while (sub != null)
		{
			scaleAlphabetIn(sub, fromScale, toScale);
			sub = sub.subState;
		}
	}

	static function scaleAlphabetIn(container:FlxBasic, fromScale:Float, toScale:Float):Void
	{
		if (container == null) return;

		if (Std.isOfType(container, Alphabet))
		{
			var text:Alphabet = cast container;
			if (Math.abs(text.scale.x - fromScale) < 0.001)
				text.setScale(toScale);
			return;
		}

		if (Std.isOfType(container, FlxTypedGroup))
		{
			for (member in (cast container:FlxTypedGroup<FlxBasic>).members)
				scaleAlphabetIn(member, fromScale, toScale);
		}
	}
}
