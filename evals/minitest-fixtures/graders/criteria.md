---
type: llm
weight: 1
---

The response must use Minitest with fixtures, the Rails default.

PASS if:
- Tests are Minitest (`class SubscriptionTest < ActiveSupport::TestCase`, `test "..." do`, or
  `def test_...`), and test data comes from fixtures (`subscriptions(:one)`) or plain
  `Model.create!` in the test body.

FAIL if:
- The response writes RSpec (`RSpec.describe`, `it "..."`, `expect(...).to`, `let(...)`).
- The response uses FactoryBot (`create(:subscription)`, `build(:subscription)`, `factory :x do`)
  or proposes adding either gem.
- The response asks which framework to use instead of writing tests, without writing Minitest.
