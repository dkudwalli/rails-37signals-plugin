---
name: rails-testing
description: This skill should be used when writing or changing tests in a Rails app — when the user asks to "write a test", "add tests for this", "add a controller test", "add a system test", "add RSpec", "add FactoryBot", "create a factory", "add fixtures", "stub an HTTP call", "fix a flaky test", or mentions Minitest, fixtures, `assert_changes`, `assert_select`, integration tests, Capybara, WebMock, VCR, or parallel tests. Provides the Minitest-plus-fixtures approach, integration-test style, custom assertion helpers, and system-test rules from three 37signals applications.
---

# Testing

Minitest and fixtures. No RSpec, FactoryBot, shoulda, `let`, `describe`, or shared examples. `test/`
mirrors `app/`, plus `test_helpers/`, `fixtures/`, `application_system_test_case.rb` and
`test_helper.rb`. No `spec/`, `support/` or `factories/`.

## Global setup is for process state only

Baseline (`writebook/test/test_helper.rb:1-15`): `parallelize(workers: :number_of_processors)`,
`fixtures :all`, and shared helper modules included on `ActiveSupport::TestCase`.

**Rule: global `setup` / `teardown` resets process-level state** — pubsub, connection pools, HTTP
stubs (`once-campfire/test/test_helper.rb:12-37`) — **never test data.** Data comes from fixtures or
the test body.

Enforce production invariants in the harness. Fizzy blanks the ambient account inside
`perform_enqueued_jobs` so a job that forgot to serialize its context fails in tests
(`fizzy/test/test_helper.rb:56-72`):

```ruby
    def perform_enqueued_jobs(...)
      saved_account = Current.account
      Current.account = nil
      super
    ensure
      Current.account = saved_account
    end
```

## Fixtures, not factories

**Rules:**

- Reach for an existing fixture first (`writebook/AGENTS.md`). Add one only when no existing fixture
  expresses the case.
- Mutate a fixture in the test for a variant: `books(:manual).update!(published: true)`.
- Name fixtures with domain words that describe their role (`handbook`, `manual`), not `user_1`.
- Choose fixtures already in the right starting state — `cards(:logo)` is open, `cards(:shipping)`
  is closed — so the test does not set up before it acts.
- With UUID primary keys, install deterministic fixture UUIDs that sort like integer ids and sit in
  the past. See `references/patterns.md`.

## Test style

- `test "sentence describing behaviour" do`, not `def test_x`. No `describe`/`context` nesting, no
  arrange/act/assert comments.
- Controller tests are `ActionDispatch::IntegrationTest` — real requests through the full stack,
  never `ActionController::TestCase` or assigns.
- **Assert the visible outcome**: `assert_response`, `assert_select`, `assert_redirected_to`,
  `assert_in_body` / `assert_not_in_body` for non-HTML bodies.
- **Assert the negative**: `assert_select "h2", text: "Manual", count: 0` for the record the user must
  not see. Cover signed-in, signed-out, and no-access cases.
- **Assert the state change with both endpoints**: `assert_changes -> { card.reload.closed? }, from: false, to: true`.
  Use `assert_difference -> { Book.count }, +1` for counts.
- Exercise every format the controller declares: `as: :turbo_stream` and `as: :json` are separate tests.
- Use `_path` helpers in request tests unless crossing hosts (`writebook/AGENTS.md`).
- `reload` a record the request touched before asserting on it.

## Custom assertions live in `test_helpers/`

When an assertion appears in three tests, name it in a `*TestHelper` module
(`fizzy/test/test_helpers/card_test_helper.rb:1-5`):

```ruby
module CardTestHelper
  def assert_card_container_rerendered(card)
    assert_turbo_stream action: :replace, target: dom_id(card, :card_container)
  end
end
```

`sign_in` authenticates through the real endpoint, accepts a symbol or record, and asserts its own
postcondition (`writebook/test/test_helpers/session_test_helper.rb:1-16`).

## System tests: few, real browser, serial

Write system tests only for interactions that need a browser — Turbo Streams arriving, unread state
updating — not CRUD an integration test covers. Campfire has three. Configure the driver explicitly
and comment each non-obvious Chrome flag with the flake it prevents
(`fizzy/test/application_system_test_case.rb:4-30`). **Run system tests serially**
(`PARALLEL_WORKERS=1`) as a separate CI step (`fizzy/config/ci.rb:5-7`, `fizzy/config/ci.rb:28-29`).

## External HTTP and mocking

- Disable outbound HTTP globally with WebMock and reset in teardown, so an unstubbed call fails loudly.
- Record with VCR only where the boundary matters; `filter_sensitive_data` for keys and a matcher that
  normalises timestamps (`fizzy/test/test_helper.rb:18-43`).
- Mocking (`mocha`) is available but rare — at process boundaries (mail, HTTP, push), never to isolate
  one model from another.

## Parallel from day one

`parallelize workers: :number_of_processors` forces isolation early, when fixing it is cheap. Never
mutate a shared hash such as `default_url_options` in `setup`; assign a merged copy
(`fizzy/test/test_helper.rb:76-79`).

## What else gets a test

The routes table (`routes_test.rb`), middleware, helpers, jobs with the context guard above, and
`bin/setup` itself (`test/setup-phases-test`). If a security policy moved into a shared gem, keep a
local test of the app's own non-negotiables. Add one focused test for new non-trivial logic; do not
scaffold a framework around it.

## Additional resources

- **`references/patterns.md`** — integration test covering access cases, state change across
  formats, the sign-in helper, the deterministic UUID fixture helper, the VCR configuration, and
  multi-tenant URL scoping in tests.
