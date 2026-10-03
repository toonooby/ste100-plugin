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
    [Oo][Ff][Ff]|0) echo 0; return ;;
  esac
  if ! [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "invalid" ; return
  fi
  # Strip leading zeros, then clamp before arithmetic can overflow.
  raw="${raw#"${raw%%[!0]*}"}"
  if [[ -z "$raw" ]]; then
    echo 0; return
  fi
  if (( ${#raw} > 2 )); then
    echo 100; return
  fi
  local n=$(( (10#$raw + 5) / 10 * 10 ))
  (( n < 10 )) && n=10
  (( n > 100 )) && n=100
  echo "$n"
}

resolve() {
  local f
  RESOLVED_LEVEL=0
  RESOLVED_SOURCE=default
  RESOLVED_SCOPE=default
  if [[ -n "${STE100_LEVEL:-}" ]]; then
    RESOLVED_LEVEL="$(normalize "$STE100_LEVEL")"
    RESOLVED_SOURCE=env:STE100_LEVEL
    RESOLVED_SCOPE="env"
    return 0
  fi
  for f in "$PROJECT_FILE" "$GLOBAL_FILE" "$LEGACY_GLOBAL_FILE"; do
    if [[ -f "$f" ]]; then
      RESOLVED_LEVEL="$(normalize "$(tr -d '[:space:]' < "$f")")"
      RESOLVED_SOURCE="file:$f"
      RESOLVED_SCOPE=global
      [[ "$f" == "$PROJECT_FILE" ]] && RESOLVED_SCOPE=project
      return 0
    fi
  done
  return 0
}

repair_help() {
  case "$RESOLVED_SCOPE" in
    env)
      echo 'Change or unset STE100_LEVEL in the environment that starts Claude Code or Codex, then start a new session.'
      ;;
    project)
      echo 'Send ste 70 --project or ste off --project to fix it, or ste clear --project to remove the project override.'
      ;;
    *)
      echo 'Send ste 70 or ste off to fix it.'
      ;;
  esac
}

describe() {
  local level source
  resolve
  level="$RESOLVED_LEVEL"
  source="$RESOLVED_SOURCE"
  if [[ "$level" == "0" ]]; then
    echo "STE100: off (source: $source)"
  elif [[ "$level" == "invalid" ]]; then
    printf 'STE100: off, because the level in %s is not valid. %s\n' "$source" "$(repair_help)"
  else
    echo "STE100: ${level}% (source: $source)"
  fi
}

if [[ "${1:-}" == "--resolve" ]]; then
  resolve
  printf '%s %s\n' "$RESOLVED_LEVEL" "$RESOLVED_SOURCE"
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

mkdir -p "${target%/*}"
echo "$level" > "$target"
# Move 0.1.x users off the old location so it cannot shadow a later `clear`.
[[ "$target" == "$GLOBAL_FILE" ]] && rm -f "$LEGACY_GLOBAL_FILE"
if [[ "$level" == "0" ]]; then
  echo "STE100 set to off ($target)"
else
  echo "STE100 set to ${level}% ($target). Applies from your next message."
fi
resolve
if [[ "$RESOLVED_SOURCE" != "file:$target" ]]; then
  printf 'Note: another setting overrides this file. '
  describe
fi
