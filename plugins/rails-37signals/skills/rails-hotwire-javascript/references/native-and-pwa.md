# Native shell and PWA

Load this when the app ships an installable PWA or a Hotwire Native shell. A web-only app
needs none of it.

## The PWA is two ERB templates

All three apps ship an installable PWA, and all three do it the same way: templates in
`app/views/pwa/` rendered by ordinary routes. No build step, no PWA gem, no framework
(`fizzy/config/routes.rb:255-256`):

```ruby
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"
```

**Rules:**

- **`manifest.json.erb` is a template, so use Rails in it** — environment-aware naming and real path
  helpers, not hardcoded strings (`fizzy/app/views/pwa/manifest.json.erb:2`, `:26-31`):

  ```erb
  "name": <%= [ "Fizzy", Rails.env.production? ? nil : Rails.env ].compact.join(" - ").to_json.html_safe %>,
  ```

  Shortcuts point at `notifications_path`, not `"/notifications"`.
- **The service worker declares caching rules, it does not contain caching logic**
  (`fizzy/app/views/pwa/service_worker.js.erb:6-25`). Each rule is a matcher plus a named handler:
  `networkFirst` for documents, `cacheFirst` for digested assets, with `maxAge` and `maxEntrySize`.
  Comment the workarounds — the Safari `cache: "no-cache"` note at `:3-5` is why the next person
  does not delete it.
- **Never cache a mutating path.** Every document rule carries `except: /\/(edit|pin|watch|new)$/`.
- **Register the worker from a Stimulus controller, on user action, not at boot**
  (`fizzy/app/javascript/controllers/notifications_controller.js:57-60`). Feature-detect first:
  `navigator.serviceWorker && window.Notification` (`:49-51`).
- **Roll back the client if the server rejects the subscription**
  (`fizzy/app/javascript/controllers/notifications_controller.js:69-77`) — on a non-OK response,
  call `subscription.unsubscribe()` rather than leaving the browser subscribed to a push the server
  will never send. This is the client half of the server-side rules in `rails-jobs-async`.
- Where installation needs explaining, that is just a partial
  (`once-campfire/app/views/pwa/_install_instructions.html.erb`), not a library.

## Hotwire Native: the bridge is progressive enhancement

Fizzy serves the same HTML to the web and to its native iOS and Android apps. There is no separate
mobile view tree and no API — the native shell wraps the web app, and *bridge components* let the
page drive native UI. Campfire and Writebook have no bridge; this is Fizzy-only.

The server tells the page what the client can do
(`fizzy/app/views/layouts/application.html.erb:9-12`):

```erb
    data-platform="<%= platform.type %>"
    data-bridge-platform="<%= platform.bridge_name %>"
    data-bridge-components="<%= platform.bridge_components %>"
```

`platform` is an ordinary model, not a helper full of `request.user_agent` checks
(`fizzy/app/models/application_platform.rb:46-55`):

```ruby
  def bridge_name
    case
    when native? && android? then :android
    when native? && ios?     then :ios
    end
  end

  def bridge_components
    extract_list_from_native_user_agent("bridge-components")
  end
```

**Rules:**

- **A bridge component is a Stimulus controller** that extends `BridgeComponent` and declares
  `static component = "<name>"` (`fizzy/app/javascript/controllers/bridge/title_controller.js:5-8`).
  All the ordinary Stimulus rules still apply — one behaviour, `#private` methods, paired
  `connect`/`disconnect`.
- **Call `super.connect()` and `super.disconnect()` first.** `BridgeComponent` has its own
  registration lifecycle; skipping the call leaves the component unregistered on the native side.
- **Keep them in their own namespace**, `app/javascript/controllers/bridge/`, referenced in markup as
  `bridge--title`, `bridge--buttons`. The namespace is what makes them easy to ignore on the web.
- **Send data to the native side with `this.send(...)`** and nothing else
  (`fizzy/app/javascript/controllers/bridge/title_controller.js:23-25`). The page never assumes a
  native client is listening.
- **Degrade silently.** `bridge_name` returns `nil` on the web, the bridge components do nothing,
  and the same markup renders as an ordinary page. Never branch the template on "is this native".
- Extend the bridge's own element API by prototype patch in one initializer rather than subclassing
  per component (`fizzy/app/javascript/initializers/bridge/bridge_element.js:3-11`).

Do not reach for this unless the app actually ships a native shell. For a web-only app the whole
section is dead weight.

