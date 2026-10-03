# ste100

A plugin for Claude Code and Codex that makes replies follow ASD-STE100 Simplified Technical English. A slider sets how strict it is, from 10% to 100%.

## Install

### Claude Code

```
/plugin marketplace add toonooby/ste100-plugin
/plugin install ste100@ste100-marketplace
```

Then start a new session.

### Codex

```bash
codex plugin marketplace add toonooby/ste100-plugin
codex plugin add ste100@ste100-marketplace
```

Then start a new session and **run `/hooks` to trust the ste100 hook.** Codex skips plugin hooks until you trust them, and the hook is what applies the rules. Until you do, `ste 70` goes to the model as a normal message and replies do not change.

## Use

The plugin does nothing until you set a level. Send one of these as a message, with or without a leading slash (`ste 70` or `/ste 70`). The hook handles it and replies with a one-line confirmation; the message does not go to the model.

| Message | Effect |
|---------|--------|
| `ste 70` | Set the level to 70% (10-100, rounded to the nearest 10) |
| `ste 40 --project` | Override the level for this project only |
| `ste off` | Turn STE off |
| `ste` | Show the active level and where it comes from |
| `ste clear --project` | Remove the project override |

If the model answers `ste 70` instead of a confirmation, the hook did not run. In Codex, run `/hooks` and trust it. In Claude Code, check that the plugin is enabled and start a new session.

To rewrite existing text, ask for it ("rewrite this in STE at 90%") or use the `ste-rewrite` skill.

The level is stored in `~/.config/ste100/level` (or `$XDG_CONFIG_HOME/ste100/level`), so Claude Code and Codex share it. Precedence: the `STE100_LEVEL` environment variable, then `<project>/.ste100-level`, then the global file.

## How it works

A `UserPromptSubmit` hook (`scripts/ste-inject.sh`) adds the rules for the active level to every turn. The rules stack up: each tier adds rules to the ones below it (see `skills/ste100/SKILL.md`).

**Accuracy beats compliance.** At every level, the model must keep caveats, uncertainty, edge cases, and odd behavior, even when that breaks a rule. At 70% and above, each rule it breaks is marked with ‡ and explained in a `STE deviations:` line, so the strict levels cannot quietly flatten the facts.

Code, commands, paths, identifiers, error messages, quotes, and file contents are not changed.

## Notes

The percentage sets how many STE rules the model follows. It is not a measured compliance score. The rules here paraphrase the main ASD-STE100 writing rules; the plugin does not include the official STE dictionary. The specification is free from [ASD](https://www.asd-ste100.org). This project is not affiliated with ASD.

Upgrading from 0.1.x: the level used to live in `~/.claude/ste100/level`. That file is still read, and it moves to the new location the next time you set a level.
