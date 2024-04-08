# Aseprite Slice Editor Tool

![Screen Cap](screenCap.png)

This is a tool to facilitate editing [9-slices](https://en.wikipedia.org/wiki/9-slice_scaling) within the [Aseprite](https://www.aseprite.org/) pixel art editor.

**The Aseprite slice feature has been buggy for a long time. In general, I discourage using slices; however, some people rely on them. Test this script on a sample sprite first. Backup any complex projects before including slices and/or using this script.**

This script was created with Aseprite version 1.3.5 on Windows 10. In the screen shot above, the theme is default dark with 100% UI scaling and 200% screen scaling. Due to the size of the dialog, a theme with 100% scaling is recommended.

If you would like to report a problem with the script, please see this repo's Issues section. I make no guarantees that I will be able to resolve any problems. If you would like more info on running Aseprite in debug mode, see the command line interface (CLI) [documentation](https://aseprite.org/docs/cli/#debug).

## Download

To download this script, click on the green Code button above, then select Download Zip. You can also click on the `editSlices.lua` file. Beware that some browsers will append a `.txt` file format extension to script files on download. Aseprite will not recognize the script until this is removed and the original `.lua` extension is used. There can also be issues with copying and pasting. Be sure to click on the Raw file button; do not copy the formatted code.

## Usage

To use this script, open Aseprite. In the menu bar, go to `File > Scripts > Open Scripts Folder`. Move the Lua script into the folder that opens. Return to Aseprite; go to `File > Scripts > Rescan Scripts Folder` (the default hotkey is `F5`). The script should now be listed under `File > Scripts`. Select `editSlices.lua` to launch the dialog.

If an error message in Aseprite's console appears, check if the script folder is on a file path that includes characters beyond [UTF-8](https://en.wikipedia.org/wiki/UTF-8), such as 'é' (e acute) or 'ö' (o umlaut).

A hot key can be assigned to the script by going to `Edit > Keyboard Shortcuts`. The search input box in the top left of the shortcuts dialog can be used to locate the script by its file name.

Once open, holding down the `Alt` or `Option` key and pressing the underlined letter on a button will activate that button via keypress. For example, `Alt+C` will cancel the dialog. See screen capture above.