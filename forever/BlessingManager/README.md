# Blessing Manager

Plans, syncs and tracks paladin blessings for a group or raid.

- `/bm` opens a grid with one row per paladin and one column per class. Click a cell to pick the blessing.
- Role overrides let tanks, healers or DPS of a class get a different blessing.
- In a party, set a personal blessing for any member that overrides your class setting. Personal overrides only affect your own casting and are never shared.
- **Auto-assign**, **Sync** across the raid, and **Post** the plan to chat.
- Colour-coded cells show who is buffed, expiring or missing.
- A bindable cast button casts your next needed blessing on the right person.
- Stays within Forever's addon rules: it does its work out of combat and queues messages until combat ends.

## Folder layout
- `src/`: the addon itself (`.toc`, Lua and XML files), plus a detailed in-game guide in `src/README.md`.

## Install
Copy `src` into your WoW: Forever `Interface\AddOns\` folder and rename it to `BlessingManager`.
WoW only loads an addon when its folder name matches the `.toc` file (`BlessingManager.toc`).
If it shows as "out of date", run `/dump select(4, GetBuildInfo())` in game and put that
number on the `## Interface:` line of `BlessingManager.toc`.
