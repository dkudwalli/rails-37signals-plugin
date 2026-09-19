---
name: rails-controllers-routing
description: This skill should be used when adding or changing Rails routes or controllers — when the user asks to "add an endpoint", "add a close/archive/publish/approve action", "add a custom action", "add a member route", "nest this resource", "write a controller", "strong parameters", "permit params", or mentions `routes.rb`, `before_action`, `respond_to`, `params.expect`, `direct`, `resolve`, or controller concerns. Provides the nouns-as-resources rule, CRUD-only routing, `*Scoped` lookup concerns, and the thin-controller shape from three 37signals applications.
---

# Controllers and routing

The famous rule is "no custom controller actions". It only works because of a prior practice: every
thing a user does gets a noun.

## Rule 0: name states and relationships as nouns

When a verb endpoint is tempting, name the noun that the verb creates or destroys. Then the route,
the model concern and the controller fall out.

| Instead of an action… | …there is a record |
|---|---|
| close / reopen a card | `Closure` (`fizzy/app/models/closure.rb`) |
| mark important | `Card::Goldness` |
| postpone | `Card::NotNow` |
| publish publicly | `Board::Publication` |
| follow / unfollow | `Watch`, `Subscription`, `Involvement` |
| mark as read | `Reading` |
| pin | `Pin` |
| grant access | `Access` |
| ban a user | `Ban` (campfire) |
| save a page revision | `Edit` (writebook) |

A slightly odd noun that names the concept exactly (`Goldness`, `NotNow`) beats an accurate phrase
that cannot be a class. Pair this with the state-as-record pattern in the `rails-models` skill.

## Every endpoint is CRUD on a resource

`fizzy/STYLE.md:138-153`:

```ruby
# Bad
resources :cards do
  post :close
  post :reopen
end

# Good
resources :cards do
  resource :closure
end
```

`POST /cards/5/closure` closes; `DELETE /cards/5/closure` reopens. No `member do` block. See the real
file at `fizzy/config/routes.rb:81-107`.

**Rules:**

- Use singular `resource` for one-per-parent things and plural `resources` for collections. The
  difference is load-bearing: `resource :closure` generates no `:id` segment.
- Use `scope module: :cards` to put controllers in `app/controllers/cards/` without changing the URL
  (`fizzy/config/routes.rb:13-26`).
- Declare `only:` / `except:` on nearly every resource so `rails routes` is a truthful inventory. Use
  `%i[ a b ]` with inner spaces for multiples, a bare symbol for one.
- Nest to express ownership. Three levels is acceptable when ownership really is three levels deep.
- Keep a non-resource route only for an integration, protocol endpoint, permalink/slug, invitation
  token, compatibility redirect, or framework endpoint — and name why. Across three apps there is
  roughly one true custom action (`once-campfire/config/routes.rb:89`, clearing search history).

## Teach the router about models with `direct` and `resolve`

When a path needs derivation, put it in `routes.rb`, not in a helper
(`fizzy/config/routes.rb:218-245`):

```ruby
  resolve "Comment" do |comment, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
    route_for :card, comment.card, options
  end

  resolve "Notification" do |notification, options|
    polymorphic_url(notification.notifiable_target, options)
  end
```

Then `link_to notification.title, notification` works for a heterogeneous list. Use `direct` for
slugged or computed URLs (`writebook/config/routes.rb:42-48`).

## A controller action finds, calls one domain method, responds

`fizzy/app/controllers/cards/goldnesses_controller.rb:1-21`:

```ruby
class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
```

If an action needs a paragraph of logic, the paragraph belongs in the model. The trivial case needs
no model method at all: `@comment = @card.comments.create!(comment_params)`
(`fizzy/STYLE.md:159-167`).

## `*Scoped` concerns for the find-and-authorize preamble

One concern per routing nesting level, holding the lookup, shared rendering and shared bookkeeping
(`fizzy/app/controllers/concerns/board_scoped.rb:1-18`):

```ruby
module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
  end

  private
    def set_board
      @board = Current.user.boards.find(params[:board_id])
    end
end
```

## Authorization is scoping

Look up records through the current actor: `Current.user.accessible_cards.find_by!(...)`. An
inaccessible record raises `RecordNotFound` → 404, so there is no separate check to forget. Add an
explicit `before_action` only for privilege beyond visibility, as a one-liner calling a model
predicate: `head :forbidden unless Current.user.can_administer_card?(@card)`. See the
`rails-auth-security` skill.

## Other controller conventions

- **`ApplicationController` has no method bodies** — only `include` lines of named concerns and
  class-level declarations (`fizzy/app/controllers/application_controller.rb:1-13`).
- **Class-level macros declare the request pipeline**: `allow_unauthenticated_access`,
  `require_unauthenticated_access except: :destroy`, `rate_limit to: 10, within: 3.minutes, only: :create`
  (`fizzy/app/controllers/sessions_controller.rb:1-8`).
- **`params.expect(card: [ :title, :description ])`**, not `require(...).permit(...)`
  (`fizzy/app/controllers/cards_controller.rb:70-72`). `expect` rejects a wrong-shaped request with a
  400 instead of half-succeeding.
  > Divergence: campfire and writebook predate `params.expect` and use `require/permit`. `expect`
  > requires Rails 8+ — check the target app's Rails version before using it.
- **`respond_to` omits `{ render }` for default rendering** (`writebook/AGENTS.md`). Empty actions stay
  empty (`def show; end`) — the `before_action`s did the work.
- **Instance variables are the contract with the view.** No presenter wraps them.
- **Pagination and HTTP caching are one-liners**: `set_page_and_extract_portion_from ...` then
  `fresh_when etag: @page.records` (`fizzy/app/controllers/boards_controller.rb:9-12`).
- **Branch in private methods, not in the action**: `if @filter.used? then show_filtered_cards else show_columns`.
