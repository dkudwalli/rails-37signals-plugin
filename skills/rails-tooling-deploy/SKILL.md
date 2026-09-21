---
name: rails-tooling-deploy
description: This skill should be used when working on Rails project tooling, configuration, CI, containers, deployment, logging, caching policy, or performance — when the user asks to "write bin/setup", "set up CI", "add GitHub Actions", "configure RuboCop", "write a Dockerfile", "deploy with Kamal", "add Redis", "configure the cache store", "add an initializer", "set up logging", "add a health check", or mentions `config/ci.rb`, `config/application.rb`, `production.rb`, Thruster, Solid Cache, or Solid Cable. Provides setup, CI, container, deploy, configuration-lifecycle and operability rules from three 37signals applications.
---

# Tooling, configuration, CI and deploy

The operating model is deliberately ordinary: one setup command, one ordered CI script, one
multi-stage Dockerfile, and as few runtime services as the app needs.

## `bin/setup` is rerunnable

`writebook/bin/setup:8-23` is the preferred baseline:

```bash
announce "Installing dependencies"
gem install bundler --conservative
bundle check || bundle install

announce "Preparing database"
if [[ $* == *--reset* ]]; then
  rails db:reset
else
  rails db:prepare
fi

announce "Removing old logs and tempfiles"
rails log:clear tmp:clear
```

Make normal execution convergent; put destructive work behind `--reset`; use `rails db:prepare`;
start a local service only if the app needs one; seed only an empty database. Grow toward Fizzy's
multi-platform setup only when the supported environments require it.

## CI is an ordered, readable release gate

`fizzy/config/ci.rb:9-35`:

```ruby
CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop -f simple"
  step "Security: Gem audit", "bin/bundler-audit check --update"
  step "Security: Importmap audit", "bin/importmap audit"
  step "Security: Brakeman audit", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gitleaks audit", "bin/gitleaks-audit"
  step "Tests: Setup phases", "test/setup-phases-test"
end
```

One human-readable name and one command per step, in the order a developer would run them: setup,
style, security, tests, signoff. Run system tests serially as their own step. Wrap tools in `bin/` so
local and CI invocations match.

> Edge-Rails note: `config/ci.rb` uses `ActiveSupport::ContinuousIntegration`, which is edge-only.
> On a released Rails, express the same ordered steps in whatever CI runner the app has.

## RuboCop omakase

Inherit `rubocop-rails-omakase`; add a local cop only for a genuine team decision; exclude
`db/migrate/**/*` and `db/schema*.rb` (`fizzy/.rubocop.yml:1-20`).

## A boring multi-stage container

`fizzy/Dockerfile:30-83`: a build stage installs gems, runs `bootsnap precompile`, and precompiles
assets with `SECRET_KEY_BASE_DUMMY=1`; the final stage creates a non-root `rails` user (uid 1000),
copies only runtime files, and runs `./bin/thrust ./bin/rails server`. Never bake a real secret into
the image; strip package-manager and Bundler caches in the build stage.

## Deployment follows the application profile

**Solid Queue, Solid Cache and Solid Cable are one decision; Redis, Resque and resque-pool are one
decision. Pick one family; never mix them.** The Fizzy profile deploys with Kamal + Docker on a
persistent volume and can run Solid Queue inside Puma via `SOLID_QUEUE_IN_PUMA` on a single server;
the ONCE-compatible profile deploys Docker + Procfile processes (web, redis, workers). For a new
self-hosted app with no ONCE compatibility requirement, take the Solid runtime.

The full profile table is in the `rails-profile` skill; run `/rails-37signals:rails-profile` to
choose and record the decision.

Commit `config/deploy.yml`; keep secrets outside Git; declare and back up the storage volume — SQLite
and local Active Storage are product data (`fizzy/config/deploy.yml:17-60`).

## Configuration lifecycle

- `config/application.rb` holds framework defaults, generator defaults and `autoload_lib ignore:`.
  Runtime policy — caching, storage, logging, TLS, queue adapter — goes in the environment file.
- Do not copy another app's `load_defaults` version; match the Rails version actually running.
- One responsibility per initializer, named in its filename and first comment. Extend framework
  classes through `ActiveSupport.on_load` or `to_prepare`, never by relying on load order. Prepend a
  named module per responsibility and call `super` in the non-matching branch.
- Read deployment switches once at the configuration boundary with a safe default; business code does
  not consult `ENV`.
- Populate `Current` once at the request edge in a controller concern
  (`fizzy/app/controllers/concerns/current_request.rb:1-12`). Never use `Current` for data that must
  outlive the request.
- Do not add `config.x` settings for values with one caller.

## Production and operability

- Disable reloading, eager-load, hide detailed errors, enable caching, and log to stdout tagged with
  the request id (`once-campfire/config/environments/production.rb:7-95`).
- Filter secrets, credentials, personal identifiers and user content centrally.
- Add tenant/user context only to error reports, lazily (`fizzy/config/initializers/error_context.rb:1-7`).
- Keep Rails' cheap `/up` health check separate from application traffic.
- Name repeated query shapes and preload graphs as model scopes; use `find_each` or a resumable job for
  unbounded work; put time, byte, batch and retention limits next to the operation they constrain.
- Use fragment/collection caching and `fresh_when` before inventing a cache layer. Version ETags when a
  shared asset changes (`etag { "v1" }`, `stale_when_importmap_changes`).
- Add monitoring infrastructure only when logs, error reports, job visibility and the health check no
  longer answer the operational question.
