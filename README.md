# wow-addons

Addons grouped by game edition: `<edition>/<Addon>/src` holds the addon files.

## Publish locally
1. Copy `.env.example` to `.env` and set the game folder for each edition in `WOW_EDITIONS`.
2. From the repo root:

```
publish forever AskAI            # one addon
publish forever AskAI TwistBar   # several
publish forever all              # every addon in the edition
publish -List                    # editions and addons
```

`publish` (or `.\publish.ps1` in PowerShell) copies `<edition>/<Addon>/src` to
`<game folder>\Interface\AddOns\<Addon>`, deleting that folder first if it exists.
Addon names are case-insensitive. The target folder is named after the `.toc` file.
