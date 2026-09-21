---
name: rails-views-helpers
description: This skill should be used when writing ERB templates, partials, layouts, view helpers, `.turbo_stream.erb` response templates, fragment caching, or JSON views in Rails — when the user asks to "add a view", "extract a partial", "this template is too long", "add a helper", "add a presenter", "use ViewComponent", "cache this fragment", "add a JSON API response", "add a serializer", or mentions `render collection`, `cache`, `dom_id`, `tag.div`, `html_safe`, or jbuilder. Provides small-partial composition, tag-building helpers, cache-key versioning, and safe escaping rules from three 37signals applications.
---

# Views and helpers

Plain ERB, small partials, and helpers that build tags. No presenters, no view models, no
ViewComponent.

## Partials are small, and there are many

Mean template length is 18 lines in fizzy, 29 in campfire, 23 in writebook. The largest non-layout
template in fizzy is 109 lines. A 300-line template is a structural problem: concepts that deserved
names did not get them.

A template's job is to name and order its children (`fizzy/app/views/cards/_container.html.erb:1-44`
is almost entirely `render` calls).

**Rules:**

- Pass locals explicitly (`card: card`). Do not read instance variables inside partials.
- Put a condition on the `render` line (`<%= render "cards/container/gild", card: card if card.published? %>`)
  rather than wrapping it in an `if` block, when it fits.
- Nest partial directories to mirror composition: `cards/container/`, `cards/display/perma/`.

## Caching

`once-campfire/app/views/messages/index.html.erb:1` is the entire index:
`<%= render partial: "messages/message", collection: @messages, cached: true %>`.

**Rules:**

- Cache at the partial that owns a record, key it on the record, and add every non-record input to
  the key array: `cache [ @books, signed_in? ]` (`writebook/app/views/books/index.html.erb:27`).
- Use `touch: true` on `belongs_to` so outer Russian dolls expire.
- **Version a cached partial's key when its output depends on code the template digestor cannot see**
  — helper Ruby, Action Text rendering, or a partial rendered by a computed name. Add a comment
  saying what bumps it (`once-campfire/app/views/messages/_message.html.erb:1-5`):

  ```erb
  <%# Bump this version when the message presentation filters change what they emit. Editing this line changes the template digest, which busts BOTH this fragment cache and the collection cache that keys on this partial's digest (helper Ruby changes alone don't). %>
  <% cache [ message, "presentation-v3" ] do %>
  ```

  Without it, changing a helper leaves every cached fragment showing the old output.
- Mark a template that must be kept in sync with another with an ERB comment naming the other file.

## Turbo Stream templates are tiny

`once-campfire/app/views/messages/create.turbo_stream.erb:1` is one line:
`<%= turbo_stream.append dom_id(@message.room, :messages), @message %>`. Use `dom_id(record, :suffix)`
for every target (never hand-written ids), `method: :morph` on replace, and `@card.reload` so the
partial sees post-callback state (`fizzy/app/views/cards/update.turbo_stream.erb:1-10`).

## Helpers build tags

The dominant helper shape is a `*_tag` method (`fizzy/app/helpers/cards_helper.rb:2-19`):

```ruby
  def card_article_tag(card, id: dom_id(card, :article), data: {}, **options, &block)
    classes = [
      options.delete(:class),
      ("golden-effect" if card.golden?),
      ("card--postponed" if card.postponed?),
      ("card--active" if card.active?)
    ].compact.join(" ")

    tag.article \
      id: id,
      style: "--card-color: #{card.color}; view-transition-name: #{id}",
      class: classes,
      data: data,
      **options,
      &block
  end
```

**Rules:**

- Use the `tag` builder, never string-interpolated HTML.
- Build conditional classes with `[("x" if cond)].compact.join(" ")` or Rails' `class_names`.
- Accept `**options` and forward `&block` so the helper is a drop-in for `tag.*`.
- Pass Ruby state into CSS as an inline custom property (`--card-color`); derive the rest in CSS.
- **When a `data-controller` / `data-action` / `data-*-value` cluster gets long, move the element into
  a `*_tag` helper** (`once-campfire/app/helpers/messages_helper.rb:2-23`). Templates should not carry
  twelve data attributes.
- One helper module per resource; cross-cutting helpers get their own file rather than swelling
  `ApplicationHelper`. Name methods by return type: `*_tag` returns an element, `*_path`/`*_url` a URL.
- To attach standard behaviour to a family of forms, wrap `form_with` in a helper that *appends* to
  `data[:controller]`, never replaces it (`writebook/app/helpers/forms_helper.rb:1-7`).

## Escaping and sanitising stay in helpers

Call `html_safe` only after an explicit escape or scrub: `ERB::Util.html_escape(...)` first, then the
transformation, then `html_safe` (`fizzy/app/helpers/html_helper.rb:1-11`). Never call `html_safe` on
raw user input.

## Contain per-item render failures

In a long list of user-generated content, rescue inside the per-item helper, report the error, and
render an "unrenderable" partial so one corrupt record does not 500 the page
(`once-campfire/app/helpers/messages_helper.rb:42-47`).

## Layouts, flash, JSON

- Layouts are a skeleton of `render` and `yield`; `<head>` is its own partial; page chrome comes
  through `content_for` and view-assigned instance variables; the skip link is the first focusable
  element (`fizzy/app/views/layouts/application.html.erb:1-42`).
- Wrap flash in `turbo_frame_tag :flash` so a stream can target it, and remove it on `animationend`
  rather than a JS timer (`fizzy/app/views/layouts/shared/_flash.html.erb:1-8`).
- Write JSON as jbuilder templates in the same view directory (`show.json.jbuilder`). No serializer
  classes and no `as_json` overrides on models.

## JSON mirrors the HTML partial tree

The JSON views are built exactly like the HTML ones: a collection template that renders a
per-record partial. `fizzy/app/views/tags/index.json.jbuilder:1` is the whole index:

```ruby
json.array! @page.records, partial: "tags/tag", as: :tag
```

And the partial owns one record (`fizzy/app/views/users/_user.json.jbuilder:1-9`):

```ruby
json.cache! user do
  json.(user, :id, :name, :role, :active)

  json.email_address user.identity&.email_address
  json.created_at user.created_at.utc

  json.url user_url(user)
  json.avatar_url user_avatar_url(user)
end
```

**Rules:**

- **One partial per record, named like the HTML one** (`_user.json.jbuilder` beside `_user.html.erb`),
  and `json.array!` with `partial:`/`as:` for the collection. No `index.json.jbuilder` that loops.
- **Wrap the partial body in `json.cache! record`** — the same Russian-doll caching as the HTML
  views, keyed on the record.
- **Use the terse attribute form** `json.(user, :id, :name)` for plain columns, and a named line
  only where the value is computed or reached through an association.
- **Emit times as UTC explicitly**: `json.created_at user.created_at.utc`. Do not let the response
  depend on the server's zone.
- **Include `_url` fields built from route helpers**, so a client never has to construct a URL.
- **No serializer, presenter or `as_json` override.** If a value needs logic, it is a model method,
  and the template calls it.
- Add a custom Turbo Stream action with a seven-line helper prepended onto
  `Turbo::Streams::TagBuilder` plus a `Turbo.StreamActions` registration in JS
  (`writebook/app/helpers/turbo_stream_actions_helper.rb:1-7`).
