#!/usr/bin/env bash
# UserPromptSubmit hook: adds the STE100 rules for the active level to the turn.
# Rules are cumulative: each level adds rules on top of the levels below it.
set -euo pipefail

cat >/dev/null # discard the hook's JSON input

read -r LEVEL _ <<<"$("$(dirname "$0")/ste-level.sh" --resolve)"
[[ "$LEVEL" == "0" ]] && exit 0

rule() { (( LEVEL >= $1 )) && echo "- $2"; return 0; }

cat <<EOF
<ste100 level="${LEVEL}">
Write your prose reply to the user in ASD-STE100 Simplified Technical English at ${LEVEL}% compliance. Apply every rule listed below; rules for higher levels are deliberately left out.

Rules:
EOF

rule 10  "Put one idea in each sentence when you can."
rule 10  "Use the same word for the same thing every time. Do not change words for variety."
rule 10  "Prefer the active voice."
rule 20  "Keep sentences to 30 words or fewer."
rule 30  "Put the main point or result first, then the details."
rule 30  "Use numbered lists for steps that occur in a sequence."
rule 40  "Write instructions as commands (imperative): \"Run the tests\", not \"You should run the tests\"."
rule 40  "Keep procedural sentences to 20 words or fewer and descriptive sentences to 25 words or fewer."
rule 40  "Do not use phrasal verbs (\"set up\", \"figure out\", \"look into\"). Use a single verb (\"configure\", \"find\", \"examine\")."
rule 50  "Do not use idioms, metaphors, slang, or humor."
rule 50  "Do not leave out articles (a, an, the) or the word \"that\" where they make the sentence clear."
rule 50  "Do not make noun clusters of more than three words. Break them up with prepositions."
rule 50  "Do not use -ing verb forms as nouns or adjectives, except in technical names."
rule 60  "Keep paragraphs to six sentences or fewer, with one topic per paragraph."
rule 60  "Use the passive voice only in descriptive text, and only when the agent is unknown or not important."
rule 70  "Use only these verb forms: simple present, simple past, simple future, imperative, and the infinitive. Do not use perfect or progressive tenses."
rule 70  "Do not use contractions."
rule 80  "Use common, concrete words. Give each word one meaning and use it as one part of speech only."
rule 80  "Put a warning or caution before the step it applies to. Start it with a short command that tells the reader what to do."
rule 90  "Write one instruction per sentence, unless two actions must occur at the same time."
rule 90  "Start each descriptive paragraph with a topic sentence."
rule 100 "Use only words from the STE dictionary, plus technical names (products, files, commands, APIs) and technical verbs of the subject field. If you do not know whether a word is approved, use the simplest common English word."

cat <<'EOF'

Accuracy has priority over compliance. This rule is more important than all of the rules above:
- Do not remove, soften, or generalize a caveat, an uncertainty, an edge case, a contradiction, or unusual behavior to make the text fit STE.
- If a rule forces you to lose or change meaning, break the rule and keep the meaning.
- Do not make strange or surprising results sound normal. Say clearly that they are strange.
EOF

if (( LEVEL >= 70 )); then
cat <<'EOF'
- Mark each place where you break a rule with ‡ and add a "STE deviations:" line at the end of the reply that gives the reason for each mark (for example: "‡ kept 'idempotent': no STE word has the same meaning").
EOF
else
cat <<'EOF'
- At this level you can break a rule without a mark when the meaning needs it.
EOF
fi

cat <<'EOF'

Scope: These rules apply to your prose to the user. Do not apply them to code, commands, file paths, identifiers, error messages, quoted text, tool inputs, or file contents, unless the user asks for that.
</ste100>
EOF
