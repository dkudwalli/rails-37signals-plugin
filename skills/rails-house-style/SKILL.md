---
name: rails-house-style
description: This skill should be used when writing, reviewing, or restructuring Ruby code in a Rails application — whenever the user asks to "add a feature", "refactor this", "where should this code go", "should I add a service object", "create app/services", "add a gem", mentions "vanilla Rails", "37signals style", "Basecamp style", "conceptual compression", or is choosing between a model, concern, PORO, service, presenter, or form object. Provides the philosophy, the Ruby style rules, and the list of libraries and directories these codebases deliberately refuse.
---

# Rails house style (37signals)

Extracted from three 37signals applications — Fizzy (kanban, newest), Once Campfire (chat), and
Writebook (publishing). Every rule below holds in all three unless a divergence is named.

## The load-bearing instruction

Before writing a new pattern, find the nearest existing example in the codebase and copy its shape
(`fizzy/STYLE.md:8`). Nearly every kind of thing that needs writing already exists somewhere. Prefer
consistency with the local code over individual judgement.

## Vanilla Rails

Thin controllers directly invoke a rich domain model. Nothing sits between them
(`fizzy/STYLE.md:155-157`).

**Rules:**

- Put code in Rails' standard directories. Do not create `app/services`, `app/presenters`,
  `app/serializers`, `app/forms`, `app/queries`, `app/interactors`, or `app/decorators`.
- Compress a behaviour into one concept that owns its name, and put that concept in the model. Do
  not spread one behaviour across a controller, a service, a job and a serializer.
- Treat `app/models/` as "the domain", not "subclasses of ActiveRecord::Base". Value objects,
  parsers, query objects and generators live there too (`fizzy/app/models/color.rb:1-3`,
  `fizzy/app/models/search/query.rb`, `writebook/app/models/html_scrubber.rb`).
- Use a plain object when it is genuinely the clearest domain object — `Signup.new(...).create_identity`
  is blessed (`fizzy/STYLE.md:179-183`) — but put it in `app/models/` under a domain name. A plain
  object is fine; a *layer* is not. Creating a directory to hold a category of object builds a layer.
- Prefer the option that adds no new process, no new service, and no new build step. Every piece of
  infrastructure is something a person has to operate.
- Prefer the framework's answer over a gem, and the newest framework answer over the one learned
  first. All three apps track edge Rails — flag edge-only APIs rather than assuming availability.

Before adding any dependency, check `references/absences.md` for what these apps use instead.

## Ruby style

The full rule set with verified counts is in `references/ruby-style.md`. The four that change how
code looks most:

- **Expanded conditionals over guard clauses.** Assign inside the condition and use `if/else` rather
  than opening a method with `return unless` (`fizzy/STYLE.md:10-32`). These codebases average about
  one guard clause per thousand lines of `app/`. The sanctioned exceptions: a return right at the
  start of the method, or a non-trivial multi-line body (`fizzy/STYLE.md:34-37`).
- **Order class methods, then public methods, then private methods; order each section by
  invocation** (`fizzy/STYLE.md:51-61`). A method appears above the methods it calls. When adding a
  private method, put it directly below its caller, not at the bottom of the class.
- **No blank line under `private`, and indent everything below it** (`fizzy/STYLE.md:105-124`). This
  is what `rubocop-rails-omakase` expects. A module containing only private methods puts `private`
  at the top with a blank line after and no indentation (`fizzy/STYLE.md:126-136`).
- **Use `!` only where a non-bang counterpart exists** (`fizzy/STYLE.md:99-103`). Never use `!` to
  flag that something is destructive. `Card#close` destroys a record and has no bang.

## Naming

- Concerns are adjectives: `Closeable`, `Postponable`, `Stallable`, `Searchable`, `Broadcastable`.
- Records that represent a state are nouns: `Closure`, `Goldness`, `NotNow`, `Publication`, `Ban`.
- Methods that enqueue end in `_later`; their synchronous partners end in `_now`.
- Predicates end in `?` and read as English: `filled?`, `awaiting_triage?`, `accepting_signups?`.
- Coining a slightly odd noun that exactly names the concept beats an accurate phrase that cannot be
  a class. `Goldness`, `NotNow`, `Involvement` and `Boost` are this product's vocabulary.

## Comments

Comments are sparse. Do not narrate what the code does. Record the reason, the history, or the
coupling (`fizzy/app/models/color.rb:14-16`). Mark duplicated logic that must stay in sync with an
explicit comment naming the other file
(`fizzy/app/javascript/controllers/bubble_controller.js:55`). When a comment concerns security, say
which layer is the actual defence.

## Related skills

Load the domain skill for the area being changed: `rails-models`, `rails-controllers-routing`,
`rails-views-helpers`, `rails-hotwire-javascript`, `rails-css`, `rails-jobs-async`,
`rails-data-search`, `rails-auth-security`, `rails-testing`, `rails-tooling-deploy`.

## Additional resources

- **`references/ruby-style.md`** — every style rule with its `STYLE.md` citation and the idioms
  `STYLE.md` does not mention (`.inquiry`, subjectless `case`, anonymous block forwarding, `it`,
  keyword arguments defaulting to `Current`, whitespace-aligned columns).
- **`references/absences.md`** — the libraries and directories these apps refuse, what replaces each,
  and the condition under which adding one is justified.
