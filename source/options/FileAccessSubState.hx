package options;

import backend.FileAccess;

/**
 * Options for the script file access sandbox.
 *
 * Safe Mode is the switch that matters: with it on, scripts may only write and
 * delete inside the mods folder, and may read the game folder as well. The per
 * type switches below only take effect when Safe Mode is off, which is stated in
 * their descriptions instead of hiding them, so the menu never lies about what
 * is currently enforced.
 */
class FileAccessSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('file_access_menu', 'File Access');
		rpcTitle = 'File Access Settings';

		var option:Option = new Option('Safe Mode',
			'Checked: scripts can only write and delete inside the mods folder.\nThey can also read the game folder, but nothing else.\nUncheck it to let the file type switches below decide,\nwhich restores the old unrestricted behavior.',
			'safeMode',
			BOOL);
		addOption(option);

		var option:Option = new Option('Data Files',
			'Text, JSON, XML, CSV and shader files.\nOnly used when Safe Mode is off.',
			'fileAccessData',
			BOOL);
		addOption(option);

		var option:Option = new Option('Script Files',
			'Lua and HScript files.\nOnly used when Safe Mode is off.',
			'fileAccessScripts',
			BOOL);
		addOption(option);

		var option:Option = new Option('Image Files',
			'PNG, JPG, WEBP and GIF files.\nOnly used when Safe Mode is off.',
			'fileAccessImages',
			BOOL);
		addOption(option);

		var option:Option = new Option('Audio Files',
			'OGG, MP3, WAV and FLAC files.\nOnly used when Safe Mode is off.',
			'fileAccessAudio',
			BOOL);
		addOption(option);

		var option:Option = new Option('Other Files',
			'Anything without a known extension.\nOnly used when Safe Mode is off.',
			'fileAccessOther',
			BOOL);
		addOption(option);

		super();
	}
}
