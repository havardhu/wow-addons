# Twist Bar

Seal, Echo, swing timer and Judgement on one line for Retribution paladins.

    [Seal] [Echo] [====== swing timer ======] [Judgement] [Holy Strike]

- Shows your active seal and its duration, and lights up when an Echo (Twist of Light) is waiting for your next swing.
- A swing timer driven by Forever's swing event, with a GCD marker that shows whether a reseal fits before the next swing.
- Cooldowns for Judgement and Holy Strike (or Crusader Strike / Hammer of the Righteous).
- Counts how many swings in the fight were twisted.
- `/twist` to unlock, move and scale it. It shows information only and never tells you what to press.

## Folder layout
- `src/`: the addon itself (`.toc`, Lua and XML files), plus a detailed in-game guide in `src/README.md`.

## Install
Copy `src` into your WoW: Forever `Interface\AddOns\` folder and rename it to `TwistBar`.
WoW only loads an addon when its folder name matches the `.toc` file (`TwistBar.toc`).
If it shows as "out of date", run `/dump select(4, GetBuildInfo())` in game and put that
number on the `## Interface:` line of `TwistBar.toc`.
