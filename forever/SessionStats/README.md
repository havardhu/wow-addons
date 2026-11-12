# Session Stats

Start a play session and see where your XP, gold and time went.

- `/ss` opens the window: start, pause and end sessions. Sessions survive logout and reload.
- Tracks XP and gold per hour (from kills and from quests), spending, kills, deaths, quests, loot by quality, reputation and profession skill-ups.
- Per-dungeon-run and per-zone breakdowns, plus a history of past sessions.
- A movable mini tracker shows time to level, XP/hr, kills, net gold and quests.
- Works around Forever's combat-log restriction by counting kills from XP messages.

## Folder layout
- `src/`: the addon itself (`.toc`, Lua and XML files), plus a detailed in-game guide in `src/README.md`.

## Install
Copy `src` into your WoW: Forever `Interface\AddOns\` folder and rename it to `SessionStats`.
WoW only loads an addon when its folder name matches the `.toc` file (`SessionStats.toc`).
If it shows as "out of date", run `/dump select(4, GetBuildInfo())` in game and put that
number on the `## Interface:` line of `SessionStats.toc`.
