# Forsaken Light (WoW: Forever)

An Undead-paladin skin: grave-green and bone frame art, pale holy-gold trim,
Morpheus lettering, and a slow golden pulse around your own frame in combat.

## What it changes
- **Frame art** on Player, Target, Focus, Pet, Target-of-Target, Focus-target and Totem
  frames is desaturated and tinted grave-green/bone.
- **Health bars**: grave-green for you and your pet. Targets are blood red (hostile),
  amber (neutral), green (friendly) or grey (tapped).
- **Mana bars**: spectral teal. Rage/energy keep Blizzard's colours.
- A thin **holy-gold trim** around each health + power block, with a faint light line
  along the top of the bars.
- **Names** in Morpheus (bone white), **level** in pale gold.
- **Combat glow**: a slow golden pulse around your player frame while in combat.
- **Minimap header**: tinted border, Morpheus zone text (PvP colours kept).

## Commands
- `/forsaken off` restores everything; `/forsaken on` re-applies.
- `/forsaken art | bars | fonts | glow | portraits | minimap` toggles each part.
- `/forsaken scan` lists what was found on each frame. If something isn't skinned,
  send that output.

## Safety
It never moves, hides or replaces Blizzard frames, and never reads health or mana values.
Bar colours are textures laid over the bar's fill, so they follow it on their own.
