# Ruby style, in full

`fizzy/STYLE.md` is the only written style guide across the three repositories. Campfire and
Writebook predate it; where they differ, that is noted.

Baseline: `rubocop-rails-omakase` in all three. This document covers what omakase does not decide.

---

## Rules from STYLE.md

### Expanded conditionals over guard clauses

`fizzy/STYLE.md:10-32`:

```ruby
# Bad
def todos_for_new_group
  ids = params.require(:todolist)[:todo_ids]
  return [] unless ids
  @bucket.recordings.todos.find(ids.split(","))
end

# Good
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end
```

Guard clauses are hard to read, especially when nested. Measured counts of `return if` /
`return unless` in `app/`: fizzy 14 across 11,299 lines; campfire 1 across 3,248; writebook 1 across
1,767.

The idiom that replaces it — assignment inside the condition
(`fizzy/app/controllers/sessions_controller.rb:14-22`):

```ruby
  def create
    if identity = Identity.find_by(email_address: email_address)
      sign_in identity
    elsif Account.accepting_signups?
      sign_up
    else
      redirect_to_fake_session_magic_link email_address
    end
  end
```

`if x = y` with a single `=` is intentional; omakase permits it.

Sanctioned exceptions (`fizzy/STYLE.md:34-37`): when the return is right at the beginning of the
method, and when the main method body is not trivial and involves several lines of code.

### Method order

`fizzy/STYLE.md:51-57`: class methods, then public methods with `initialize` at the top, then
private methods. `fizzy/STYLE.md:59-61`: vertical order follows invocation order, so reading
downward follows execution.

### `!` marks a variant, never destructiveness

`fizzy/STYLE.md:103`: only use `!` for methods that have a counterpart without `!`. `create_closure!`
has one because `create_closure` exists (`fizzy/app/models/card/closeable.rb:35`). `Card#close`
destroys a record and has none.

### Indentation under `private`

`fizzy/STYLE.md:105-124`:

```ruby
class SomeClass
  def some_method
    # ...
  end

  private
    def some_private_method_1
      # ...
    end
end
```

Verified adoption: fizzy 166 of 174 files with a class-level `private`; campfire 54 of 62; writebook
29 of 30. RuboCop's default `Layout/IndentationConsistency` objects to this;
`rubocop-rails-omakase` configures it to expect exactly this. It is the fastest visual tell that
code came from this lineage.

`fizzy/STYLE.md:126-136`: a module with only private methods puts `private` at the top with a blank
line after and no indentation — as in
`writebook/app/models/concerns/authorization.rb:1-10`.

---

## Conventions STYLE.md does not mention

### Whitespace-aligned columns for parallel lines

`fizzy/app/models/card.rb:22-24`:

```ruby
  scope :reverse_chronologically, -> { order created_at:     :desc, id: :desc }
  scope :chronologically,         -> { order created_at:     :asc,  id: :asc  }
  scope :latest,                  -> { order last_active_at: :desc, id: :desc }
```

Align a set of lines that are variations of each other so they read as a table. Do not align
unrelated assignments.

### Subjectless `case` instead of `if/elsif` chains

`once-campfire/app/models/message.rb:31-37`:

```ruby
  def content_type
    case
    when attachment?    then "attachment"
    when sound.present? then "sound"
    else                     "text"
    end.inquiry
  end
```

### `.inquiry` to turn a string into a predicate

`.inquiry` makes `message.content_type.attachment?` work in a view. Also
`writebook/app/models/leafable.rb:18-20` and `authenticated_by.bot_key?` in campfire's
authentication concern.

### Keyword arguments defaulting to `Current`

`fizzy/app/models/card/closeable.rb:31` — `def close(user: Current.user)`. The caller normally omits
it; tests and background jobs pass it explicitly. Same in
`fizzy/app/models/concerns/eventable.rb:8`:

```ruby
  def track_event(action, creator: Current.user, board: self.board, **particulars)
```

Ruby 3.1+ omitted-value hash syntax (`creator:`, `board:`) is used consistently.

### Anonymous block forwarding

`fizzy/app/models/current.rb:21-27`:

```ruby
  def with_account(value, &)
    with(account: value, &)
  end
```

`&` with no name when the block is only passed through.

### `it` in single-argument blocks

`fizzy/app/models/color.rb:9` — `COLORS.find { |it| it.value == value }`. Ruby 3.4's implicit `it`,
used where the block parameter carries no information.

### `Struct` for value objects, `class << self` for class-method groups

`fizzy/app/models/color.rb:1-22`:

```ruby
Color = Struct.new(:name, :value)

class Color
  class << self
    # Finds a Color by its CSS value (e.g. "var(--color-card-4)").
    def for_value(value)
```

Reopen the struct to add behaviour; use `class << self` rather than repeated `def self.`.

### Comments explain why, and flag cross-file coupling

`fizzy/app/javascript/controllers/bubble_controller.js:55`:

```javascript
  // Keep in sync with Card::Stallable#stalled? in app/models/card/stallable.rb
```

`fizzy/app/models/color.rb:14-16`:

```ruby
      # Broken exports serialized Color structs instead of raw CSS values,
      # producing JSON like {"name":"Lime","value":"var(--color-card-4)"}.
      # Parse it and extract the value.
```
