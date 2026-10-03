#!/usr/bin/env bash
# UserPromptSubmit hook for Claude Code and Codex.
#
# A prompt like "ste 70", "/ste off" or "ste status --project" sets the level
# and is blocked, so it never reaches the model. Neither tool registers a plain
# /ste command for plugins (Codex has no plugin commands; Claude Code namespaces
# them), and both pass an unknown "/ste 70" through to this hook. Any other
# prompt gets the current STE100 mode, replacing earlier hook instructions.
# Rules are cumulative: each level adds rules on top of the levels below it.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"

off_context() {
  cat <<'EOF'
<ste100 level="0">
Automatic STE100 styling is off. This replaces all earlier STE100 hook instructions. Do not apply their writing rules or add their STE deviations line. Follow the user's requested style. This does not cancel an explicit request to write or rewrite text in STE.
</ste100>
EOF
}

if ! command -v jq >/dev/null 2>&1; then
  off_context
  echo '<ste100-error>The STE100 hook needs jq. Tell the user once to install jq and restart Claude Code or Codex. Automatic STE100 styling is off until jq is available.</ste100-error>'
  exit 0
fi

# Decode the event before matching commands. JSON escapes can occur in both
# prompts and project paths. Reject malformed events without retaining old rules.
if ! jq -se '
  length == 1 and (.[0] | type == "object") and
  (.[0].prompt | type == "string") and
  ((.[0].cwd // "") | type == "string") and
  ((.[0].prompt | contains("\u0000")) | not) and
  (((.[0].cwd // "") | contains("\u0000")) | not)
' <<<"$input" >/dev/null 2>&1; then
  off_context
  echo '<ste100-error>The STE100 hook could not read its JSON input. No automatic STE100 rules apply to this message. Tell the user once about the hook input error.</ste100-error>'
  exit 0
fi

# NUL delimiters preserve trailing newlines in a valid Unix directory name.
IFS= read -r -d '' prompt < <(jq -j '.prompt, "\u0000"' <<<"$input") || true
IFS= read -r -d '' project_dir < <(jq -j '.cwd // "", "\u0000"' <<<"$input") || true
if [[ -z "${STE100_PROJECT_DIR:-}" && -z "${CLAUDE_PROJECT_DIR:-}" && -n "$project_dir" ]]; then
  export STE100_PROJECT_DIR="$project_dir"
fi

shopt -s nocasematch
ste_prompt='^[[:space:]]*/?(ste100:)?ste([[:space:]]+([0-9]{1,3}%?|off|status|clear))?([[:space:]]+(--project))?[[:space:]]*$'
if [[ $prompt =~ $ste_prompt ]]; then
  arg="${BASH_REMATCH[3]:-}"
  scope="${BASH_REMATCH[5]:-}"
  arg="$(printf '%s' "$arg" | tr '[:upper:]' '[:lower:]')"
  [[ -n "$scope" ]] && scope=--project
  msg="$("$DIR/ste-level.sh" "$arg" "$scope" 2>&1)" || true
  jq -n --arg reason "$msg" '{decision: "block", reason: $reason}'
  exit 0
fi
shopt -u nocasematch

read -r LEVEL _ <<<"$("$DIR/ste-level.sh" --resolve)"
if [[ "$LEVEL" == "0" ]]; then
  off_context
  exit 0
fi
if [[ "$LEVEL" == "invalid" ]]; then
  off_context
  printf '<ste100-error>%s Tell the user once about the invalid setting and how to repair it.</ste100-error>\n' "$("$DIR/ste-level.sh")"
  exit 0
fi

rule() { (( LEVEL >= $1 )) && echo "- $2"; return 0; }

cat <<EOF
<ste100 level="${LEVEL}">
This replaces all earlier STE100 hook instructions. Only the rules in this block apply to automatic STE100 styling, including when this level is lower than an earlier level.
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
