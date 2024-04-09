# Aseprite Slice Editor Tool

![Screen Cap](screenCap.png)

This is a tool to facilitate editing [9-slices](https://en.wikipedia.org/wiki/9-slice_scaling) within the [Aseprite](https://www.aseprite.org/) pixel art editor.

**The Aseprite slice feature has been buggy for a long time. In general, I discourage using slices. However, some people rely on them. Test this script on a sample sprite first. Backup any complex projects before including slices and/or using this script.**

If you are creating a custom [theme](https://aseprite.org/docs/extensions/themes/), and work with the slices that link `theme.xml` and `sheet.png`, beware of using this script's features.

This script was created with Aseprite version 1.3.5 on Windows 10. In the screen shot above, the theme is default dark with 100% UI scaling and 200% screen scaling. Due to the size of the dialog, a theme with 100% scaling is recommended.

If you would like to report a problem with the script, please see this repo's Issues section. I make no assurances that I will be able to resolve any problems. If you would like more info on running Aseprite in debug mode, see the command line interface (CLI) [documentation](https://aseprite.org/docs/cli/#debug).

## Download

To download this script, click on the green Code button above, then select Download Zip. You can also click on the `editSlices.lua` file. Beware that some browsers will append a `.txt` file format extension to script files on download. Aseprite will not recognize the script until this is removed and the original `.lua` extension is used. There can also be issues with copying and pasting. Be sure to click on the Raw file button; do not copy the formatted code.

## Usage

To use this script, open Aseprite. In the menu bar, go to `File > Scripts > Open Scripts Folder`. Move the Lua script into the folder that opens. Return to Aseprite; go to `File > Scripts > Rescan Scripts Folder` (the default hotkey is `F5`). The script should now be listed under `File > Scripts`. Select `editSlices.lua` to launch the dialog.

If an error message in Aseprite's console appears, check if the script folder is on a file path that includes characters beyond [UTF-8](https://en.wikipedia.org/wiki/UTF-8), such as 'é' (e acute) or 'ö' (o umlaut).

A hot key can be assigned to the script by going to `Edit > Keyboard Shortcuts`. The search input box in the top left of the shortcuts dialog can be used to locate the script by its file name.

Once open, holding down the `Alt` or `Option` key and pressing the underlined letter on a button will activate that button via keypress. For example, `Alt+C` will cancel the dialog. See the screen capture above.

The features of this dialog, per each button, are:
- **All**: Selects all the sprite's slices.
- **Mask**: Gets the slices entirely contained by the selection mask.
- **None**: Deselects all the sprite's slices.
- **Copy**: Partially copies the selected slices, avoiding custom user data and properties. Inverts the slices' colors. Warns before execution.
- **Delete**: Deletes the selected slices. Warns before execution.
- **From**: Creates a slice from the bounds of a selection mask.
- **To**: Converts the selected slices to a selection mask.
- **W**: Nudges the selected slices up toward y = 0.
- **A**: Nudges the selected slices left toward x = 0.
- **S**: Nudges the selected slices down toward y = height - 1.
- **D**: Nudges the selected slices right toward x = width - 1.
- **Resize**: Sets slices' bounds to the given size, maintaining their pivots. Insets are scaled by ratio of new size to old.
- **Inset**: Sets slices' insets to a pixel increment from its bounds.
- **Pivot**: Sets slices' pivots according to 9 presets (top left, bottom right, center, etc.).
- **Rename**: Sets a slice's name to the provided string. If multiple slices are selected, appends a number after the string.
- **Color**: Recolors the selected slices per a mix between two given colors. Color mixing is done in HSL unless one of the colors is gray. When HSL is used, the hue is mixed counter clockwise.
- **Swap**: Swaps the origin and destination color.
- **Cancel**: Closes the dialog.

Both resize and nudge try to avoid creating a slice that is outside the sprite's bounds.

All nudge buttons try to match the slice's top-left corner to the slice grid when snap to grid is enabled.

Any order-sensitive functions, like rename and color mix, sort slices according to the y coordinate, followed by the x, followed by the slice name.

