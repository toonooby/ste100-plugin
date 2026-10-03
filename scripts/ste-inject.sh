#!/usr/bin/env bash
# UserPromptSubmit hook for Claude Code and Codex.
#
# A prompt like "ste 70", "/ste off" or "ste status --project" sets the level
# and is blocked, so it never reaches the model. Neither tool registers a plain
# /ste command for plugins (Codex has no plugin commands; Claude Code namespaces
# them), and both pass an unknown "/ste 70" through to this hook. Any other
# prompt gets the STE100 rules for the active level. Rules are cumulative: each
# level adds rules on top of the levels below it.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }'
}

# Both tools send JSON with "cwd" and "prompt". A level command never contains
# quotes or backslashes, so plain regexes are enough to read it.
ws='([[:space:]]|\\[nrt])*'
if [[ -z "${CLAUDE_PROJECT_DIR:-}" && $input =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
  export STE100_PROJECT_DIR="${BASH_REMATCH[1]}"
fi

shopt -s nocasematch
ste_prompt="\"prompt\"[[:space:]]*:[[:space:]]*\"${ws}/?(ste100:)?ste(([[:space:]]+[a-z0-9%]+)?([[:space:]]+--project)?)${ws}\""
if [[ $input =~ $ste_prompt ]]; then
  # Group 1 is the leading whitespace inside $ws, group 2 the optional
  # "ste100:" namespace; group 3 holds the arguments.
  args="$(printf '%s' "${BASH_REMATCH[3]}" | tr '[:upper:]' '[:lower:]')"
  if [[ $args =~ ^[[:space:]]*(([0-9]{1,3}%?|off|status|clear)([[:space:]]+--project)?)?[[:space:]]*$ ]]; then
    # shellcheck disable=SC2086 # word splitting turns "70 --project" into two args
    msg="$("$DIR/ste-level.sh" $args 2>&1)" || true
    printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$msg")"
    exit 0
  fi
fi
shopt -u nocasematch

read -r LEVEL SOURCE <<<"$("$DIR/ste-level.sh" --resolve)"
[[ "$LEVEL" == "0" ]] && exit 0
if [[ "$LEVEL" == "invalid" ]]; then
  echo "<ste100-error>The STE100 level setting (${SOURCE}) is not valid, so no STE100 rules apply. Tell the user once that sending \"ste 70\" or \"ste off\" fixes it.</ste100-error>"
  exit 0
fi

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
