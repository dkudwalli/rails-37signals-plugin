#!/usr/bin/env bash
#
# Verify every source citation in the plugin against real checkouts of the three
# applications the rules were read from.
#
# A citation looks like `fizzy/app/models/card.rb:22-24` or `writebook/app/helpers/forms_helper.rb`.
# This script asserts the file exists and, when a line range is given, that the range is
# within the file. It does not check that the cited lines still say what the rule claims —
# that needs a human, which is what SOURCES.md pins commits for.
#
# Usage:
#   scripts/check-citations.sh [checkout-parent-dir]
#
# checkout-parent-dir defaults to $RAILS_37SIGNALS_SRC, then to ~/Projects.
# It must contain fizzy/, once-campfire/ and writebook/.
#
# Exit codes: 0 all citations resolve, 1 one or more are broken, 2 checkouts not found.

set -uo pipefail

SRC="${1:-${RAILS_37SIGNALS_SRC:-$HOME/Projects}}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

missing_checkouts=()
for app in fizzy once-campfire writebook; do
  [ -d "$SRC/$app" ] || missing_checkouts+=("$app")
done

if [ ${#missing_checkouts[@]} -gt 0 ]; then
  echo "Source checkouts not found under: $SRC"
  printf '  missing: %s\n' "${missing_checkouts[*]}"
  echo
  echo "Clone them, or point at them:"
  echo "  scripts/check-citations.sh /path/to/parent"
  echo "  RAILS_37SIGNALS_SRC=/path/to/parent scripts/check-citations.sh"
  echo "See SOURCES.md for the commits these rules were read from."
  exit 2
fi

ok=0
broken=0

# Citations are backticked repo-relative paths, optionally followed by :start-end or :line.
# Multi-range forms (`file.rb:4-9, 68-88`) are checked on their first range only.
while IFS= read -r citation; do
  # `fizzy/...` and friends are prose describing the citation format, not claims about a file.
  case "$citation" in
    *...*) continue ;;
  esac

  path="${citation%%:*}"
  rest="${citation#"$path"}"
  rest="${rest#:}"

  file="$SRC/$path"

  if [ ! -f "$file" ]; then
    echo "MISSING FILE   $citation"
    broken=$((broken + 1))
    continue
  fi

  if [ -n "$rest" ]; then
    start="${rest%%-*}"
    end="${rest#*-}"
    [ "$end" = "$rest" ] && end="$start"

    # Skip anything non-numeric rather than guessing at it.
    if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
      lines=$(wc -l < "$file")
      # A file with no trailing newline still has content on its last line.
      [ "$lines" -eq 0 ] && lines=1
      if [ "$end" -gt "$lines" ]; then
        echo "RANGE PAST EOF $citation (file has $lines lines)"
        broken=$((broken + 1))
        continue
      fi
      if [ "$start" -gt "$end" ]; then
        echo "BAD RANGE      $citation (start after end)"
        broken=$((broken + 1))
        continue
      fi
    fi
  fi

  ok=$((ok + 1))
done < <(
  grep -rhoE '`(fizzy|once-campfire|writebook)/[A-Za-z0-9_./-]+(:[0-9]+(-[0-9]+)?)?`' \
    "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/agents" 2>/dev/null \
    | tr -d '`' \
    | sort -u
)

echo
echo "checked against: $SRC"
echo "resolved: $ok"
echo "broken:   $broken"

if [ "$broken" -gt 0 ]; then
  echo
  echo "Citations must resolve. Fix the path or the line range, and if the source moved,"
  echo "update the pinned commit in SOURCES.md."
  exit 1
fi

exit 0
