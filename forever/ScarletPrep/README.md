# Scarlet Prep

A Horde checklist for Scarlet Monastery in WoW: Forever.

- Lists the quests to pick up before you go: Into The Scarlet Monastery, Hearts of Zeal, Test of Lore, Compendium of the Fallen, Vorrel's Revenge, plus the Mage and Rogue class quests.
- Shows the full chain behind each one, including prerequisites like Going, Going, Guano! and the ten-step Test of Lore.
- Reads your quest log to show where you are: done, in progress, ready to turn in, or what to pick up next.
- An overview groups your next stops by place and lists what to do inside each wing.
- `/smprep` or the button on the quest log.

## Folder layout
- `src/`: the addon itself (`.toc` and Lua files), plus a detailed in-game guide in `src/README.md`.

## Install
Run `publish forever ScarletPrep` from the repo root, or copy `src` into your WoW: Forever
`Interface\AddOns\` folder and rename it to `ScarletPrep`.
WoW only loads an addon when its folder name matches the `.toc` file (`ScarletPrep.toc`).
