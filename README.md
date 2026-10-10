# Text Reload Command

Reload every text file of the game and of all enabled extensions while the game runs, by typing `/reloadtext` or `/rtx` in the chat window. Made for modders: edit a `t/0001-l044.xml`, reload, and see the new text without restarting the game or loading a save.

## Features

- **`/reloadtext`** and the short form **`/rtx`** in the chat window - re-read the text files (`t/0001*.xml`) of the game and of every enabled extension, in the current game language.
- A changed text shows its new value, a newly added text id becomes available at once.
- A text that refers to another one with `{page,id}` follows the change of the referred text at once.
- The result is written to the game log and, unless switched off, printed into the chat window. A failure is always printed.
- The settings can be changed right from the chat: `/rtx none|debug|trace` sets the debug level, `/rtx reply on|off` switches the chat reply after a reload.

## Requirements

- `X4: Foundations` 8.00 or newer.
- `Print Extension List`, to record the game version and the enabled extensions in the log. Version `1.00` and upper is required.
  - It is available via Steam - [Print Extension List](https://steamcommunity.com/sharedfiles/filedetails/?id=3770927339)
  - Or via the Nexus Mods - [Print Extension List](https://www.nexusmods.com/x4foundations/mods/2191)
- Optional: `Options Helper` with the `Mod Support APIs` by [SirNukes](https://next.nexusmods.com/profile/sirnukes?gameId=2659), for the in-game options page. Versions `1.10` and `1.95` and upper. Without them the settings are changed through the chat commands.
  - Available via Steam - [Options Helper](https://steamcommunity.com/sharedfiles/filedetails/?id=3715253556) and [SirNukes Mod Support APIs](https://steamcommunity.com/sharedfiles/filedetails/?id=2042901274)
  - Or via the Nexus Mods - [Options Helper](https://www.nexusmods.com/x4foundations/mods/2089) and [Mod Support APIs](https://www.nexusmods.com/x4foundations/mods/503)

## Limitations

- This mod requires a `Protected UI Mode` in the Extensions settings to be disabled.
- Windows game only: the native Linux build is not supported, the reload command answers with a message and does nothing. The Windows game running on Linux through Proton or Wine should work.
- A reload only adds and updates texts, it never removes them: a text id or a whole page removed from a file, or a page whose id was changed, stays in the game with its last text until the next start.
- Mission Director scripts that write a text as `{page,id}` keep the old text until `/refreshmd`. Scripts that use `readtext` get the new one at once.
- Most of the UI shows the new text the next time a menu is drawn, but a UI extension that copied its texts when it was loaded keeps the old ones. For the best result run `/reloadui` after the reload, the same way `/refreshmd` is recommended for texts used in Mission Director scripts.
- Only the text files already known to the game are re-read: a text file added to an extension while the game runs may not be found.

## Installation

You can download the latest version via Steam client - [Text Reload Command](https://steamcommunity.com/sharedfiles/filedetails/?id=)
Or you can do it via the Nexus Mods - [Text Reload Command](https://www.nexusmods.com/x4foundations/mods/2449)

## Save state

**No** (removing the extension does not break saves).

## Usage

1. Edit the text file of your extension in the game's `extensions` folder.
2. Open the chat window and type `/reloadtext` or `/rtx`.
3. The chat window answers `Texts reloaded.`, or the reason when the reload failed.
4. `/rtx reply off` stops the success line in the chat, `/rtx reply on` brings it back.
5. `/rtx none`, `/rtx debug` or `/rtx trace` sets the debug level. Any other parameter prints a short usage line.

## Extension Options

With `Options Helper` installed, the mod adds a `Text Reload Command` page to `Settings` - `Extensions Options`:

- **Reply in chat after a reload** - print `Texts reloaded.` in the chat window after a successful reload. On by default; a failure is printed anyway.
- **Debug Level** - how much the mod writes to the game log. `None` is the default and keeps the log clean, `Debug` records one line per action taken, and `Trace` adds the detail. Use `Debug` or `Trace` when preparing a bug report, then set it back to `None`.

## Credits

- **Author**: Chem O`Dun, on [Nexus Mods](https://next.nexusmods.com/profile/ChemODun/mods?gameId=2659) and [Steam Workshop](https://steamcommunity.com/id/chemodun/myworkshopfiles/?appid=392160)
- *"X4: Foundations"* is a trademark of [Egosoft](https://www.egosoft.com).

## Acknowledgements

- [EGOSOFT](https://www.egosoft.com) - for the X series.

## Changelog

### [1.00] - 2026-10-??

- **Added**
  - Initial release.
