# Scarlet Prep (WoW: Forever)

A Horde checklist for Scarlet Monastery. It lists every quest worth having before you go,
the full chain behind each one, and where you stand in it, read live from your quest log.

## Use
- `/smprep` (or `/smp`, `/scarletprep`), or the **Scarlet Prep** button on the quest log.
- **Overview**: what to do inside the Monastery (with objective progress), your next stops
  grouped by place (Undercity, Thunder Bluff, Thousand Needles...), quests you're still too low
  for, and the level range of each wing.
- **Before you go**: the Scarlet Key (checked automatically) plus a few things to tick yourself.
- **One page per quest chain**: every step with who gives it, where to turn it in, which wing,
  what to do, and your objectives from the quest log.

## Quests
- **Into The Scarlet Monastery** (Varimathras, Undercity, level 33): Loksey, Herod, Mograine and Whitemane.
- **Hearts of Zeal** (Master Apothecary Faranell, Undercity, level 30), after **Going, Going, Guano!** in Razorfen Kraul.
- **Test of Lore**: the ten-step chain from Dorn Plainstalker (Thousand Needles) to Parqual Fintallas (Undercity) and back.
- **Compendium of the Fallen** (Sage Truthseeker, Thunder Bluff, level 28). Not for Undead.
- **Vorrel's Revenge**: starts inside the Graveyard wing.
- Class quests, shown only to that class: **Rituals of Power** (Mage) and **The Eye of Bhossca** (Rogue).

## How progress is tracked
- Quests in your log are matched by quest ID (the Classic IDs), with the quest title as a fallback.
- A step counts as done when the game reports it completed, when you turn it in while the addon is
  loaded, or when a later step of the same chain is done or in your log.
- Did something before installing the addon that it can't see? Open that chain and click
  **Mark step done**. **Undo my marks** (or `/smprep reset`) clears them.
- You get a chat message when a quest is ready to turn in or ready for the dungeon.

## Commands
`/smprep`, `/smprep report` (summary in chat), `/smprep reset`, `/smprep help`

## Notes
- Quest data comes from WoW: Forever guides and the Classic quest database. Forever changed some
  rewards, so reward lists are marked as Classic where unconfirmed. Everything is in `Data.lua`.
