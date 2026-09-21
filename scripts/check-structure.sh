#!/usr/bin/env bash
#
# Structural invariants that are easy to break by accident and impossible to
# see in a diff. Each one encodes a decision, with the reason attached.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ok    %s\n' "$label"
  else
    printf '  FAIL  %s (expected %s, got %s)\n' "$label" "$expected" "$actual"
    fail=1
  fi
}

echo "Review checklist is single-sourced"
# The agent must delegate to the rails-review skill rather than carrying its own copy.
# Two copies silently drift; that is what this whole arrangement exists to prevent.
# Distinctive checklist rules. These appear in the skill's checklist and nowhere
# else, so any of them turning up in the agent means the checklist was copied back in.
# (`app/services` is deliberately NOT one of these — it is a legitimate trigger
# example in the agent's "When to invoke" section.)
check "agent does not inline checklist rules" \
  "$(grep -cE 'html_safe|after_\*_commit|unique index' agents/rails-reviewer.md)" 0
check "agent loads the skill" \
  "$(grep -c 'rails-37signals:rails-review' agents/rails-reviewer.md)" 1
check "skill still owns a checklist" \
  "$(grep -c 'app/services' skills/rails-review/SKILL.md)" 1

echo
echo "Model invocation flags"
# rails-review MUST stay model-invocable: disable-model-invocation makes it
# unreachable from the rails-reviewer agent via the Skill tool.
check "rails-review is model-invocable" \
  "$(grep -c 'disable-model-invocation' skills/rails-review/SKILL.md)" 0
# rails-profile answers "Solid Queue or Redis?", so it must be model-invocable too.
check "rails-profile is model-invocable" \
  "$(grep -c 'disable-model-invocation' skills/rails-profile/SKILL.md)" 0
# rails-adopt writes to the user's AGENTS.md; it stays explicit-only.
check "rails-adopt is explicit-only" \
  "$(grep -c 'disable-model-invocation' skills/rails-adopt/SKILL.md)" 1

echo
echo "No duplicated decision tables"
# The ONCE-vs-Fizzy table lives in rails-profile alone. Copies drift.
check "profile table appears once" \
  "$(grep -rlc '^| Product boundary' skills/*/SKILL.md | wc -l)" 1

echo
echo "Every skill has a name and description"
missing=0
for f in skills/*/SKILL.md; do
  grep -q '^name:' "$f" || { echo "  FAIL  $f has no name:"; missing=1; }
  grep -q '^description:' "$f" || { echo "  FAIL  $f has no description:"; missing=1; }
  dir=$(basename "$(dirname "$f")")
  nm=$(awk -F': ' '/^name: /{print $2; exit}' "$f")
  [ "$dir" = "$nm" ] || { echo "  FAIL  $f name '$nm' != directory '$dir'"; missing=1; }
done
[ "$missing" -eq 0 ] && echo "  ok    all skills well-formed" || fail=1

echo
if [ "$fail" -eq 0 ]; then
  echo "Structure OK."
else
  echo "Structural invariant broken. Each check above names the decision it protects."
fi
exit "$fail"
