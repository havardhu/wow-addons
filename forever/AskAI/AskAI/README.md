# Ask AI (WoW: Forever)

Addons can't reach the internet, so Ask AI does the next best thing: it builds a complete,
ready-to-paste prompt about the quest you're looking at. You paste it into ChatGPT, Claude
or any other assistant.

## Use
- Click **Ask AI** in the quest log, or in the quest-giver window to ask before accepting.
  You can also type `/askai`, or bind a key under Key Bindings > AddOns.
- Pick a prompt on the left. The text is already selected, so press **Ctrl+C** and paste.
- Type an extra question in the box and press Enter to add it to the prompt.
- The Wowhead link for the quest is at the bottom.

## Built-in prompts
- **How do I do this?** Where to go and what to do for this quest.
- **Quest chain**: the chain this quest belongs to, all steps, where the next one starts,
  and the final reward.
- **Where to go / what to do**: a step-by-step route from where you're standing, with
  objective order, dangers for your level, and nearby quests to combine.

## Your own prompts
Right-click the Ask AI button, click **Edit prompts**, or type `/askai edit`.
- **New**, **Duplicate**, **Up/Down**, **Delete**. Everything saves as you type.
- Click a placeholder to insert it. Placeholders are filled in from the game when the prompt is built:
  `{context}` (full quest + character block), `{quest}`, `{questID}`, `{questLevel}`,
  `{questZone}`, `{status}`, `{objectives}`, `{description}`, `{class}`, `{race}`,
  `{faction}`, `{playerLevel}`, `{zone}`, `{position}`, `{wowhead}`, `{question}`, `{game}`.
- **Preview** shows the prompt filled in for your selected quest.
- Built-in prompts can be edited too. **Reset** restores one, `/askai restore` restores all.

## Commands
`/askai` (or `/ai`), `/askai <prompt name>`, `/askai edit`, `/askai restore`, `/askai resetbuttons`

If an Ask AI button sits in an awkward spot, shift-drag it. Its position is saved.
