---
name: rails-data-search
description: This skill should be used when writing migrations, designing schema, adding indexes or constraints, choosing a database, adding search, or working with Active Storage and Action Text in Rails — when the user asks to "add a migration", "add a column", "add a unique constraint", "should I use Postgres", "add full-text search", "add Elasticsearch", "use UUIDs", "add file uploads", "store attachments on S3", "add an export/import", or mentions SQLite, FTS5, `has_one_attached`, `has_rich_text`, `storage.yml`, or `sanitize_sql`. Provides schema and migration conventions, in-database search patterns, and storage/portability rules from three 37signals applications.
---

# Data, search and storage

SQLite in production, search in the database, and attachments as domain content.

## SQLite is a production database

Campfire and Writebook ship SQLite only. Fizzy supports SQLite or MySQL (Trilogy) selected by
`DATABASE_ADAPTER`, with a committed schema for each. No database server to install, back up or
upgrade — the "deployable by one person" constraint. Start with SQLite and add a server only for a
real deployment or query need.

## Schema conventions

From `fizzy/db/schema.rb:13-26` and `writebook/db/schema.rb:14-23`:

- `null: false` on everything not genuinely optional, including timestamps.
- String enums with a database default: `t.string "involvement", default: "access_only", null: false`.
- **Put unconditional uniqueness and integrity in a database index or constraint, not only a
  validation**: `t.index ["board_id", "user_id"], unique: true`.
- `utf8mb4` with `_0900_ai_ci` collation on MySQL.

A trick worth stealing — a database-enforced singleton
(`once-campfire/db/migrate/20251212154340_add_singleton_constraint_to_accounts.rb`):

```ruby
    add_column :accounts, :singleton_guard, :integer, default: 0, null: false
    add_index :accounts, :singleton_guard, unique: true
```

## Migrations are single-purpose and tiny

One concern per migration, a descriptive class name, `change` only
(`fizzy/db/migrate/20260709120000_add_account_board_status_index_to_cards.rb` is one `add_index`).
Exclude `db/migrate` and `db/schema*.rb` from RuboCop.

## Identifiers

Integer keys by default. Fizzy uses UUIDv7 (binary, base36 in Ruby) because it is multi-tenant —
and that costs a 124-line initializer (`fizzy/config/initializers/uuid_primary_keys.rb`) plus
deterministic fixture UUIDs.

> Divergence: adopt UUIDv7 only as a package — keys, fixtures, `id` tie-breakers and account context
> together. Do not add UUIDs to an ONCE-style app without the requirement. UUIDv7 support is an
> edge-Rails area; verify against the target Rails version.

For per-tenant sequential numbers on a UUID model, increment a counter under a lock:
`account.with_lock { account.increment!(:cards_count).cards_count }` (`fizzy/app/models/card.rb:92-94`).

## Full-text search runs in the database

No Elasticsearch, OpenSearch, pg_search or search gem. Use the database's FTS (SQLite FTS5, MySQL
`MATCH ... AGAINST`) behind a `Searchable` concern maintained by `after_*_commit` callbacks
(`fizzy/app/models/concerns/searchable.rb`). Return `none` for an invalid query, never `nil` or an
error.

**Build the query from an allowlist of tokens; do not blocklist operators.** Stripping bad characters
is not enough — `AND`, `OR`, `NOT`, `NEAR` survive as bare words and parse as FTS5 syntax. Re-emit
every token as a quoted literal (`writebook/app/models/leaf/searchable.rb:122-127`):

```ruby
        def quote_query_tokens(terms)
          terms.scan(/"[^"]*"|\w+/)
            .filter_map { |token| token.delete('"').presence }
            .map { |token| %("#{token}") }
            .join(" ")
        end
```

Also: bind every value with `sanitize_sql([...])`, never interpolate; use `Arel.sql` only around a
literal; select `highlight()` / `snippet()` / `bm25()` as SQL attributes rather than excerpting in
Ruby. In a multi-tenant FTS, put the tenant into the full-text query itself, not only the `WHERE`
(`fizzy/app/models/search/record/trilogy.rb:1-38`).

## Attachments and rich text are domain content

- Declare `has_one_attached :image, dependent: :purge_later` and `has_rich_text` on the owning model.
- **Treat attachments as protected content: authorize every Active Storage serving path.** An opaque
  blob URL is not authorization. Details and the framework-controller trap are in the
  `rails-auth-security` skill.
- Store on local disk by default and make cloud storage a deploy-time choice via an env var
  (`fizzy/config/environments/production.rb:57-61`). Require `aws-sdk-s3` lazily. Keep credentials
  out of `storage.yml`.
  > Divergence: writebook's `local` service is `public: true` because its content is public by
  > design. Never inherit that into an app whose content is private — public blob URLs are unsigned
  > and permanent.
- Model export and import as persisted resources with a state machine
  (`pending`/`processing`/`completed`/`failed`), a job, and completion mail — not a long request
  (`fizzy/app/models/account/import.rb:1-79`). Add portability only when users must migrate data.

## Seeds

Seeds are real code in `db/seeds.rb` + `db/seeds/`, run by `bin/setup` only when the database is empty.
