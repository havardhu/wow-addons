# Green Hills Pages

Tracks the Green Hills of Stranglethorn pages for a bank alt in WoW: Forever.

- Lists the 15 pages the quest needs, by chapter, with how many you hold in bags and bank.
- A checkbox per page to mark it as sent to your main (account-wide).
- Lists spare pages the quest doesn't use, so you can sell them.
- Tooltips on page items say whether you still need that page.
- Doesn't use the quest log, so it works on a character that never takes the quest.
- `/ghs` opens it.

## Folder layout
- `src/`: the addon itself (`.toc` and Lua file), plus a detailed guide in `src/README.md`.

## Install
Run `publish forever GreenHills` from the repo root, or copy `src` into your WoW: Forever
`Interface\AddOns\` folder and rename it to `GreenHills`.
WoW only loads an addon when its folder name matches the `.toc` file (`GreenHills.toc`).
