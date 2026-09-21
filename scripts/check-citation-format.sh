#!/usr/bin/env bash
#
# Check citation *format* without needing the source checkouts.
# Path and line-range verification is scripts/check-citations.sh, which does need them.
#
# Rules enforced (see SOURCES.md):
#   - repository names are lowercase: fizzy, once-campfire, writebook
#   - no multi-range citations (`file.rb:4-9, 68-88`) — write two citations
#   - no bare `campfire/` — the directory is once-campfire

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
targets=(skills agents)

report() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -rnE "$pattern" "${targets[@]}" 2>/dev/null) || true
  if [ -n "$hits" ]; then
    echo "$label"
    printf '%s\n' "$hits" | sed 's/^/    /'
    echo
    fail=1
  fi
}

# Capitalised repo name inside a backticked path, e.g. `Fizzy/app/...`
report "Capitalised repository name in a path (use lowercase in citations):" \
  '`(Fizzy|Campfire|Once-[Cc]ampfire|Writebook)/'

# `campfire/...` should be `once-campfire/...`
report "Bare 'campfire/' in a path (the directory is once-campfire):" \
  '`campfire/'

# Multi-range citations: `file.rb:4-9, 68-88`
report "Multi-range citation (write two separate citations instead):" \
  '`(fizzy|once-campfire|writebook)/[A-Za-z0-9_./-]+:[0-9]+(-[0-9]+)?, *[0-9]+'

if [ "$fail" -eq 0 ]; then
  echo "Citation format OK."
fi

exit "$fail"
