# 37signals Rails playbook

Copy this into a Rails application's `AGENTS.md` or `CLAUDE.md`. These are defaults; retain an
explicit product constraint when it requires a documented divergence.

## Build shape

- Use vanilla Rails: thin controllers call rich domain models directly. Do not add a default service layer. (`fizzy/STYLE.md:155-183`)
- Put code in Rails' standard directories. Do not create `app/services`, `presenters`, `forms`, `queries`, or `serializers` by default. (`13-absences.md`)
- Split a growing model into namespaced concerns beside it; keep the model as the domain's front door. (`fizzy/app/models/card.rb:1-26`)
- Use a plain PORO only when it is the clearest domain object, not because it has a special category. (`fizzy/STYLE.md:179-183`)
- Reuse a local pattern, Rails API, stdlib, or browser feature before adding a dependency.

## Ruby

- Prefer expanded conditionals over mid-method guard clauses; use early return only at the method start when it improves the flow. (`fizzy/STYLE.md:10-49`)
- Order class methods, public methods, then private methods; order each section by invocation. (`fizzy/STYLE.md:51-97`)
- Indent below visibility modifiers; put `private` first in a module containing only private methods. (`fizzy/STYLE.md:105-136`)
- Use `!` only where a non-bang counterpart exists, not merely to mark mutation. (`fizzy/STYLE.md:99-103`)
- Let model method names describe domain transitions; do not translate generic controller verbs into hidden business logic.

## Models and data

- Make models own associations, scopes, transitions, callbacks, and persistence. (`fizzy/app/models/card.rb:6-26, 58-94`)
- Use small named concerns for cohesive slices of model behaviour. (`fizzy/app/models/card.rb:1-4`)
- Put association defaults at the association when the current context is truly the domain default. (`fizzy/app/models/card.rb:6-8`)
- Order by a timestamp and `id` to make ties deterministic. (`fizzy/app/models/card.rb:22-24`)
- Put unconditional uniqueness/integrity in a database index or constraint, not only a validation. (`09-data-search.md`)
- Keep migrations small and single-purpose; use `change` where it is sufficient. (`09-data-search.md`)
- Start with SQLite and database-backed search; add a database/server only for a real product need. (`14-divergences.md`)
- Adopt UUIDv7 only with its complete operational and fixture implications. (`09-data-search.md`)
- Rebuild a search query from allowlisted tokens; do not blocklist the operators you fear. (`09-data-search.md`)

## Routing and controllers

- Name state changes and relationships as nouns, then expose them as resources. Do not add a custom action for ordinary domain behaviour. (`fizzy/config/routes.rb:81-107`; `fizzy/STYLE.md:138-153`)
- Nest routes only to express ownership; use `scope module:` to keep controller names aligned. (`fizzy/config/routes.rb:13-26`)
- Keep controllers to loading, parameter handling, model invocation, and response selection.
- Scope record lookups through the current actor so inaccessible records are unreachable. (`04-controllers-routing.md`)
- Use `params.expect` for required parameter shapes on edge Rails. (`04-controllers-routing.md`)
- Use `direct` / `resolve` for polymorphic URL mapping rather than scattering route conditionals. (`fizzy/config/routes.rb:218-245`)
- Keep custom routes only for integrations, protocol endpoints, or compatibility redirects; name the exception. (`once-campfire/config/routes.rb:62-90`; `fizzy/config/routes.rb:247-262`)

## Authentication and authorization

- Secure controllers by default; opt out through a named access macro, not a scattered callback skip. (`10-auth-security.md`)
- Store sessions as records and only a signed token or signed id in the cookie. (`10-auth-security.md`)
- Put authorization predicates on models and enforce normal access through scoped lookups. (`10-auth-security.md`)
- Record how a request authenticated and apply CSRF/capability policy to the credential type. (`10-auth-security.md`)
- Deny fetches of user-supplied URLs by resolved IP, never hostname; pin the address you checked. (`10-auth-security.md`)
- Share the SSRF address policy across apps as a gem; keep a local test of addresses you will not serve. (`10-auth-security.md`)
- Close live Action Cable connections when a session ends; session revocation is not connection revocation. (`17-realtime-notifications.md`)
- Authenticate `ActiveStorage::DirectUploadsController` and `DiskController#update` even if you never use direct uploads. (`18-content-storage-portability.md`)
- Drive an embed/HTML allowlist from one table feeding both the sanitiser and the CSP; version the policy. (`10-auth-security.md`)

## Views, Hotwire, and CSS

- Prefer small ERB partials and helpers; do not introduce presenters/ViewComponents by default. (`05-views-helpers.md`)
- Use importmap and native browser modules; do not add a JavaScript build step by default. (`fizzy/Gemfile:7-11`)
- Give each Stimulus controller one behaviour; use targets/values and private `#methods`. (`fizzy/app/javascript/controllers/auto_save_controller.js:1-47`)
- Use Turbo broadcasts/refreshes for server-rendered live updates before custom client state. (`06-hotwire-javascript.md`)
- Authenticate Cable connections and scope every channel stream through the current actor. (`17-realtime-notifications.md`)
- Guard `Turbo::StreamsChannel` too; a signed stream name proves provenance, not permission. (`17-realtime-notifications.md`)
- Version a cached partial's key when its output depends on code the template digestor cannot see. (`05-views-helpers.md`)
- Write plain CSS in component files, with native nesting, `@layer`, and custom-property tokens. (`fizzy/app/assets/stylesheets/buttons.css:1-39`; layer order at `fizzy/app/assets/stylesheets/_global.css:1`)
- Use semantic HTML, visible focus, keyboard access, and responsive/hover-aware CSS as baseline accessibility.

## Jobs and infrastructure

- Keep jobs shallow: enqueue from a `_later` method and delegate the work to `_now` or another model API. (`fizzy/STYLE.md:185-213`)
- Serialize tenant context into jobs; never rely on ambient `Current` surviving a queue boundary. (`fizzy/app/jobs/concerns/account_tenanted.rb:1-46`)
- Use Solid Queue/Cache/Cable together for new Rails apps unless an explicit product constraint selects Redis/Resque. (`14-divergences.md`)
- Use one database-backed full-text-search approach before adding a search service. (`09-data-search.md`)
- Treat attachments as protected domain content; authorize every Active Storage serving path. (`18-content-storage-portability.md`)
- Persist integration deliveries, sign and bound outbound requests, and reject private network targets. (`19-integrations-webhooks.md`)

## Tests

- Use Minitest and fixtures; reach for an existing fixture before creating a record. (`writebook/test/test_helper.rb:5-14`; `11-testing.md`)
- Keep global setup for process state, not test data. (`fizzy/test/test_helper.rb:45-73`)
- Run ordinary tests in parallel; run browser/system tests serially if shared state makes them unreliable. (`fizzy/config/ci.rb:5-7, 28-29`)
- Assert response/body/domain behaviour rather than implementation details. (`writebook/AGENTS.md:21-34`)
- Add one focused test for new non-trivial logic; do not scaffold a test framework around it.

## Tooling and deploy

- Make `bin/setup` rerunnable; keep destructive reset work behind `--reset`; use `rails db:prepare`. (`writebook/bin/setup:8-23`)
- Run CI as readable ordered shell steps: setup, style, security, tests, release signoff. (`fizzy/config/ci.rb:9-35`)
- Start RuboCop with `rubocop-rails-omakase`; add local rules only for actual team choices. (`fizzy/.rubocop.yml:1-20`)
- Build a multi-stage production image, precompile assets without a real secret, and run it as non-root. (`fizzy/Dockerfile:30-83`)
- Commit deploy configuration, keep secrets outside Git, and declare/backup persistent storage. (`fizzy/config/deploy.yml:17-60`)
- Keep production observable with request-tagged stdout logs, filtered parameters, and a cheap `/up` health check. (`20-performance-operability.md`)

## Explicit divergences

- Select and record an ONCE-compatible or Fizzy application profile before combining database, queue, cache, cable, storage, and deploy choices. (`21-new-app-decisions.md`)
- Do not mix Fizzy's Solid stack with Campfire/Writebook's Redis/Resque stack. Pick one. (`14-divergences.md`)
- Do not copy Fizzy's multi-tenancy, UUIDs, or dual database support into an ONCE-style app without the requirement. (`14-divergences.md`)
- All source applications track edge Rails; verify edge features against your Rails release before copying them. (`README.md`)
