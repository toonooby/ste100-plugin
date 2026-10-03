---
description: Rewrite a text (or your last reply) in STE100 at a given compliance level
argument-hint: "<10-100> [text to rewrite]"
---

Rewrite text in ASD-STE100 Simplified Technical English.

Arguments: $ARGUMENTS

1. The first argument is the compliance level (10-100). If it is missing, use the active level from the ste100 context in this turn, or 70 if there is none.
2. The rest of the arguments is the text to rewrite. If there is no text, rewrite your previous reply.
3. Use the `ste100` skill for the rules of each level.
4. Keep every fact, caveat, uncertainty, and edge case. Accuracy has priority over compliance. Mark each rule you break with ‡ and explain it in a "STE deviations:" list at the end.
5. After the rewrite, give a short table: rule broken in the original, count, and an example fix.
