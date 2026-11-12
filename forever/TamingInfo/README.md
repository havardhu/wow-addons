# Taming Info

Everything about the beast you're targeting. Works on every class, so you can scout pets on any character.

- An on-screen button whose dot shows whether your target can be tamed. Hover for a summary, click for the full panel.
- The panel shows the pet family, why it can or can't be tamed, attack speed, diet, pet type, family abilities with ranks, and known rares.
- A skills box marks each skill the beast knows as **NEW**, **rank up** or **known** for you.
- An account-wide beast journal built from Beast Lore, taming, and watching beasts fight.
- Browse every Forever pet family, including the new Fox, plus taming guides.

## Folder layout
- `src/`: the addon itself (`.toc`, Lua and XML files), plus a detailed in-game guide in `src/README.md`.

## Install
Copy `src` into your WoW: Forever `Interface\AddOns\` folder and rename it to `TamingInfo`.
WoW only loads an addon when its folder name matches the `.toc` file (`TamingInfo.toc`).
If it shows as "out of date", run `/dump select(4, GetBuildInfo())` in game and put that
number on the `## Interface:` line of `TamingInfo.toc`.
