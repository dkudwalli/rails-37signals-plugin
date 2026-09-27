# Model patterns in detail

## `delegated_type` for a heterogeneous collection

`writebook/app/models/leaf.rb:1-16`:

```ruby
class Leaf < ApplicationRecord
  include Editable, Positionable, Searchable

  belongs_to :book, touch: true
  delegated_type :leafable, types: Leafable::TYPES, dependent: :destroy
  positioned_within :book, association: :leaves, filter: :active

  delegate :searchable_content, to: :leafable

  enum :status, %w[ active trashed ].index_by(&:itself), default: :active

  scope :with_leafables, -> { includes(:leafable) }
end
```

The counterpart concern, `writebook/app/models/leafable.rb:1-25`, declares the paired associations
and a default `searchable_content` the types override:

```ruby
module Leafable
  extend ActiveSupport::Concern

  TYPES = %w[ Page Section Picture ]

  included do
    has_one :leaf, as: :leafable, inverse_of: :leafable, touch: true
    has_one :book, through: :leaf

    delegate :title, to: :leaf
  end

  def searchable_content
    nil
  end
```

`Leaf` holds position, status and title; `Page`/`Section`/`Picture` hold their own content.

> Divergence: campfire uses STI for `Rooms::Open`/`Closed`/`Direct`
> (`once-campfire/app/models/room.rb:25-28`); writebook and fizzy prefer `delegated_type` and
> `has_one` state records. Prefer the newer approach unless the subtypes genuinely share every
> column.

## Enums use the hash-from-array idiom

```ruby
enum :status, %w[ drafted published ].index_by(&:itself)                                  # fizzy/app/models/card/statuses.rb:5
enum :status, %w[ active trashed ].index_by(&:itself), default: :active                    # writebook/app/models/leaf.rb:10
enum :theme, %w[ black blue green magenta orange violet white ].index_by(&:itself), suffix: true, default: :blue  # writebook/app/models/book.rb:10
```

String-backed enums keep the database column readable, and adding a value renumbers nothing.

## Association extensions instead of a manager object

`once-campfire/app/models/room.rb:1-18`:

```ruby
class Room < ApplicationRecord
  has_many :memberships, dependent: :delete_all do
    def grant_to(users)
      room = proxy_association.owner
      Membership.insert_all(Array(users).collect { |user| { room_id: room.id, user_id: user.id, involvement: room.default_involvement } })
    end

    def revoke_from(users)
      destroy_by user: users
    end

    def revise(granted: [], revoked: [])
      transaction do
        grant_to(granted) if granted.present?
        revoke_from(revoked) if revoked.present?
      end
    end
  end
```

Called as `room.memberships.revise(granted: …, revoked: …)`. Fizzy uses the same call shape:
`@board.accesses.revise granted: grantees, revoked: revokees`
(`fizzy/app/controllers/boards_controller.rb:43`).

## `class << self` for class-level constructors

`once-campfire/app/models/room.rb:32-44`:

```ruby
  class << self
    def create_for(attributes, users:)
      transaction do
        create!(attributes).tap do |room|
          room.memberships.grant_to users
        end
      end
    end

    def original
      order(:created_at).first
    end
  end
```

A creation that has to do more than `create!` becomes a named class method, not a service object.

## Class-level macros to configure a concern per model

`writebook/app/models/concerns/positionable.rb:17-32` defines a macro the including model calls with
its own parameters:

```ruby
  class_methods do
    def positioned_within(parent, association:, filter:)
      define_method :positioning_parent do
        send(parent)
      end

      define_method :all_positioned_siblings do
        positioning_parent.send(association).send(filter).positioned
      end

      define_method :other_positioned_siblings do
        all_positioned_siblings.excluding(self)
      end

      private :positioning_parent, :all_positioned_siblings, :other_positioned_siblings
    end
  end
```

Used as `positioned_within :book, association: :leaves, filter: :active`. This is the Rails-native
alternative to passing an options hash into `include`.

## Hooks with default no-op implementations

`fizzy/app/models/concerns/eventable.rb:1-25` exposes `should_track_event?` and `event_was_created`
with default implementations meant to be overridden. That is how a shared concern stays configurable
without an options hash.

## Document a shared concern's contract

When a shared concern requires methods from its includers, list them in a comment at the bottom of
the concern (`fizzy/app/models/concerns/searchable.rb:56-62`):

```ruby
  # Models must implement these methods:
  # - account_id: returns the account id
  # - search_title: returns title string or nil
  # - search_content: returns content string
  # - searchable?: returns whether this record should be indexed
```

## Defaulted `belongs_to` instead of controller assignment

```ruby
belongs_to :account, default: -> { board.account }               # fizzy/app/models/card.rb:6
belongs_to :creator, class_name: "User", default: -> { Current.user }   # fizzy/app/models/card.rb:8
belongs_to :account, default: -> { creator.account }              # fizzy/app/models/board.rb:5
```

Ownership and tenancy are derived by the model. A controller never writes `creator: Current.user` —
and because it never does, it cannot forget to.

## Normalisation and validation belong on the model

`fizzy/app/models/identity.rb:1-40`:

```ruby
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }
```

Use the stdlib regexp rather than a hand-rolled one. Declare normalisation on the model so no
controller has to remember to downcase. Use `before_destroy :something, prepend: true` when a
callback must run before `dependent:` teardown.
