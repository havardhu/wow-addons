# Forsaken Light

An Undead-paladin skin for the unit frames and minimap header.

- Grave-green and bone frame art on the player, target, focus, pet, target-of-target, focus-target and totem frames.
- Recoloured health and mana bars with a thin holy-gold trim.
- Names in Morpheus lettering, with a slow golden pulse around your frame in combat.
- `/forsaken on|off`, with toggles for each part.
- Purely cosmetic: it never moves, hides or replaces Blizzard frames.

## Folder layout
- `src/`: the addon itself (`.toc`, Lua and XML files), plus a detailed in-game guide in `src/README.md`.

## Install
Copy `src` into your WoW: Forever `Interface\AddOns\` folder and rename it to `ForsakenLight`.
WoW only loads an addon when its folder name matches the `.toc` file (`ForsakenLight.toc`).
If it shows as "out of date", run `/dump select(4, GetBuildInfo())` in game and put that
number on the `## Interface:` line of `ForsakenLight.toc`.
