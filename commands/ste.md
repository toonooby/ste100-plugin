---
description: Set the STE100 compliance level (10-100, off, status, clear) for Claude's replies
argument-hint: "[10-100 | off | status | clear] [--project]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ste-level.sh:*)
disable-model-invocation: true
---

!`"${CLAUDE_PLUGIN_ROOT}/scripts/ste-level.sh" $ARGUMENTS`

Report the result above to the user in one line. Do not add other text.
