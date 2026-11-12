# Ask AI

Builds a ready-to-paste AI prompt about the quest you're looking at. Addons can't reach the
internet, so Ask AI collects the quest, objectives, zone and character details into a prompt
you copy into ChatGPT, Claude or any other assistant.

- Open it from the **Ask AI** button in the quest log or quest-giver window, a key binding, or `/askai`.
- Built-in prompts: how to do the quest, the full quest chain, and a step-by-step route.
- Write your own prompts with placeholders such as `{quest}`, `{objectives}`, `{zone}` and `{class}`.
- Includes a Wowhead link for the quest.

## Folder layout
- `src/`: the addon itself (`.toc`, Lua and XML files), plus a detailed in-game guide in `src/README.md`.

## Install
Copy `src` into your WoW: Forever `Interface\AddOns\` folder and rename it to `AskAI`.
WoW only loads an addon when its folder name matches the `.toc` file (`AskAI.toc`).
If it shows as "out of date", run `/dump select(4, GetBuildInfo())` in game and put that
number on the `## Interface:` line of `AskAI.toc`.
