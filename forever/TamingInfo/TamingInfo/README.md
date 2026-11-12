# Taming Info (WoW: Forever)

A "Taming Info" button that's always on screen. Click it for everything about the beast
you're targeting. Works on every class, so you can scout pets on any character.

## The button
- The dot shows your target's status: green = tameable, orange = too high level,
  red = not tameable, grey = no target.
- Hover for a quick summary. Drag to move it. `/taming button` hides it.

## The skills box (under the button)
When you target a tameable beast, a small box lists the skills **this beast** knows, each marked:
- **NEW** (green): you can't teach this skill yet. Tame it to learn it.
- **rank up** (yellow): you know the skill, but this beast has a higher rank.
- **known** (grey): you already have it.

The game doesn't directly tell addons what a wild beast knows, so the addon builds a
**beast journal** as you play:
- **Beast Lore** (hunters, level 24+): cast it on a beast and its abilities are read from the tooltip.
- **Taming**: your new pet's spellbook is saved under the wild beast's name.
- **Watching it fight**: when a beast uses Bite, Sonic Blast and so on, the ability and rank are recorded
  (when the game doesn't hide it).

What you already know is picked up from "You have learned a new spell/ability" messages and
by **opening Beast Training once**. You can also set it by hand: `/taming know Bite 3`.

The journal is account-wide, so Beast Lore results from your hunter also show on your other
characters. Until a beast is recorded, the box shows what it *could* know for its family and level.

## The panel
**Current target**
- Name, level, elite/rare, creature type, pet family
- Whether it can be tamed, and why not (not a beast, already a pet, too high level, dead...).
  Non-hunters see "tameable by a level X hunter" as a test mode.
- **Attack speed**: shows whether this beast has Faster or Slower Attack, which the pet keeps after taming
- Notable-beast note if it's a known rare (The Rake, Broken Tooth, Humar...)
- Its family's **unique ability** with every rank, and the highest rank a beast of this level could teach
- Shared abilities (Bite/Claw/Dash/Dive/Cower) and the best rank this beast could teach
- Diet, pet type (Offensive / Balanced / Defensive), stacking notes, and other notable beasts of the family

**Browse**: every family in Forever (including the new Fox), plus "How taming works"
(rules, attack speed, learning skills, happiness & loyalty), "Notable beasts" and the
**Beast journal** (your teachable skills plus every recorded beast).

**Tooltip hint**: mousing over a tameable beast adds a line with family, type, notable,
and fast/slow speed. Toggle it with `/taming tooltip`.

## Commands
`/taming` (or `/tame`) opens the panel, `/taming wolf` opens a family,
`/taming button`, `/taming skills` (toggle the skills box), `/taming tooltip`,
`/taming know <ability> <rank>`, `/taming forget <ability>`, `/taming reset`.

## Notes
- Data comes from WoW: Forever beta-era guides (1.60.x). Guides disagree on a few diets.
  Everything is in Data.lua, so it's easy to correct.
- Not every beast in a family knows its family ability. Rank info is the best it *could* teach.
- Target details are hidden in combat (game restriction) and refresh when combat ends.
