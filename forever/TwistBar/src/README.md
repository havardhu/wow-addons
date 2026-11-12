# Twist Bar (WoW: Forever)

Seal, Echo, swing timer and Judgement on one line for Retribution paladins.

    [Seal] [Echo] [====== swing timer ======] [Judgement] [Holy Strike]
                    twisted 14/16 swings (88%)

## What you see
- **Seal**: your active seal, coloured border, with its remaining duration as a swipe.
  Red border + "no seal" when you have none.
  The number in the bottom-right corner is the seal's stack count (Echo stacks), when it has any. The swing bar takes your seal's colour.
- **Echo** (only if you have Twist of Light): lights up green with the replaced seal's icon
  while an Echo is waiting for your next melee attack. Grey = nothing pending.
- **Swing bar**: driven by Forever's own swing event. Weapon speed on the left, time left
  on the right. "out of range" appears when your target is outside melee range.
- **White line on the bar**: where your global cooldown ends. If it's left of the spark's
  destination, a reseal fits before the next swing.
- **Judgement / Holy Strike**: cooldown swipes (falls back to Crusader Strike or Hammer of
  the Righteous if that's what you have).
- **twisted X/Y swings**: how many of this fight's swings carried an Echo. Resets each pull.

It doesn't tell you when to press anything. You read it and make the call.

## Commands
- `/twist` or `/twist unlock`: drag to move, then `/twist lock`
- `/twist scale 1.2`
- `/twist show smart|always|combat`: smart = in combat or with an attackable target
- `/twist strike`: toggle the strike cooldown icon
- `/twist gcd`: toggle the GCD marker
- `/twist echo on|off|auto`: force Echo tracking if auto-detect of Twist of Light misses
- `/twist reset`: move it back to the default position

## Tips
- You can turn off Forever's own swing timer (Options > Advanced Options > Swing Timer)
  so you don't see two.
- Swap seals once out of combat after installing. That teaches the addon the Echo buffs,
  so it can read them directly during fights instead of predicting them.
- Seal and Echo names are matched in English ("Seal of ...", "Echo of ...").
