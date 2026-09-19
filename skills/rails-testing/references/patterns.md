# Test patterns, with code

## Integration test covering access cases

`writebook/test/controllers/books_controller_test.rb:1-42` (excerpt):

```ruby
class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "index lists the current user's books" do
    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook"
    assert_select "h2", text: "Manual", count: 0
  end

  test "index includes published books, even when the user does not have access" do
    books(:manual).update!(published: true)

    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook"
    assert_select "h2", text: "Manual"
  end

  test "index redirects to login if not signed in and no published books exist" do
    sign_out
    get root_url

    assert_redirected_to new_session_url
  end
```

## State change across formats

`fizzy/test/controllers/cards/closures_controller_test.rb:1-35` (excerpt):

```ruby
  test "create" do
    card = cards(:logo)

    assert_changes -> { card.reload.closed? }, from: false, to: true do
      post card_closure_path(card), as: :turbo_stream
      assert_card_container_rerendered(card)
    end
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_not card.closed?

    post card_closure_path(card), as: :json

    assert_response :no_content
    assert card.reload.closed?
  end
```

## Sign-in helper that asserts its postcondition

`writebook/test/test_helpers/session_test_helper.rb:1-16`:

```ruby
module SessionTestHelper
  def sign_in(user)
    user = users(user) unless user.is_a? User
    post session_url, params: { email_address: user.email_address, password: "secret123456" }
    assert cookies[:session_token].present?
  end

  def sign_out
    delete session_url
    assert_not cookies[:session_token].present?
  end
end
```

## Deterministic UUIDv7 fixtures (only if the app uses UUID keys)

Rails derives fixture ids from `crc32(label)`; with UUID keys the order becomes random and
`.first`/`.last` are meaningless. `fizzy/test/test_helper.rb:99-129`:

```ruby
module FixturesTestHelper
  extend ActiveSupport::Concern

  class_methods do
    def identify(label, column_type = :integer)
      if label.to_s.end_with?("_uuid")
        column_type = :uuid
        label = label.to_s.delete_suffix("_uuid")
      end

      # Rails passes :string for varchar columns, so handle both :uuid and :string
      return super(label, column_type) unless column_type.in?([ :uuid, :string ])
      generate_fixture_uuid(label)
    end

    private

    def generate_fixture_uuid(label)
      fixture_int = Zlib.crc32("fixtures/#{label}") % (2**30 - 1)

      # Translate the deterministic order into times in the past, so that records
      # created during test runs are also always newer than the fixtures.
      base_time = Time.utc(2024, 1, 1, 0, 0, 0)
      timestamp = base_time + (fixture_int / 1000.0)

      uuid_v7_with_timestamp(timestamp, label)
    end
```

Installed with (`fizzy/test/test_helper.rb:178-180`):

```ruby
ActiveSupport.on_load(:active_record_fixture_set) do
  prepend(FixturesTestHelper)
end
```

`uuid_v7_with_timestamp` is defined further down the same helper in fizzy; read the source before
copying.

## VCR with secrets filtered and timestamps normalised

`fizzy/test/test_helper.rb:18-43` (excerpt):

```ruby
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<OPEN_AI_KEY>") { Rails.application.credentials.openai_api_key || ENV["OPEN_AI_API_KEY"] }

  # Ignore timestamps in request bodies
  config.before_record do |i|
    if i.request&.body
      i.request.body.gsub!(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/, "<TIME>")
    end
  end
```

## Multi-tenant URL scoping without leaking

`fizzy/test/test_helper.rb:76-79`:

```ruby
class ActionDispatch::IntegrationTest
  setup do
    integration_session.default_url_options = integration_session.default_url_options.merge(script_name: "/#{ActiveRecord::FixtureSet.identify("37signals")}")
  end
```
