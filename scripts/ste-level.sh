#!/usr/bin/env bash
# Read or set the STE100 compliance level.
#
#   ste-level.sh                 print the active level and where it came from
#   ste-level.sh 70              set the global level (10-100, rounded to 10)
#   ste-level.sh off             turn STE off globally
#   ste-level.sh 70 --project    set the level for the current project only
#   ste-level.sh clear --project remove the project override
#
# Precedence: $STE100_LEVEL > <project>/.claude/ste100-level > ~/.claude/ste100/level
set -euo pipefail

GLOBAL_FILE="${HOME}/.claude/ste100/level"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_FILE="${PROJECT_DIR}/.claude/ste100-level"

normalize() {
  local raw="${1%\%}"
  case "$raw" in
    off|OFF|0) echo 0; return ;;
  esac
  if ! [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "invalid" ; return
  fi
  local n=$(( (raw + 5) / 10 * 10 ))
  (( n < 10 )) && n=10
  (( n > 100 )) && n=100
  echo "$n"
}

resolve() {
  if [[ -n "${STE100_LEVEL:-}" ]]; then
    echo "$(normalize "$STE100_LEVEL") env:STE100_LEVEL"
  elif [[ -f "$PROJECT_FILE" ]]; then
    echo "$(normalize "$(tr -d '[:space:]' < "$PROJECT_FILE")") project:$PROJECT_FILE"
  elif [[ -f "$GLOBAL_FILE" ]]; then
    echo "$(normalize "$(tr -d '[:space:]' < "$GLOBAL_FILE")") global:$GLOBAL_FILE"
  else
    echo "0 default"
  fi
}

if [[ "${1:-}" == "--resolve" ]]; then
  resolve
  exit 0
fi

arg="${1:-}"
scope="${2:-}"

if [[ -z "$arg" || "$arg" == "status" ]]; then
  read -r level source <<<"$(resolve)"
  if [[ "$level" == "0" ]]; then
    echo "STE100: off (source: $source)"
  else
    echo "STE100: ${level}% (source: $source)"
  fi
  exit 0
fi

target="$GLOBAL_FILE"
[[ "$scope" == "--project" ]] && target="$PROJECT_FILE"

if [[ "$arg" == "clear" ]]; then
  rm -f "$target"
  echo "Removed $target"
  read -r level source <<<"$(resolve)"
  echo "STE100 now: $([[ $level == 0 ]] && echo off || echo "${level}%") (source: $source)"
  exit 0
fi

level="$(normalize "$arg")"
if [[ "$level" == "invalid" ]]; then
  echo "Usage: /ste [10-100 | off | status | clear] [--project]" >&2
  exit 1
fi

mkdir -p "$(dirname "$target")"
echo "$level" > "$target"
if [[ "$level" == "0" ]]; then
  echo "STE100 set to off ($target)"
else
  echo "STE100 set to ${level}% ($target). Applies from your next message."
fi
if [[ -n "${STE100_LEVEL:-}" ]]; then
  echo "Note: STE100_LEVEL=${STE100_LEVEL} is set in the environment and overrides this file."
fi
