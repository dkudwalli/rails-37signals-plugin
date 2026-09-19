---
name: rails-models
description: This skill should be used when creating or changing an Active Record model, a model concern, or domain logic in a Rails app — when the user asks to "add a model", "add a boolean column", "mark something as done/published/archived", "this model is getting too big", "split this model", "add a scope", "add a callback", "fix N+1 queries", "add includes/preload", "where do I put this method", or mentions `delegated_type`, `Current`, `ActiveSupport::CurrentAttributes`, STI, enums, or association extensions. Provides the namespaced-concern idiom, the state-as-record pattern, and scope and callback conventions from three 37signals applications.
---

# Models

"Rich domain model" usually produces a 2,000-line `User`. These apps keep models rich *and* readable
with one rule: one class per concept, and concepts split into concerns namespaced under the model.

## The class body is a table of contents

`fizzy/app/models/card.rb:1-13` — `Card` is the most feature-laden model in the three apps and its
file is 95 lines:

```ruby
class Card < ApplicationRecord
  include Accessible, Assignable, Attachments, Broadcastable, Closeable, Colored, Commentable,
    Entropic, Eventable, Exportable, Golden, Mentions, Multistep, Pinnable, Postponable, Promptable,
    Readable, Searchable, Stallable, Statuses, Storage::Tracked, Taggable, Triageable, Watchable

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :reactions, -> { order(:created_at) }, as: :reactable, dependent: :delete_all
  has_one_attached :image, dependent: :purge_later

  has_rich_text :description
```

**Rules:**

- Use one `include` listing concerns alphabetically. Add a second `include` only to express load
  order, with a comment saying why (`fizzy/app/models/user.rb:1-4`: `include Timelined # Depends on Accessor`).
- Keep in the class body: associations, `has_rich_text` / `has_one_attached`, validations, the scopes
  that order the base relation, and the two or three methods belonging to no feature.
- Move everything that is a *feature* into a concern.

## Concerns are namespaced under the model

`fizzy/app/models/card/closeable.rb` defines `module Card::Closeable`, not `module Closeable`.

**Rule: a concern goes in `app/models/<model>/` unless two models include it. Then, and only then,
promote it to `app/models/concerns/`.** In fizzy, `app/models/concerns/` holds only six files — the
ones included by more than one model. This is what lets `Card` and `Comment` both have a
`Searchable` without colliding.

## A concern is a vertical slice

A concern owns its association, its scopes, its predicates and its verbs. Everything about closing a
card lives in `fizzy/app/models/card/closeable.rb:1-48`:

```ruby
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }
  end

  def closed?
    closure.present?
  end

  def close(user: Current.user)
    unless closed?
      transaction do
        not_now&.destroy
        create_closure! user: user
        track_event :closed, creator: user
      end
    end
  end
end
```

**Rule: if `has_one :closure` sits in the class body while the behaviour sits in a concern, the
feature has been split in two.**

## Represent a state as a record, not a boolean column

This is the practice everything else hangs off. Instead of a `cards.closed_at` column there is a
`Closure` record (`fizzy/app/models/closure.rb:1-5`, four lines).

What those four lines buy: *who* and *when* for free (`closed_by`, `closed_at` become reads);
scopes that are joins (`joins(:closure)`, `where.missing(:closure)` — no null handling); and a URL,
because `Closure` is a resource, so closing is `POST /cards/:id/closure` and reopening is `DELETE`.

**Rule: when a boolean or timestamp column would need "who did it", "when", or an endpoint, make it
a record with a `has_one`.** The predicate becomes `closure.present?` and the verb becomes
`create_closure!`. The same shape appears as `Card::NotNow`, `Board::Publication`, `Pin`, `Watch`,
`Access`, `Boost`, `Ban`, `Edit`.

## Verb methods are idempotent and transactional

`fizzy/app/models/card/golden.rb:15-21` is the minimal form: `create_goldness! unless golden?` and
`goldness&.destroy`. Named as domain verbs (`gild`/`ungild`), not `set_golden`. Where more than one
write is involved, wrap the body in `transaction`.

## Scope conventions

- **Ordering scopes are adverbs**: `chronologically`, `reverse_chronologically`, `alphabetically`,
  `ordered`, `positioned`.
- **Always break timestamp ties with `id`** — every ordering scope orders by a timestamp *and* `id`
  (`fizzy/app/models/card.rb:22-24`).
- **Preloading is a named scope, not caller-side `includes`.** Declare `with_users` and `preloaded`
  once beside the associations and reuse them from every controller; that is how N+1 fixes stay
  fixed (`fizzy/app/models/card.rb:25-26`).
- **Parameterised dispatch scopes replace controller conditionals** — `Card.indexed_by(index)` and
  `Card.sorted_by(sort)` map a URL param to a scope with a `case`
  (`fizzy/app/models/card.rb:28-48`).

## Callbacks

`fizzy/app/models/card.rb:15-20`:

- Inline lambda when the body is one expression; a private method name when it is not.
- Always `if:` — callbacks are conditional by default here.
- Anything slow or networked is enqueued, not run inline. See the `rails-jobs-async` skill.
- Use `after_create_commit`, not `after_create`, when the work must see committed data.

## `Current` for request context

Override the writer to derive dependent attributes so callers set one thing
(`fizzy/app/models/current.rb:1-27` — setting `Current.session` cascades to `identity` then `user`).
Use `Current` as the *default* for keyword arguments in models so tests and jobs can pass explicitly.
Provide `with_*` wrappers (`Current.with_account(value, &)`) for scoped execution rather than
assigning and restoring by hand.

## `ApplicationRecord` stays nearly empty

`writebook/app/models/application_record.rb` is three lines. Fizzy's adds exactly one. The base
class is not a dumping ground for helpers.

## Additional resources

- **`references/patterns.md`** — `delegated_type` vs STI, enum idiom, association extensions,
  `class << self` constructors, class-level macros to configure a concern per model, and the
  shared-concern contract comment convention, hooks with default no-op implementations, defaulted
  `belongs_to` instead of controller assignment, and normalisation/validation placement.
