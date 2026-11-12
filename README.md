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

## Workflow
`main` is protected: nothing is pushed to it directly. Every change goes through a feature
branch and a squash-merged pull request, so `main` keeps one commit per change.

```
git switch main
git pull
git switch -c feature/my-change
# ...commit as often as you like...
git push -u origin feature/my-change
```

Open a pull request into `main` on GitHub and click **Squash and merge**. Then clean up:

```
git switch main
git pull
git branch -D feature/my-change
```

Use `-D`, not `-d`: after a squash merge git doesn't see the branch as merged.

Branch names: `feature/...` for new things, `fix/...` for bug fixes, `docs/...` for documentation.

### GitHub settings that enforce this
Ruleset on the default branch (`main`):
- Restrict deletions, Require linear history, Block force pushes.
- Require a pull request before merging, with 0 required approvals (you can't approve your
  own PR) and **Squash** as the only allowed merge method.
- Empty bypass list.

Settings > General > Pull Requests: only **Allow squash merging** enabled, and
**Automatically delete head branches** on.
