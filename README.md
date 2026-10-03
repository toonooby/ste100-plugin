# ste100

A plugin for Claude Code and Codex that makes replies follow ASD-STE100 Simplified Technical English. A slider sets how strict it is, from 10% to 100%.

## Install

The hook requires **Bash 3.2 or later and [jq](https://jqlang.org/download/)**. Make sure `jq` is on the `PATH` used by Claude Code or Codex. The scripts run on macOS and Linux; native Windows is not verified.

### Claude Code

Send these two commands one at a time. If you paste both at once, Claude Code reads them as a single marketplace source and rejects it.

```
/plugin marketplace add toonooby/ste100-plugin
```

```
/plugin install ste100@ste100-marketplace
```

If Claude Code opens an "Add Marketplace" box instead, enter only `toonooby/ste100-plugin`.

Then start a new session.

### Codex

Run these two commands in a terminal, one at a time:

```bash
codex plugin marketplace add toonooby/ste100-plugin
```

```bash
codex plugin add ste100@ste100-marketplace
```

Then review and trust the ste100 hook:

- **Codex CLI:** start a new session and run `/hooks`.
- **Codex desktop app:** open the app's **Hooks settings**, then review and trust the ste100 hook there. `/hooks` is the CLI command.

Codex skips plugin hooks until you trust them, and the hook is what applies the rules. Start a new session after installation or an update. If an update asks you to review the hook again, trust its new definition.

## Use

Automatic STE styling starts when you set a level. Send one of these as a message, with or without a leading slash (`ste 70` or `/ste 70`). The hook handles it and displays a confirmation; the message does not go to the model.

| Message | Effect |
|---------|--------|
| `ste 70` | Set the level to 70% (10-100, rounded to the nearest 10) |
| `ste 40 --project` | Override the level for this project only |
| `ste off` | Turn STE off globally; project and environment overrides still take precedence |
| `ste off --project` | Turn STE off for this project |
| `ste` | Show the active level and where it comes from |
| `ste clear --project` | Remove the project override |

If the model answers `ste 70` instead of a confirmation, check that `jq` is available and the plugin is enabled. In Codex CLI, run `/hooks` and trust the hook; in the desktop app, use Hooks settings. In Claude Code, check `/plugin` and start a new session.

To rewrite existing text, ask for it ("rewrite this in STE at 90%") or use the `ste-rewrite` skill.

The level is stored in `~/.config/ste100/level` (or `$XDG_CONFIG_HOME/ste100/level`), so Claude Code and Codex share it. Precedence: the `STE100_LEVEL` environment variable, then `<project>/.ste100-level`, then the global file.

An invalid level turns automatic styling off and gives repair instructions for its source. Use `--project` to repair or clear a project override. To repair an environment override, change or unset `STE100_LEVEL` in the environment that starts the app or CLI, then start a new session.

## How it works

A `UserPromptSubmit` hook (`scripts/ste-inject.sh`) adds the current mode to every turn. Each message explicitly replaces earlier automatic STE instructions, so lowering the level or turning it off works within the same conversation. Turning automatic styling off still allows an explicit request to rewrite text in STE.

Within an active level, the rules stack up: each tier adds rules to the ones below it (see `skills/ste100/SKILL.md`).

**Accuracy beats compliance.** At every level, the model must keep caveats, uncertainty, edge cases, and odd behavior, even when that breaks a rule. At 70% and above, each rule it breaks is marked with ‡ and explained in a `STE deviations:` line, so the strict levels cannot quietly flatten the facts.

Code, commands, paths, identifiers, error messages, quotes, and file contents are not changed.

## Notes

The percentage sets how many STE rules the model follows. It is not a measured compliance score. The rules here paraphrase the main ASD-STE100 writing rules; the plugin does not include the official STE dictionary. The specification is free from [ASD](https://www.asd-ste100.org). This project is not affiliated with ASD.

Upgrading from 0.1.x: the level used to live in `~/.claude/ste100/level`. That file is still read, and it moves to the new location the next time you set a level.

## Checks

Run `python3 -m unittest discover -s tests -v` for the hook regression tests. Python 3 is needed only for these tests. The tests use temporary settings and leave your own STE level files unchanged.
