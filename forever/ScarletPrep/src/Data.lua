-- Scarlet Prep - Data
-- Horde quests for Scarlet Monastery in WoW: Forever, with their full chains.
--
-- Each goal is a chain of steps. A step is one quest. `ids` are the Classic quest IDs
-- (Forever reuses the Classic quest data); the title is a fallback when an ID doesn't match.
--   level   required level to pick up the step
--   who/hub where you pick it up         to/toHub  where you turn it in (default: who/hub)
--   doHub   where the objectives are     sm        objectives are inside Scarlet Monastery
--   wing    which SM wing(s)             text      what to do

local ADDON, ns = ...

local UC = "Undercity"
local SM = "Scarlet Monastery"

ns.WINGS = {
    { name = "Graveyard", levels = "28-38", note = "No key needed." },
    { name = "Library",   levels = "29-39", note = "No key needed. The Scarlet Key is at the end, near Arcanist Doan." },
    { name = "Armory",    levels = "32-42", note = "Needs the Scarlet Key (or Lockpicking)." },
    { name = "Cathedral", levels = "35-45", note = "Needs the Scarlet Key (or Lockpicking)." },
}

ns.GOALS = {
    {
        key = "itsm",
        name = "Into The Scarlet Monastery",
        summary = "Kill bosses in three wings for Varimathras. The best Horde quest reward in SM.",
        share = true,
        rewards = "Choice of Sword of Omen, Prophetic Cane or Dragon's Blood Necklace (Classic rewards; Forever may have updated them).",
        steps = {
            {
                ids = { 1048 }, title = "Into The Scarlet Monastery", level = 33,
                who = "Varimathras", hub = UC, where = "Royal Quarter (56.6, 92.6)",
                doHub = SM, sm = true, wing = "Library, Armory, Cathedral",
                text = "Kill Houndmaster Loksey (Library), Herod (Armory), and Scarlet Commander Mograine and High Inquisitor Whitemane (Cathedral). Mograine only counts after Whitemane raises him and both are dead. Armory and Cathedral need the Scarlet Key.",
            },
        },
    },
    {
        key = "zeal",
        name = "Hearts of Zeal",
        summary = "Collect 20 Hearts of Zeal from Scarlet mobs, in any wing or outside. Needs Going, Going, Guano! from Razorfen Kraul first.",
        share = false,
        rewards = "Experience and Undercity reputation.",
        steps = {
            {
                ids = { 1109 }, title = "Going, Going, Guano!", level = 30,
                who = "Master Apothecary Faranell", hub = UC, where = "The Apothecarium",
                doHub = "Razorfen Kraul",
                text = "Bring 1 Kraul Guano. It drops from the elite Kraul Bats in the caves on the far west side of Razorfen Kraul, about three quarters of the way through the dungeon.",
            },
            {
                ids = { 1113 }, title = "Hearts of Zeal", level = 30,
                who = "Master Apothecary Faranell", hub = UC, where = "The Apothecarium",
                doHub = SM, sm = true, wing = "Any wing (or outside)",
                text = "Collect 20 Hearts of Zeal from Scarlet Crusade mobs. They drop in every wing and outside the entrance. Not shareable.",
            },
        },
    },
    {
        key = "lore",
        name = "Test of Lore",
        summary = "A ten-step chain (Dorn's tests) that ends with a book from the Library. Long: start it early.",
        share = false,
        rewards = "Library step: experience and Undercity reputation. Final Passage: choice of Windstorm Hammer or Dancing Flame (Classic), plus reputation with all Horde cities.",
        steps = {
            {
                ids = { 1149 }, title = "Test of Faith", level = 26,
                who = "Dorn Plainstalker", hub = "Thousand Needles", where = "The Weathered Nook, a cave northeast of Freewind Post",
                text = "Talk to Dorn, then take the leap of faith: jump off the cliff next to him. You'll be caught.",
            },
            {
                ids = { 1150 }, title = "Test of Endurance", level = 26,
                who = "Dorn Plainstalker", hub = "Thousand Needles", where = "The Weathered Nook",
                doHub = "Thousand Needles",
                text = "Bring Grenka's Claw from Grenka Bloodscreech, a harpy in Thousand Needles.",
            },
            {
                ids = { 1151 }, title = "Test of Strength", level = 26,
                who = "Dorn Plainstalker", hub = "Thousand Needles", where = "The Weathered Nook",
                doHub = "Thousand Needles",
                text = "Bring the Fragments of Rok'Alim from Rok'Alim the Pounder, an elemental in Thousand Needles.",
            },
            {
                ids = { 1152, 1153 }, title = "Test of Lore", level = 26,
                who = "Dorn Plainstalker", hub = "Thousand Needles", where = "The Weathered Nook",
                to = "Braug Dimspirit", toHub = "Stonetalon Mountains",
                text = "Travel to Braug Dimspirit near the Talondeep Path entrance in Stonetalon Mountains.",
            },
            {
                ids = { 1154 }, title = "Test of Lore", level = 27,
                who = "Braug Dimspirit", hub = "Stonetalon Mountains", where = "Near the Talondeep Path entrance",
                doHub = "Ashenvale",
                text = "Get the book Legacy of the Aspects from the podium in the Dor'Danil Barrow Den in Ashenvale and bring it to Braug.",
            },
            {
                ids = { 6627 }, title = "Test of Lore", level = 27,
                who = "Braug Dimspirit", hub = "Stonetalon Mountains", where = "Near the Talondeep Path entrance",
                text = "Answer Braug's question. The answer is Neltharion. A wrong answer teleports you to The Barrens.",
            },
            {
                ids = { 1159 }, title = "Test of Lore", level = 26,
                who = "Braug Dimspirit", hub = "Stonetalon Mountains", where = "Near the Talondeep Path entrance",
                to = "Parqual Fintallas", toHub = UC,
                text = "Find Parqual Fintallas on the southern bridge in the Apothecarium, Undercity (57, 65).",
            },
            {
                ids = { 1160 }, title = "Test of Lore", level = 28,
                who = "Parqual Fintallas", hub = UC, where = "The Apothecarium (57, 65)",
                doHub = SM, sm = true, wing = "Library",
                text = "Find Beginnings of the Undead Threat in the Library: on a table in a small room off a red-carpeted hallway past the courtyard.",
            },
            {
                ids = { 6628 }, title = "Test of Lore", level = 28,
                who = "Parqual Fintallas", hub = UC, where = "The Apothecarium (57, 65)",
                text = "Answer Parqual's question. The answer is in the book you just brought him.",
            },
            {
                ids = { 1394 }, title = "Final Passage", level = 30,
                who = "Parqual Fintallas", hub = UC, where = "The Apothecarium (57, 65)",
                to = "Dorn Plainstalker", toHub = "Thousand Needles",
                text = "Return to Dorn Plainstalker in the Weathered Nook for the reward.",
            },
        },
    },
    {
        key = "comp",
        name = "Compendium of the Fallen",
        summary = "Grab a book from the Library for Sage Truthseeker. Orc, Troll and Tauren only.",
        share = true,
        notRace = { Scourge = true, Undead = true },
        notRaceText = "Not available to Undead.",
        rewards = "Choice of Vile Protector, Forcestone Buckler or Omega Orb (Vile Protector is buffed in Forever).",
        steps = {
            {
                ids = { 1049 }, title = "Compendium of the Fallen", level = 28,
                who = "Sage Truthseeker", hub = "Thunder Bluff",
                doHub = SM, sm = true, wing = "Library",
                text = "Take the Compendium of the Fallen from a bookshelf in the corner room between the last two hallways of the Library.",
            },
        },
    },
    {
        key = "vorrel",
        name = "Vorrel's Revenge",
        summary = "Starts inside the Graveyard wing, then sends you to Alterac Mountains and Tarren Mill.",
        share = true,
        rewards = "Experience and money.",
        steps = {
            {
                ids = { 1051 }, title = "Vorrel's Revenge", level = 25,
                who = "Vorrel Sengutz", hub = SM, where = "Graveyard wing, on the rack next to Interrogator Vishas",
                to = "Monika Sengutz", toHub = "Hillsbrad Foothills",
                doHub = "Alterac Mountains", startsInside = true, wing = "Graveyard",
                text = "Kill Interrogator Vishas, then talk to Vorrel to get the quest. Kill Nancy Vishas (level 33 elite) at the house on the Misty Shore in Alterac Mountains for Vorrel's Wedding Ring and bring it to Monika Sengutz in Tarren Mill. Grandpa Vishas (level 34 elite) stays inside the house.",
            },
        },
    },

    -- Class quests: only shown to that class.
    {
        key = "mage",
        name = "Rituals of Power (Mage)",
        class = "MAGE",
        summary = "Mage chain that ends with a wand. The book is in the Library.",
        share = false,
        rewards = "Choice of Icefury Wand, Nether Force Wand or Ragefire Wand.",
        steps = {
            {
                title = "Journey to the Marsh", level = 30,
                who = "Mage trainer", hub = "Any capital city",
                to = "Tabetha", toHub = "Dustwallow Marsh",
                text = "Speak with Tabetha at the Quagmire in Dustwallow Marsh.",
            },
            {
                title = "Get the Scoop", level = 30,
                who = "Tabetha", hub = "Dustwallow Marsh", where = "The Quagmire",
                to = "Magus Tirth", toHub = "Thousand Needles",
                text = "Find Magus Tirth at the Shimmering Flats. He wants a password: target the chicken \"Plucky\" Johnson nearby, type /beckon, and talk to him once he turns human.",
            },
            {
                title = "Rituals of Power", level = 30,
                who = "Magus Tirth", hub = "Thousand Needles", where = "The Shimmering Flats",
                to = "Tabetha", toHub = "Dustwallow Marsh",
                doHub = SM, sm = true, wing = "Library",
                text = "Get the book Rituals of Power from just inside the last stretch of hallway in the Library, near the Compendium of the Fallen. Bring it to Tabetha.",
            },
            {
                title = "Mage's Wand", level = 30,
                who = "Tabetha", hub = "Dustwallow Marsh", where = "The Quagmire",
                text = "Follow-up from Tabetha that gives you the wand.",
            },
        },
    },
    {
        key = "rogue",
        name = "The Eye of Bhossca (Rogue)",
        class = "ROGUE",
        summary = "Solo Rogue chain started by letters from \"C\". Sneak through the Graveyard and Library.",
        share = false,
        rewards = "Ruby-Adorned Blade (rare one-handed sword, made for Forever) and money.",
        steps = {
            {
                title = "The Horn of Xelthos", level = 20,
                who = "Dead drop (letter from \"C\")", hub = "Silverpine Forest", where = "Cabin near Pyrewood Village (47.1, 71.1)",
                doHub = "Shadowfang Keep",
                text = "A letter arrives in a capital city at level 20. Get the Horn of Xelthos from Shadowfang Keep, alone, and return it to the dead drop. The Eye quest reportedly doesn't appear without this.",
            },
            {
                title = "The Eye of Bhossca", level = 25,
                who = "Dead drop (letter \"Return Customer\")", hub = "Silverpine Forest", where = "Cabin near Pyrewood Village (47.1, 71.1)",
                doHub = SM, sm = true, wing = "Graveyard + Library (solo)",
                text = "The second letter arrives in a capital city, often at level 30. Take the Scarlet Initiate's Uniform from the Supply Locker in the Scarlet Monastery stables (81.1, 32.1; Pick Lock). Pickpocket the Scryer's Key from a Scarlet Scryer (Graveyard), open the Personal Letterbox near Arcanist Doan (Library), sit on the two right benches in the Graveyard, loot the Reliquary Key from the northern mausoleum, then open the Padlocked Reliquary in the Gallery of Treasures (Library). Put the Eye in the dead drop, collect the \"Payment\" letter in a city, and return to the dead drop for the reward.",
            },
        },
    },
}

-- Before-you-go checklist. `item` is checked automatically; the rest you tick yourself.
ns.CHECKS = {
    { key = "scarletkey", name = "The Scarlet Key", item = 7146,
      text = "Opens the Armory and Cathedral. Pick it up at the end of the Library, near Arcanist Doan." },
    { key = "hearth", name = "Hearthstone set to Brill or Undercity",
      text = "Brill and the Undercity are closest to the Monastery and the quest givers." },
    { key = "group", name = "Group of five",
      text = "Shareable quests (Into The Scarlet Monastery, Compendium, Vorrel's Revenge) can be shared with your group." },
    { key = "supplies", name = "Food, drink and repairs",
      text = "Several wings in a row is a long trip." },
}
