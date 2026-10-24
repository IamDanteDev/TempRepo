package options;

class CustomizationSubState extends BaseOptionsMenu
{
	public function new() {
        title = Language.getPhrase('gameplay_menu', 'Gameplay Settings');
        rpcTitle = 'Customization Menu'; //for Discord Rich Presence

        //I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
        var option:Option = new Option('Enable?', //Name
            'If checked, Your options in this menu will overwrite the Psych Engine UI', //Description
            'hudcustomization', //Save data variable name
            BOOL); //Variable type
        addOption(option);

        super();
}

}