---
name: rails-review
description: This skill should be used when the user asks to "review this Rails code", "review my Rails PR", "review the diff" in a Rails app, "check this against the 37signals playbook", "is this vanilla Rails", or runs /rails-37signals:rails-review. Runs the 37signals Rails review checklist against the current diff, a branch, or named files and reports findings with the rule each one breaks.
argument-hint: "[base-ref | file paths]  (default: uncommitted changes, else HEAD vs main)"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git merge-base:*), Bash(git rev-parse:*), Read, Grep, Glob
---

# Rails review against the 37signals checklist

Review Rails changes against the checklist below. It is a checklist, not a scorecard: a relevant
unchecked item is a reason to raise a finding or ask a question.

## Step 1: Determine the scope

Interpret `$ARGUMENTS`:

- Empty: review uncommitted changes — `git diff HEAD` for tracked files, plus every untracked file
  listed by `git status --porcelain` (lines starting `??`), read in full. If there are none, review the
  current branch against its merge-base with `main` (or `master`).
- A git ref (confirm with `git rev-parse --verify <arg>`): review `git diff <ref>...HEAD`.
- File paths: review those files in full.

Read enough surrounding code to judge each change — at minimum the whole file for any changed model,
controller, concern, or `routes.rb`.

## Step 2: Read the application profile

Check `AGENTS.md` / `CLAUDE.md` at the repository root for an `## Application profile` block
(Fizzy or ONCE-compatible). Deviations recorded there are deliberate — do not flag them. If there is
no profile and the diff touches jobs, cache, cable, database, storage or deploy configuration, flag
the missing profile and suggest `/rails-37signals:rails-profile`.

Check `Gemfile` / `Gemfile.lock` for the Rails version. When a finding recommends an edge-Rails API
(`params.expect`, `ActiveSupport::ContinuousIntegration`, `broadcasts_refreshes` morphing, UUIDv7
support), note that it needs the target's Rails version to support it.

## Step 3: Apply the checklist to the changed code only

### Shape
- Code sits in a standard Rails location; no new `app/services`, `presenters`, `forms`, `queries`,
  `serializers`, `decorators`, `interactors`.
- Controllers call a model API directly rather than a default service layer.
- Behaviour that already exists as a model concern, helper, partial or browser API is reused.
- A new domain transition has a noun and a resource, not a custom controller verb or `member` route.
- The diff is the smallest complete change, including the migration, index and test its invariant needs.

### Ruby and models
- Names explain the domain operation without a translating comment.
- Methods ordered by invocation; private methods below an indented `private` with no blank line after it.
- Expanded conditionals rather than mid-method guard clauses.
- `!` only where a non-bang counterpart exists.
- The model owns persistence, transitions, callbacks and scopes that belong to it; a feature's
  association lives in the same concern as its behaviour.
- A boolean/timestamp that needs who/when/an endpoint is a state record instead.
- Default associations, `Current`, and async context are explicit.
- Orderings break timestamp ties with `id`.
- An absolute invariant has a database constraint or unique index, not only a validation.

### HTTP, view and browser
- New endpoints are conventional CRUD, nested only as far as ownership requires, with `only:`/`except:`.
- Record lookups are scoped through the current actor, enforcing authorization by construction.
- Unauthenticated access is an explicit controller macro, not an ad-hoc `skip_before_action`.
- Views are split into small partials with explicit locals; shared display logic is in a helper.
- A Stimulus controller owns one behaviour, uses targets/values, keeps non-action methods `#private`,
  and pairs every `connect` side effect with `disconnect`.
- Importmap / native HTML / CSS is used before any JavaScript or CSS build dependency.
- Interactive UI keeps semantic HTML, keyboard access and visible focus.
- A feature fetching a user-supplied URL denies by resolved IP and pins that address.
- Framework controllers that can reach this data (Active Storage, `Turbo::StreamsChannel`) are guarded
  too, not only the app's own controllers.
- A new cached fragment carries a version in its key when its output depends on helper Ruby, Action
  Text, or a partial the digestor cannot follow.
- `html_safe` appears only after an explicit escape or scrub.

### Async, data and operations
- The ONCE-compatible or Fizzy profile is recorded, and deviations are called out.
- A job delegates to a model; `_later`/`_now` naming is used; enqueueing happens in `after_*_commit`.
- Ending a session also ends the live Cable connections it authorized.
- An async job serializes all required tenant/request context rather than leaking `Current`.
- One queue/cache/cable family is used — Solid and Redis stacks are not mixed.
- Migrations are small, use `change`, and are named after one concern.
- Search stays in the database; user input is rebuilt from allowlisted tokens and bound, never
  interpolated.
- Setup stays rerunnable, with destructive work behind an explicit flag.
- CI runs style, security checks, and serial system tests.
- The production image has a build stage, no baked secrets, and a non-root runtime user.

### Tests
- An existing fixture is used before constructing records; no factories.
- Test setup is limited to process state; data is visible in fixtures or the test body.
- Assertions target user-observable output or the domain boundary, not assigns or implementation.
- Authorization/scoping, the unhappy path and background behaviour are covered where relevant.
- External HTTP is stubbed with WebMock/VCR only at a real boundary.
- New non-trivial logic has one small test that fails when it breaks.

## Step 4: Report

Group findings by severity:

1. **Security** — authorization gaps, unguarded framework controllers, SSRF, unescaped HTML, missing
   rate limits, leaked context.
2. **Correctness** — race-prone callbacks, missing constraints, non-deterministic ordering, context not
   crossing a job boundary.
3. **Structure** — service layers, custom actions, logic in controllers, mixed stacks.
4. **Style** — ordering, guard clauses, naming, test style.

For each finding give `path:line`, one sentence on what is wrong, the rule it breaks, and the smallest
concrete fix. Do not report items that pass. If nothing fails, say so plainly in one line.

For the rule text and source citations behind any finding, load the matching domain skill
(`rails-models`, `rails-controllers-routing`, `rails-auth-security`, and so on).
