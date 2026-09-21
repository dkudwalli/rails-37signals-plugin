# rails-37signals

A Claude Code plugin that makes Claude write Rails the way 37signals does: vanilla Rails, rich
models, no service layer, Minitest and fixtures, importmap, and plain CSS. The rules come from three
real applications — **Fizzy** (newest), **Once Campfire** and **Writebook** — and carry citations
into their source.

It is built from the *37signals Rails playbook* (observed 2026-09-18). The rules are copied into the
plugin, so it works on any machine without the playbook or source repositories. The commits each
application was read at are pinned in [`SOURCES.md`](SOURCES.md), and
`scripts/check-citations.sh` verifies every citation against a local checkout.

## What's included

Fourteen skills and one agent. Eleven skills are knowledge that loads when relevant; three are
task skills you invoke yourself.

### Knowledge skills (load automatically when relevant)

| Skill | Covers |
|---|---|
| `rails-house-style` | Philosophy, Ruby style, what these apps refuse to install and what they use instead |
| `rails-models` | Namespaced concerns, state as records, scopes, callbacks, `Current`, `delegated_type` |
| `rails-controllers-routing` | Nouns as resources, CRUD-only routes, `*Scoped` concerns, `direct`/`resolve` |
| `rails-views-helpers` | Small partials, `*_tag` helpers, cache-key versioning, safe escaping, jbuilder |
| `rails-hotwire-javascript` | Importmap without a build step, Stimulus conventions, Turbo, Action Cable authorization |
| `rails-css` | `@layer`, two-tier oklch tokens, dark mode, component custom properties, a11y baseline |
| `rails-jobs-async` | `_later`/`_now`, shallow jobs, tenant context across the queue, recurring tasks, mail, push |
| `rails-data-search` | Schema and migrations, SQLite, in-database FTS, UUIDs, storage, export/import |
| `rails-auth-security` | Session records, authorization by scoping, magic links, SSRF, Active Storage hardening |
| `rails-testing` | Minitest plus fixtures, integration tests, custom assertions, serial system tests |
| `rails-tooling-deploy` | `bin/setup`, `config/ci.rb`, RuboCop omakase, Docker, Kamal, config lifecycle, operability |

### Task skills (you invoke these)

These are skills, not `commands/` files — Claude Code exposes every plugin skill as
`/plugin-name:skill-name`, so they are invocable as slash commands without a separate command
definition.

| Skill | What it does |
|---|---|
| `/rails-37signals:rails-review [ref or paths]` | Reviews the diff against the playbook checklist and reports findings by severity |
| `/rails-37signals:rails-profile [AGENTS.md path]` | Walks you through choosing between the ONCE-compatible and Fizzy stacks, then records the choice in `AGENTS.md` |
| `/rails-37signals:rails-adopt [AGENTS.md or CLAUDE.md]` | Adds the condensed ruleset to the target repo's agent instructions |

`rails-adopt` only ever runs when you invoke it — it carries `disable-model-invocation`, because
it rewrites your `AGENTS.md`. `rails-profile` can also answer a stack question in passing ("Solid
Queue or Redis?") but asks before writing anything.

### Agent

`rails-reviewer` (`agents/rails-reviewer.md`) runs the checklist on its own after a Rails change, or
when you ask for a playbook review. It has no write or edit tools and is told to use Bash only for
read-only git commands. It reports findings; it does not change code.

**The agent does not carry its own checklist.** It loads the `rails-review` skill through the
`Skill` tool, so there is exactly one copy of the checklist to keep current. This is why
`rails-review` must stay model-invocable: `disable-model-invocation` would put it out of the
agent's reach. `scripts/check-structure.sh` enforces that.

No hooks, MCP servers or settings. The plugin advises and never blocks an edit.

## Installation

This repository is both the plugin and a one-plugin marketplace
(`.claude-plugin/marketplace.json`). You add the marketplace, then install the plugin from it.

### From GitHub

In Claude Code:

```text
/plugin marketplace add dkudwalli/rails-37signals-plugin
/plugin install rails-37signals@rails-37signals
```

Or from your shell:

```bash
claude plugin marketplace add dkudwalli/rails-37signals-plugin
claude plugin install rails-37signals@rails-37signals
```

Restart Claude Code if the skills don't appear. Run `/plugin` to check that `rails-37signals` is
installed and enabled.

### From a local clone

```bash
git clone https://github.com/dkudwalli/rails-37signals-plugin.git
claude plugin marketplace add ./rails-37signals-plugin
claude plugin install rails-37signals@rails-37signals
```

To try it for one session without installing:

```bash
claude --plugin-dir /path/to/rails-37signals-plugin
```

### For a whole team

To have Claude Code offer the plugin to everyone who opens a Rails repo, commit this to the repo's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "rails-37signals": {
      "source": { "source": "github", "repo": "dkudwalli/rails-37signals-plugin" }
    }
  },
  "enabledPlugins": {
    "rails-37signals@rails-37signals": true
  }
}
```

Each person is asked to trust the marketplace the first time they open the repo.

### Updating and removing

```text
/plugin marketplace update rails-37signals
/plugin uninstall rails-37signals@rails-37signals
```

## Suggested first run in a Rails app

1. `/rails-37signals:rails-profile`: choose and record the application profile.
2. `/rails-37signals:rails-adopt`: add the ruleset to `AGENTS.md` so every session follows it.
3. Work as usual. The domain skills load when they're relevant.
4. `/rails-37signals:rails-review` before you commit.

## Two warnings

**All three source apps track edge Rails.** `params.expect`, `ActiveSupport::ContinuousIntegration`,
`broadcasts_refreshes` with morphing, and UUIDv7 primary keys may not exist, or may behave
differently, on the Rails version you run. The skills and reviewer mark these APIs as needing a
version check.

**The source apps disagree with each other, and the newest one wins.** Campfire and Writebook run
Redis and Resque; Fizzy runs Solid Queue, Cache and Cable with no Redis. The plugin names both and
never recommends a mix. Where they conflict, it defaults to Fizzy unless the profile you recorded
says otherwise.

## Keeping it current

The skills are copies of the playbook's chapters. When a chapter changes, update the matching skill
and copy the new `PLAYBOOK.md` over `skills/rails-adopt/assets/PLAYBOOK.md`. Then bump `version` in
**both** `.claude-plugin/plugin.json` and the entry in `.claude-plugin/marketplace.json` —
`claude plugin tag --dry-run` checks that the two agree.

Some skills keep their detail in `references/`, which the table below does not list: `rails-house-style`
(`ruby-style.md`, `absences.md`), `rails-models` (`patterns.md`), `rails-testing` (`patterns.md`),
`rails-auth-security` (`hardening.md`) and `rails-hotwire-javascript` (`native-and-pwa.md`). Check
those too.

Before releasing, run the checks:

```bash
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict
claude plugin validate ./skills --strict
claude plugin validate ./agents --strict
./scripts/check-structure.sh          # invariants that are invisible in a diff
./scripts/check-citation-format.sh    # citation style
./scripts/check-citations.sh          # every citation resolves (needs the checkouts)
claude plugin eval . --ablation with-without   # does the plugin change behaviour?
```

The first six run in CI (`.github/workflows/ci.yml`); `check-citations.sh` needs local checkouts of
the three applications, so it is a local/release step. The evals cost money per run and are not on
every push.

| Playbook chapters | Skill |
|---|---|
| 01, 02, 13, 14 | `rails-house-style` |
| 03 | `rails-models` |
| 04 | `rails-controllers-routing` |
| 05 | `rails-views-helpers` |
| 06, 17 | `rails-hotwire-javascript`, `rails-jobs-async` (mail and push) |
| 07 | `rails-css` |
| 08 | `rails-jobs-async` |
| 09, 18 | `rails-data-search` |
| 10, 18, 19 | `rails-auth-security` |
| 11 | `rails-testing` |
| 12, 16, 20 | `rails-tooling-deploy` |
| 15 | `rails-review`, `rails-reviewer` agent |
| 21 | `rails-profile` |
| `PLAYBOOK.md` | `rails-adopt` asset |

## License

MIT
