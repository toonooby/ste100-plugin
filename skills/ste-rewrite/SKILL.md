---
name: ste-rewrite
description: Rewrite a text, or your previous reply, in ASD-STE100 Simplified Technical English at a given compliance level (10-100). Use when the user asks to rewrite, simplify, or convert text into STE or STE100.
argument-hint: "<10-100> [text to rewrite]"
---

Rewrite text in ASD-STE100 Simplified Technical English.

1. The level is the first number (10-100) the user gives. If there is none, use the active level from the ste100 context in this turn, or 70 if there is none.
2. The text to rewrite is the rest of the request. If there is no text, rewrite your previous reply.
3. Use the `ste100` skill for the rules of each level.
4. Keep every fact, caveat, uncertainty, and edge case. Accuracy has priority over compliance. Mark each rule you break with ‡ and explain it in a "STE deviations:" list at the end.
5. After the rewrite, give a short table: rule broken in the original, count, and an example fix.
