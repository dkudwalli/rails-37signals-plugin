---
name: rails-hotwire-javascript
description: This skill should be used when writing JavaScript, Stimulus controllers, Turbo Stream broadcasts, Turbo Frames, morphing, or Action Cable channels in a Rails app — when the user asks to "add a Stimulus controller", "add JavaScript", "make this update live", "add real-time updates", "add a websocket channel", "install an npm package", "add React/Vue", "set up esbuild/webpack/vite", or mentions importmap, `broadcasts_refreshes`, morphing, `Turbo::StreamsChannel`, presence, or typing indicators. Provides no-build importmap rules, Stimulus conventions, Turbo broadcast patterns, and Cable authorization rules from three 37signals applications.
---

# Hotwire and JavaScript

No build step, no `package.json`, no `node_modules` in any of the three apps. JavaScript is ES
modules served to the browser through importmap and Propshaft.

## No bundler

`fizzy/config/importmap.rb:1-20` pins Turbo, Stimulus and a few vendored packages, then
`pin_all_from` each directory.

**Rules:**

- Use `pin_all_from` per directory so a new file is importable with no config change.
- Add a dependency with `bin/importmap pin <pkg>`, producing a readable vendored file. If a
  package needs a build to work, do not use it.
- Run `bin/importmap audit` in CI.
- Keep `application.js` to imports only. Each directory exposes an `index.js` importing its members.

Layout: `controllers/` (one behaviour each), `helpers/` (pure functions, named exports only),
`initializers/` (side effects on load), `lib/` (multi-file or vendored subsystems), `models/`
(stateful client classes, when needed).

If the app ships an installable PWA or a Hotwire Native shell, the rules for the service worker,
the web manifest, push registration and bridge components are in `references/native-and-pwa.md`.
A web-only app does not need them.

## Stimulus conventions

- **One behaviour per controller**, named for the behaviour not the page: `auto_submit`,
  `element_removal`, `local_time`, `copy_to_clipboard`, `toggle_class`. Behaviour-named controllers get
  reused; page-named ones do not.
- **Anonymous default export**: `export default class extends Controller`. The filename is the
  identifier.
- **Public methods are exactly the `data-action` targets; everything else is `#private`**, including
  private getters (`fizzy/app/javascript/controllers/auto_submit_controller.js:1-43`).
- **Instance state in private fields** (`#timer`). Tuning numbers are module-level `const` with numeric
  separators and a unit comment (`const REFRESH_INTERVAL = 3_600_000 // 1 hour`).
- **Every `connect()` that starts something has a `disconnect()` that stops it** — timers, listeners,
  observers (`fizzy/app/javascript/controllers/bubble_controller.js:4-19`).
- **Use `static targets` / `static values`**, with spaced array literals `[ "a", "b" ]`.
- **Use `<name>TargetConnected` / `Disconnected`** for elements that arrive later via Turbo, instead of
  a `MutationObserver`. Bind handlers as arrow-function class fields so `removeEventListener` gets the
  same reference (`fizzy/app/javascript/controllers/lightbox_controller.js:6-17`).
- **Talk to other controllers with `this.dispatch(...)` and outlets**, never by importing them.
- **Set `aria-busy` and `disabled` inside the behaviour** — accessibility belongs in the controller.
- **Prefer the platform**: `<dialog>` + `showModal()`, `animationend` / `transitionend` instead of a
  `setTimeout` matched to a CSS duration, and CSS as the source of truth for interactivity.
- When a controller grows a data structure or algorithm, extract it to `app/javascript/models/` and
  keep the controller as the DOM adapter.

### What that looks like

`fizzy/app/javascript/controllers/auto_submit_controller.js:1-43` in full. `submit` is public
because a `data-action` calls it; everything else is `#private`. Note `aria-busy` handled inside the
behaviour, and no state outside the element:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:submit-end", this.#handleSubmitEnd.bind(this), { once: true })
    this.submit()
  }

  submit() {
    this.#markAsBusy()
    this.#disableSubmit()
    this.element.requestSubmit()
  }

  #handleSubmitEnd(event) {
    if (event.detail.success) {
      this.element.remove()
    } else {
      this.#clearBusy()
      this.#enableSubmit()
    }
  }

  #markAsBusy() {
    this.element.setAttribute("aria-busy", "true")
  }

  #submitElements() {
    return this.element.querySelectorAll("input[type=submit],button")
  }
}
```

A controller that owns an observer shows the paired-teardown and arrow-field rules together
(`fizzy/app/javascript/controllers/bridge/title_controller.js:10-21`, `:52-62`):

```javascript
  async connect() {
    super.connect()
    await nextFrame()
    this.#startObserver()
    window.addEventListener("resize", this.#windowResized)
  }

  disconnect() {
    super.disconnect()
    this.#stopObserver()
    window.removeEventListener("resize", this.#windowResized)
  }

  // Bound as a class field so removeEventListener gets the same reference.
  #windowResized = () => {
    this.#updateObserverIfNeeded()
  }

  get #title() {
    return this.titleValue ? this.titleValue : document.title
  }
```

Every `addEventListener` in `connect` has its `removeEventListener` in `disconnect`, and the
observer is disconnected with `this.observer?.disconnect()`. A controller that starts something and
does not stop it leaks on every Turbo navigation.

## Turbo

- **Prefer `broadcasts_refreshes` plus morphing over hand-written broadcasts**
  (`fizzy/app/models/card/broadcastable.rb:1-18`). Reach for explicit `broadcast_*_to` only to target
  one element in one user's page.
  > Edge-Rails note: `broadcasts_refreshes` with page morphing requires Turbo 8 / a recent
  > turbo-rails. Verify against the target app before using it.
- **`method: :morph` on replaces** preserves focus, scroll and open `<details>`.
- **Broadcast from the model, after commit**, targeting one named DOM region with a server-rendered
  partial (`fizzy/app/models/notification.rb:21-27`).
- Use Turbo Frames for independently updating regions (`turbo_frame_tag :flash`, per-record edit
  frames) and `data-turbo-permanent` for elements that must survive navigation.
- Keep long `data-*` wiring in `*_tag` helpers (see the `rails-views-helpers` skill).

## Action Cable: authenticate, authorize, and revoke

Use a custom channel only for a small real-time protocol a page refresh cannot express — presence,
typing. Channels carry no durable domain writes
(`once-campfire/app/channels/typing_notifications_channel.rb:1-13`).

**Rules:**

- Authenticate in `ApplicationCable::Connection` using the same session lookup as controllers, and
  `reject_unauthorized_connection` otherwise (`once-campfire/app/channels/application_cable/connection.rb:1-19`).
- Scope every stream lookup through the identified actor: `current_user.rooms.find_by(...)`. Never
  stream a client-supplied record id directly.
- **Guard `Turbo::StreamsChannel` too.** It accepts the same signed stream name and performs no
  membership check. A signed name proves the server minted it, not that this subscriber may read it.
  Prepend a rejection onto the framework channel in a `to_prepare` block
  (`once-campfire/app/channels/concerns/room_streams_are_authorized.rb:1-13`).
- **Close live connections when a session ends.** Destroying the session does not close an open
  WebSocket. Call `ActionCable.server.remote_connections.where(current_user: user).disconnect(reconnect: true)`
  on sign-out, and make it best-effort so a Cable outage cannot keep a user signed in
  (`fizzy/app/models/user.rb:39-41`, `once-campfire/app/controllers/concerns/authentication.rb:70-81`).
- Restore tenant context before resolving the actor in a multi-tenant app.
