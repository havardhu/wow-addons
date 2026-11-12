# Blessing Manager (WoW: Forever)

Plan who blesses which class, sync it across the raid, and see who's missing a blessing.

## Install
Copy the `BlessingManager` folder into `World of Warcraft\_forever_\Interface\AddOns\`
(or whatever the Forever client folder is called). If the addon shows as "out of date",
run `/dump select(4, GetBuildInfo())` in game and put that number on the `## Interface:` line
of `BlessingManager.toc`.

## Use
- `/bm` opens the grid: one row per paladin in your group, one column per class.
- Click a cell to cycle the class's default blessing; Shift-click clears it.
- Right-click a cell for **role overrides**: pick a different blessing (or none) for that
  class's tanks, healers or DPS. Overrides beat the class default. Example: Shaman default
  Kings, Shaman Healer -> Wisdom. Cells with overrides show small T / H / D letters.
  Roles come from the party/raid role each player has set; players with no role get the default.
- **Personal overrides** (party only, when you're a paladin): under the grid, every party member
  is listed with the blessing you'll give them. Click to cycle, Shift-click to go back to the
  class setting, right-click to pick from a list. A personal override beats your class default
  and role overrides, but only for your own casting: it's never sent to the group, and the
  shared grid and **Post** still show the class plan. Gold background = personal override.
- **Auto-assign** fills every row you're allowed to edit, using the priority table at the top of `Core.lua`.
- **Sync** pushes your rows and asks everyone else for theirs. **Post** writes the plan to raid/party chat.
- Cell borders: green = everyone buffed, orange = expiring soon, red = someone missing (or two paladins on the same blessing), grey = nobody of that class here.
- The small pink button casts your next needed blessing on the right person. Bind it under
  Key Bindings > AddOns > "Cast next blessing". Right-drag to move it.

In a raid you can edit your own row; the leader and assists can edit every row. In a party, anyone can edit.

## Commands
`/bm auto | sync | clear | check | report | alerts | sound | button | debug | threshold <minutes>`

## How it stays within Forever's addon rules
All scanning and target picking happens out of combat. In combat the addon freezes and the cast
button keeps whatever target it had. Addon messages are queued during combat and sent afterwards.
