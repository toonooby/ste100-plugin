# ste100

A Claude Code plugin that makes Claude write its replies in ASD-STE100 Simplified Technical English. A slider sets the compliance level from 10% to 100%.

## Install

In Claude Code:

```
/plugin marketplace add toonooby/ste100-plugin
/plugin install ste100@ste100-marketplace
```

Or from a terminal:

```bash
claude plugin marketplace add toonooby/ste100-plugin
claude plugin install ste100@ste100-marketplace
```

Then start a new session and run `/ste 70`. The plugin does nothing until you set a level.

To try it without installing, clone this repo and run `claude --plugin-dir ./ste100-plugin`.

## Use

| Command | Effect |
|---------|--------|
| `/ste 70` | Set the global level to 70% (rounded to the nearest 10) |
| `/ste 40 --project` | Override the level for this project only |
| `/ste off` | Turn STE off |
| `/ste` | Show the active level and its source |
| `/ste clear --project` | Remove the project override |
| `/ste-rewrite 90 <text>` | Rewrite some text (or the last reply) at a level |

Precedence: `STE100_LEVEL` env var > `<project>/.claude/ste100-level` > `~/.claude/ste100/level`. The default is off.

## How it works

A `UserPromptSubmit` hook (`scripts/ste-inject.sh`) adds the rules for the active level to every turn. The rules stack up: each tier adds rules to the ones below it (see `skills/ste100/SKILL.md`).

**Accuracy beats compliance.** At every level, Claude must keep caveats, uncertainty, edge cases, and odd behavior, even when that breaks a rule. At 70% and above, each rule it breaks is marked with ‡ and explained in a `STE deviations:` line, so the strict levels cannot quietly flatten the facts.

Code, commands, paths, identifiers, error messages, quotes, and file contents are not changed.

## Notes

The percentage sets how many STE rules Claude follows. It is not a measured compliance score. The rules here paraphrase the main ASD-STE100 writing rules; the plugin does not include the official STE dictionary. The specification is free from [ASD](https://www.asd-ste100.org). This project is not affiliated with ASD.
