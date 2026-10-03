#!/usr/bin/env bash
# Read or set the STE100 compliance level. Shared by Claude Code and Codex.
#
#   ste-level.sh                 print the active level and where it came from
#   ste-level.sh 70              set the global level (10-100, rounded to 10)
#   ste-level.sh off             turn STE off globally
#   ste-level.sh 70 --project    set the level for the current project only
#   ste-level.sh clear --project remove the project override
#
# Precedence: $STE100_LEVEL > <project>/.ste100-level > ~/.config/ste100/level
set -euo pipefail

GLOBAL_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ste100/level"
LEGACY_GLOBAL_FILE="${HOME}/.claude/ste100/level" # written by 0.1.x
PROJECT_DIR="${STE100_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"
PROJECT_FILE="${PROJECT_DIR}/.ste100-level"

normalize() {
  local raw="${1%\%}"
  case "$raw" in
    off|OFF|0) echo 0; return ;;
  esac
  if ! [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "invalid" ; return
  fi
  local n=$(( (10#$raw + 5) / 10 * 10 ))
  (( n < 10 )) && n=10
  (( n > 100 )) && n=100
  echo "$n"
}

resolve() {
  local f
  if [[ -n "${STE100_LEVEL:-}" ]]; then
    echo "$(normalize "$STE100_LEVEL") env:STE100_LEVEL"
    return
  fi
  for f in "$PROJECT_FILE" "$GLOBAL_FILE" "$LEGACY_GLOBAL_FILE"; do
    if [[ -f "$f" ]]; then
      echo "$(normalize "$(tr -d '[:space:]' < "$f")") file:$f"
      return
    fi
  done
  echo "0 default"
}

describe() {
  local level source
  read -r level source <<<"$(resolve)"
  if [[ "$level" == "0" ]]; then
    echo "STE100: off (source: $source)"
  elif [[ "$level" == "invalid" ]]; then
    echo "STE100: off, because the level in $source is not valid. Send ste <10-100> or ste off to fix it."
  else
    echo "STE100: ${level}% (source: $source)"
  fi
}

if [[ "${1:-}" == "--resolve" ]]; then
  resolve
  exit 0
fi

arg="${1:-}"
scope="${2:-}"

if [[ -z "$arg" || "$arg" == "status" ]]; then
  describe
  exit 0
fi

target="$GLOBAL_FILE"
[[ "$scope" == "--project" ]] && target="$PROJECT_FILE"

if [[ "$arg" == "clear" ]]; then
  rm -f "$target"
  [[ "$target" == "$GLOBAL_FILE" ]] && rm -f "$LEGACY_GLOBAL_FILE"
  echo "Removed $target"
  describe
  exit 0
fi

level="$(normalize "$arg")"
if [[ "$level" == "invalid" ]]; then
  echo "Usage: ste <10-100 | off | status | clear> [--project]" >&2
  exit 1
fi

mkdir -p "$(dirname "$target")"
echo "$level" > "$target"
# Move 0.1.x users off the old location so it cannot shadow a later `clear`.
[[ "$target" == "$GLOBAL_FILE" ]] && rm -f "$LEGACY_GLOBAL_FILE"
if [[ "$level" == "0" ]]; then
  echo "STE100 set to off ($target)"
else
  echo "STE100 set to ${level}% ($target). Applies from your next message."
fi
if [[ -n "${STE100_LEVEL:-}" ]]; then
  echo "Note: STE100_LEVEL=${STE100_LEVEL} is set in the environment and overrides this file."
fi
