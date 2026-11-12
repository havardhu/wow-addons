-- Taming Info - data for WoW: Forever hunter pets (collected from beta-era guides, 1.60.x).
-- Values may change with patches; edit freely.

local ADDON, ns = ...
local D = {}
ns.D = D

D.TYPES = {
    Offensive = { color = "ff6060", desc = "High damage, low tanking." },
    Balanced  = { color = "ffd100", desc = "Medium damage, medium tanking." },
    Defensive = { color = "60a0ff", desc = "Low damage, high tanking." },
}

-- Shared abilities. ranks = { {petLevel, value}, ... }
D.SHARED = {
    Bite  = { short = "Damage attack.", desc = "Bite the target for %s damage.", ranks = {
        { 1, 8 }, { 8, 17 }, { 16, 26 }, { 24, 34 }, { 32, 44 }, { 40, 54 }, { 48, 73 }, { 56, 90 } } },
    Claw  = { short = "Damage attack.", desc = "Claw the target for %s damage.", ranks = {
        { 1, 5 }, { 8, 10 }, { 16, 14 }, { 24, 19 }, { 32, 25 }, { 40, 31 }, { 48, 42 }, { 56, 51 } } },
    Dash  = { short = "Sprint: +40/60/80% movement speed for 15 sec.", desc = "Movement speed +%s for 15 sec.", ranks = { { 30, "40%" }, { 40, "60%" }, { 50, "80%" } } },
    Dive  = { short = "Flyer sprint: +40/60/80% movement speed for 15 sec.", desc = "Movement speed +%s for 15 sec (flyers).", ranks = { { 30, "40%" }, { 40, "60%" }, { 50, "80%" } } },
    Cower = { desc = "Reduces threat. Learned from wild beasts like other skills." },
}

-- type, diet (from one guide), special ability with rank table, secondary abilities.
-- A `*` note means guides report the ability may not autocast.
D.FAMILIES = {
    Bat = { type = "Offensive", diet = { "Fruit", "Fungus" },
        special = { name = "Sonic Blast", new = true,
            desc = "%s Nature damage and +30% cast time on the enemy for 20 sec.",
            ranks = { { 12, 16 }, { 24, 36 }, { 36, 48 }, { 48, 68 }, { 60, 84 } },
            note = "Doesn't stack with Curse of Tongues or Mind-numbing Poison." },
        secondary = { "Bite", "Dive", "Cower" },
        notes = { "Guides list Dive for bats from level 40." } },
    Bear = { type = "Defensive", diet = { "Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat" },
        special = { name = "Swipe", new = true,
            desc = "Hits up to 3 nearby enemies for %s damage.",
            ranks = { { 12, 4 }, { 24, 9 }, { 36, 12 }, { 48, 17 }, { 60, 21 } },
            note = "Autocasts only when there are multiple targets." },
        secondary = { "Bite", "Claw", "Dash", "Cower" } },
    ["Bird of Prey"] = { type = "Offensive", diet = { "Fish", "Meat" },
        special = { name = "Mine!", new = true,
            desc = "%s damage and disarms the target for 3 sec.",
            ranks = { { 10, 11 }, { 20, 15 }, { 30, 22 }, { 40, 35 }, { 50, 44 } } },
        secondary = { "Claw", "Dive", "Cower" } },
    Boar = { type = "Defensive", diet = { "Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat" },
        special = { name = "Charge",
            desc = "+%s melee attack power on the next attack and immobilizes the target for 1 sec.",
            ranks = { { 1, 44 }, { 12, 106 }, { 24, 168 }, { 36, 246 }, { 48, 370 }, { 60, 490 } },
            note = "Autocasts only if the pet is on Assist and you attack first." },
        secondary = { "Bite", "Dash", "Cower" } },
    ["Carrion Bird"] = { type = "Balanced", diet = { "Fish", "Meat" },
        special = { name = "Demoralizing Screech", updated = true,
            desc = "%s to enemies in melee range for 30 sec.",
            ranks = { { 8, "8 dmg, -41 AP" }, { 24, "11 dmg, -77 AP" }, { 48, "24 dmg, -153 AP" }, { 56, "33 dmg, -198 AP" } },
            note = "Doesn't stack with Demoralizing Roar." },
        secondary = { "Bite", "Claw", "Dive", "Cower" } },
    Cat = { type = "Offensive", diet = { "Fish", "Meat" },
        special = { name = "Prowl",
            desc = "Stealth: %s.",
            ranks = { { 30, "-50% speed, +20% first hit" }, { 40, "-45% speed, +35% first hit" }, { 50, "-40% speed, +50% first hit" } } },
        secondary = { "Bite", "Claw", "Dash", "Cower" } },
    ["Core Hound"] = { type = "Offensive", diet = { "Meat" },
        special = { name = "Lava Breath",
            desc = "%s Fire damage to 2 nearby enemies, -25% cast speed for 10 sec.",
            ranks = { { 48, 84 }, { 48, 106 } } },
        secondary = { "Bite", "Cower" },
        notes = { "No Dash or Dive." } },
    Crab = { type = "Defensive", diet = { "Bread", "Fish", "Fruit", "Fungus" },
        special = { name = "Pinch", new = true, autocast = true,
            desc = "%s damage and -50% movement speed for 9 sec.",
            ranks = { { 12, 20 }, { 24, 34 }, { 36, 44 }, { 48, 73 }, { 60, 95 } } },
        secondary = { "Claw", "Dash", "Cower" } },
    Crocolisk = { type = "Defensive", diet = { "Fish", "Meat" },
        special = { name = "Dismember", new = true, autocast = true,
            desc = "%s damage and -25% healing received for 6 sec.",
            ranks = { { 12, 12 }, { 24, 19 }, { 36, 28 }, { 48, 42 }, { 60, 54 } },
            note = "Doesn't stack with Mortal Strike." },
        secondary = { "Bite", "Dash", "Cower" } },
    Fox = { type = "Offensive", diet = { "Fruit", "Meat" }, newFamily = true,
        special = { name = "Trickster's Dance", new = true, autocast = true,
            desc = "+50% dodge and 30% faster attacks for 12 sec.",
            ranks = { { 20, "" } } },
        secondary = { "Bite", "Dash", "Cower" },
        notes = { "New pet family in Forever." } },
    Gorilla = { type = "Defensive", diet = { "Bread", "Fruit", "Fungus" },
        special = { name = "Thunderstomp",
            desc = "%s Nature damage to all enemies within 8 yards.",
            ranks = { { 30, 57 }, { 40, 74 }, { 50, 99 }, { 60, 132 } } },
        secondary = { "Bite", "Dash", "Cower" } },
    Hyena = { type = "Balanced", diet = { "Meat", "Fruit" },
        special = { name = "Tendon Rip", new = true, autocast = true,
            desc = "%s damage over 9 sec and -50% movement speed.",
            ranks = { { 12, 12 }, { 24, 21 }, { 36, 27 }, { 48, 45 }, { 60, 60 } } },
        secondary = { "Bite", "Dash", "Cower" } },
    Raptor = { type = "Offensive", diet = { "Meat" },
        special = { name = "Savage Rend", new = true, autocast = true,
            desc = "Bleed for %s damage over 18 sec.",
            ranks = { { 12, 30 }, { 24, 54 }, { 36, 72 }, { 48, 120 }, { 60, 156 } } },
        secondary = { "Bite", "Claw", "Dash", "Cower" } },
    Scorpid = { type = "Defensive", diet = { "Meat" },
        special = { name = "Scorpid Poison", new = true,
            desc = "%s Nature damage over 10 sec, stacks up to 5 times.",
            ranks = { { 8, 5 }, { 24, 10 }, { 40, 20 }, { 56, 25 } } },
        secondary = { "Claw", "Dash", "Cower" } },
    Spider = { type = "Offensive", diet = { "Meat" },
        special = { name = "Web", new = true, autocast = true,
            desc = "Immobilizes and deals %s Nature damage over 4 sec.",
            ranks = { { 12, 12 }, { 24, 20 }, { 36, 28 }, { 48, 40 }, { 60, 52 } } },
        secondary = { "Bite", "Dash", "Cower" } },
    Tallstrider = { type = "Defensive", diet = { "Bread", "Cheese", "Fruit", "Fungus" },
        special = { name = "Dust Cloud", new = true, autocast = true,
            desc = "Reduces the target's armor by %s for 30 sec.",
            ranks = { { 12, 65 }, { 24, 175 }, { 36, 285 }, { 48, 395 }, { 60, 505 } },
            note = "Doesn't stack with Faerie Fire." },
        secondary = { "Bite", "Dash", "Cower" } },
    Turtle = { type = "Defensive", diet = { "Bread", "Fish", "Fruit", "Fungus" },
        special = { name = "Shell Shield", autocast = true,
            desc = "-50% damage taken, 60% slower but harder attacks, for 12 sec.",
            ranks = { { 20, "" } } },
        secondary = { "Bite", "Dash", "Cower" } },
    ["Wind Serpent"] = { type = "Offensive", diet = { "Bread", "Cheese", "Fish" },
        special = { name = "Lightning Breath",
            desc = "%s Nature damage to one target.",
            ranks = { { 1, 9 }, { 12, 21 }, { 24, 34 }, { 36, 50 }, { 48, 76 }, { 60, 92 } } },
        secondary = { "Bite", "Dive", "Cower" } },
    Wolf = { type = "Balanced", diet = { "Meat" },
        special = { name = "Furious Howl", updated = true,
            desc = "+%s melee attack power to party/raid within 15 yards for 1 min.",
            ranks = { { 10, 5 }, { 24, 34 }, { 40, 60 }, { 56, 82 } },
            note = "Doesn't stack with Battle Shout." },
        secondary = { "Bite", "Dash", "Cower" } },
}

D.ORDER = {}
for name in pairs(D.FAMILIES) do D.ORDER[#D.ORDER + 1] = name end
table.sort(D.ORDER)

-- Notable beasts. Keyed by NPC name.
D.RARES = {
    ["The Rake"]                  = { family = "Cat", level = "10", zone = "Mulgore", why = "1.2 attack speed: the best early damage pet." },
    ["Shal'ma"]                   = { family = "Cat", level = "9", zone = "Durotar (Echo Isles)", why = "New Horde-side rare cat." },
    ["Ghostfang"]                 = { family = "Cat", level = "10", zone = "Dun Morogh", why = "White and purple cat skin." },
    ["Humar the Pridelord"]       = { family = "Cat", level = "23", zone = "The Barrens", why = "Black lion skin. Heavily camped." },
    ["Broken Tooth"]              = { family = "Cat", level = "37", zone = "Badlands", why = "1.0 attack speed: the fastest cat." },
    ["Matriarch Bristlefur"]      = { family = "Bear", level = "10", zone = "Elwynn Forest", why = "Early bear for Human hunters." },
    ["Elmpaw"]                    = { family = "Bear", level = "12", zone = "Elwynn Forest (Stone Cairn Lake)", why = "New bear skin." },
    ["Mystmane"]                  = { family = "Bear", level = "13", zone = "Zephras Isle", why = "Already knows Swipe." },
    ["Coldrasp"]                  = { family = "Wolf", level = "12", zone = "Tirisfal Glades", why = "Blue spirit wolf skin." },
    ["Vulgara the Insatiable"]    = { family = "Wolf", level = "8", zone = "Zephras Isle", why = "Counts as a wolf and can learn Furious Howl." },
    ["Slavering Worg"]            = { family = "Wolf", level = "18-25", zone = "Shadowfang Keep", why = "1.2 attack speed: the best wolf for melee groups." },
    ["Mist Howler"]               = { family = "Wolf", level = "22", zone = "Ashenvale", why = "Fast wolf that knows Furious Howl." },
    ["Nightscreech"]              = { family = "Bird of Prey", level = "10", zone = "Teldrassil", why = "White bird of prey skin." },
    ["Fernfeather"]               = { family = "Tallstrider", level = "10", zone = "Zephras Isle", why = "Crane-like skin." },
    ["Death Flayer"]              = { family = "Scorpid", level = "11", zone = "Durotar", why = "Faster attack than most scorpids." },
    ["Carnage"]                   = { family = "Raptor", level = "30", zone = "Wetlands", why = "New raptor skin." },
}

D.RULES = {
    "You can only tame beasts at or below your own level.",
    "You can't tame with a pet out, even a dismissed one. Stable or release it first. The stable holds 2 pets plus your active one.",
    "Tame Beast is a 20 sec channel that costs 60% of base mana and removes 100% of your armor while channeling.",
    "The tame fails if the beast stops targeting you (someone else hits it, it gets distracted...).",
    "New pets start unhappy and disloyal: feed them right away.",
}

D.SPEED = {
    "Every pet has a base attack speed of 2.0 sec.",
    "Wild beasts can carry Faster Attack (1.7 down to 1.0 sec) or Slower Attack (2.5 / 2.7 sec). The pet keeps it after taming.",
    "No trainer sells these. Resetting a pet's training removes them.",
    "A faster pet does noticeably more damage: in one beta test, a 1.3 cat did about 50% more DPS than a 2.0 bird (not confirmed by Blizzard).",
}

D.LEARNING = {
    "1. Stable or release your pet so the slot is empty.",
    "2. Tame a beast that knows the ability and rank you want.",
    "3. Fight with it until chat says you learned the ability (can take a couple of minutes). Click utility skills manually: they may not autocast.",
    "4. Release or stable the teacher, call your pet, and teach it via Beast Training.",
    "Learned skills stay in Beast Training for every future pet that can use them. Each rank needs its own teacher, and your pet must meet the rank's level.",
    "Not every beast in a family knows its family ability, and Beast Lore doesn't always show it.",
}

D.HAPPY = {
    "Happy pets deal 125% damage, content 100%, unhappy 75%.",
    "Happiness drops when the pet dies or is dismissed (Dismiss Pet alone costs 50). Feed Pet raises it, but only with food from its diet and never in combat.",
    "Loyalty levels: Rebellious, Unruly, Submissive, Dependable, Faithful, Best Friend. It rises while the pet fights happy (XP-giving kills only).",
    "Training points come from loyalty: a level 60 Best Friend pet has 300. Up to 4 active abilities on the pet bar.",
}
