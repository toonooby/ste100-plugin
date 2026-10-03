---
name: ste100
description: Reference for writing or checking text in ASD-STE100 Simplified Technical English at a 10-100% compliance level. Use when the user asks for STE, Simplified Technical English, STE100, simpler technical prose, or a compliance check or rewrite of documentation, procedures, or replies. Also use when the user sends a level message such as "ste 70" or "/ste 70": reaching you means the plugin's hook did not run.
---

# ASD-STE100 writing at graded compliance

ASD-STE100 is a controlled language for technical documentation. It limits vocabulary and grammar so that readers (including non-native English speakers) understand text quickly and with one meaning. The official specification and dictionary are free from ASD (https://www.asd-ste100.org). This skill paraphrases the main writing rules; it does not contain the dictionary.

## The slider

The plugin maps a level from 10% to 100% onto cumulative rule tiers. The user sets the level by sending `ste <level>` or `/ste <level>` as a message, and a hook adds the rules for that level to each turn.

### If a level message reaches you

The hook normally catches `ste 70`, `/ste off`, and similar messages before they reach the model. If one reaches you, the hook did not run, so no STE rules are being applied either. Do not set the level yourself; that would hide the problem.

- In Codex, the usual cause is that plugin hooks stay off until the user trusts them. Tell the user to run `/hooks`, trust the ste100 hook, and send the message again.
- In Claude Code, the usual cause is that the plugin is disabled or the session started before it was installed. Tell the user to check `/plugin` and start a new session.

| Level | Adds |
|-------|------|
| 10 | One idea per sentence; consistent terms; prefer active voice |
| 20 | Sentences of 30 words or fewer |
| 30 | Main point first; numbered lists for sequences |
| 40 | Imperative instructions; 20-word procedural / 25-word descriptive limits; no phrasal verbs |
| 50 | No idioms, metaphors, slang, or humor; keep articles and "that"; noun clusters of 3 words max; no -ing nouns/adjectives |
| 60 | Paragraphs of 6 sentences max, one topic each; passive only in descriptive text when the agent is unknown or unimportant |
| 70 | Only simple present, simple past, simple future, imperative, infinitive; no contractions; deviations must be marked with ‡ |
| 80 | Common concrete words, one meaning and one part of speech each; warnings before the step, starting with a command |
| 90 | One instruction per sentence unless actions are simultaneous; topic sentence first in descriptive paragraphs |
| 100 | Dictionary-approved words only, plus technical names and technical verbs of the field |

## The accuracy rule (overrides every tier)

STE can push a writer to smooth over complexity. That is a failure, not compliance.

- Keep every caveat, uncertainty, edge case, contradiction, and unusual behavior.
- If a rule forces a loss or change of meaning, break the rule.
- Say that strange results are strange. Do not normalize them.
- At 70% and above, mark each deviation with ‡ and list the reasons under "STE deviations:" at the end.

## Out of scope

Code, commands, paths, identifiers, error messages, quoted text, tool inputs, and file contents stay as they are unless the user asks otherwise.

## Rewrite examples

Original: "You'll want to go ahead and spin up the dev server before kicking off the tests, since they're hitting it."

- 40%: "Start the dev server before you run the tests. The tests send requests to it."
- 80%: "Start the development server. Then run the tests. The tests send requests to the server."

Original: "This mostly works, but weirdly the cache sometimes returns stale data after a deploy — we haven't pinned down why."

- 70% (correct): "The cache usually returns correct data. After a deployment, the cache sometimes returns old data. This is unusual. We do not know the cause."
- 70% (wrong — smooths over the problem): "The cache returns data after a deployment."
