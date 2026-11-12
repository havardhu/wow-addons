# Session Stats (WoW: Forever)

Start a session, play, and see where your XP, gold and time went.

## Install
Copy the `SessionStats` folder into your Forever `Interface\AddOns\` folder. If it shows as
"out of date", run `/dump select(4, GetBuildInfo())` and put that number on the `## Interface:`
line of `SessionStats.toc`.

## Use
- `/ss` opens the window. **New session** starts tracking. **Pause** stops the clock and recording
  (e.g. while you AFK in town). **End** moves the session to History.
- Sessions survive logout/reload. Only logged-in, unpaused time counts.
- The mini tracker shows time to level, XP/hr, kills, net gold and quests. Drag it to move,
  double-click to open the window, right-click to pause/resume. `/ss mini` hides it.

## What it tracks
- **XP:** from kills, from quests and total (each with per-hour). Time, time to level,
  and roughly how many kills or quests until you level.
- **Gold:** from kills (looted coin), from quests and total earned (each with per-hour), plus vendor sales and net change. Spending on vendors,
  repairs, flights, training, mail and the AH. Gold/hr and vendor value of looted items.
- **Combat:** XP-giving kills, kills/hr, corpses looted, deaths.
- **Quests:** completed, accepted, per hour, average XP and gold per quest.
- **Loot:** items by quality, plus a list of notable (rare+) drops with zone.
- **Reputation gains and profession skill-ups.**
- **Dungeons:** each run, from zoning in to zoning out, with time, XP, gold, kills, deaths and loot.
  Zoning out and back within 15 minutes (corpse runs) continues the same run.
- **Zones:** time, XP/hr, kills, quests and gold for each zone.

## Commands
`/ss [show | new <name> | pause | resume | end | mini | report [party|raid|guild]]`

## Limits
Forever blocks the combat log for addons, so kills are counted from the "X dies, you gain N
experience" messages. Grey mobs and kills at max level don't give XP, so they aren't counted;
use "Corpses looted" for those.
