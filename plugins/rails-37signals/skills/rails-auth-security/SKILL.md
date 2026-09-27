---
name: rails-auth-security
description: This skill should be used when implementing authentication, authorization, sessions, API tokens, rate limiting, webhooks, outbound HTTP to user-supplied URLs, file-upload security, HTML sanitising, CSP, or security CI in a Rails app — when the user asks to "add login", "add authentication", "add Devise", "add Pundit", "add roles/permissions", "add magic links", "add API tokens", "add passkeys", "add webhooks", "fetch a URL the user provides", "unfurl links", "prevent SSRF", "allow iframe embeds", or "secure file uploads". Provides session-record auth, authorization-by-scoping, SSRF and Active Storage hardening, and security CI rules from three 37signals applications.
---

# Authentication, authorization and security

No Devise, Pundit, CanCan or OmniAuth. Authentication is a `Session` record plus a signed cookie;
authorization is scoped lookups plus a few model predicates. Roughly 100 lines per app.

## Sessions are records

`once-campfire/app/models/session.rb:1-19` (byte-identical in writebook): `has_secure_token`,
`belongs_to :user`, and a `resume` that updates activity at most once an hour. Users can list and
revoke sessions; signing out is a `DELETE`.

The cookie holds only a token or signed id:
`cookies.signed.permanent[:session_token] = { value: session.token, httponly: true, same_site: :lax }`
(`once-campfire/app/controllers/concerns/authentication.rb:86-88`). Put the lookup in its own tiny
module (`Authentication::SessionLookup`) so Action Cable and Active Storage share it.

## Secure by default; opt out with a named macro

`writebook/app/controllers/concerns/authentication.rb:1-46`. The shape, from Fizzy's version of the
same concern (`fizzy/app/controllers/concerns/authentication.rb:4-30`):

```ruby
  included do
    before_action :require_account # Checking and setting account must happen first
    before_action :require_authentication
    helper_method :authenticated?

    etag { Current.identity.id if authenticated? }
  end

  class_methods do
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
      allow_unauthorized_access **options
    end
  end
```

Every opt-out is a named macro built from `skip_before_action`, declared once here. A controller
never calls `skip_before_action :require_authentication` itself — that is the whole point, because a
named macro is greppable and a scattered skip is not. Note too that `allow_unauthenticated_access`
still runs `resume_session`, so a public page knows who is looking, and the `etag` block keys
caching on the identity so one user's page is never served to another.

- `before_action :require_authentication` is unconditional in `ApplicationController`. A new controller
  is protected because nothing was done.
- Controllers opt out with `allow_unauthenticated_access` — a class macro, not a scattered
  `skip_before_action`. The macro also restores the session, so a public page still knows the user.
- `require_unauthenticated_access` is a distinct macro for sign-in pages.
- `require_authentication` is a chain: `restore_authentication || bot_authentication || request_authentication`.
  Each new credential type is a new `||` branch and its own private method.
- **Record how the request authenticated** (`@authenticated_by = method.to_s.inquiry`) and gate CSRF,
  capabilities and rate limits on it: `protect_from_forgery with: :exception, unless: -> { authenticated_by.bot_key? }`.
  Bearer tokens work only on JSON requests (`fizzy/app/controllers/concerns/authentication.rb:58-74`).

## Authorization is scoping, with predicates for the rest

- Load records through the actor: `Current.user.boards.find(params[:board_id])`. Unreachable → 404.
- Put capability predicates on the model, named `can_<verb>_<noun>?`
  (`fizzy/app/models/user/role.rb:1-32`). Controllers call them in a one-line
  `head :forbidden unless Current.user.can_administer_card?(@card)`.
- Use a string role enum with `scopes: false` and hand-written scopes that also require `active: true`.
  Override `admin?` once (`super || owner?`) instead of `admin? || owner?` at every call site.
- In a multi-tenant app, resolve the tenant **before** authenticating, and require both the account and
  the user to be active (`fizzy/app/controllers/concerns/authorization.rb:1-44`).

## Credentials

- **Magic links**: single use (consume destroys), expiry as a range scope, a code-generation retry loop,
  and a `cleanup` for the schedule (`fizzy/app/models/magic_link.rb:1-43`).
- **Do not leak whether an account exists.** For an unknown email, redirect through an *unsaved* fake
  magic link so the response is indistinguishable (`fizzy/app/controllers/concerns/authentication/via_magic_link.rb:15-23`).
- **Guard development shortcuts at runtime**: an `after_action` that raises outside development if the
  dev-only flash code is present (`via_magic_link.rb:4-13`).
- **API tokens**: `has_secure_token`, a `read`/`write` enum, and `allows?(method)` mapping HTTP verbs
  (`fizzy/app/models/identity/access_token.rb:1-10`).
- Passwords, where used: `has_secure_password`. Normalise emails on the model with `normalizes`.
- **Rate-limit anything that sends mail, issues a credential, or accepts a code**, at the action with
  Rails' `rate_limit to:, within:, only:` — not in the proxy.

## Framework boundaries `ApplicationController` does not cover

These are the non-obvious holes. Details and code are in `references/hardening.md`.

- **Active Storage.** `DirectUploadsController` and `DiskController` inherit from
  `ActiveStorage::BaseController`, not `ApplicationController`, so `require_authentication` never
  runs on them. Authenticate `DirectUploadsController` and `DiskController#update` **even if the app
  never uses direct uploads** — mounting the engine mounts the endpoints. For private content, also
  authorize reads on the blob/representation controllers, and re-append `set_representation` so the
  image/video parser runs *after* authorization.
- **Action Cable.** Authenticate the connection, scope streams through the actor, guard
  `Turbo::StreamsChannel`, and close live connections on sign-out. See the `rails-hotwire-javascript`
  skill.

## Outbound HTTP to user-supplied URLs (SSRF)

Any feature that fetches a user-supplied URL — webhooks, link unfurling, push endpoints — must:

- Resolve DNS itself and **deny by the resolved IP, never the hostname or scheme**.
- **Pin the checked address** (`http.ipaddr = resolved_ip`) so Net::HTTP cannot re-resolve (DNS rebinding).
- Distinguish "did not resolve" from "resolved to a blocked range".
- Share the address policy across apps as a gem once a second app needs it, and keep a local test of
  the addresses the app will never serve (`fizzy/test/models/surfguard_policy_test.rb:1-11`).
- Bound the request: timeouts, max response bytes, classified errors, HMAC signature, persisted
  delivery record enqueued after commit (`fizzy/app/models/webhook/delivery.rb:1-129`).

## Configuration hardening and CI

- Filter personal data and user content in logs, not only secrets (`:email`, `"message.body"` —
  `once-campfire/config/initializers/filter_parameter_logging.rb:6-8`).
- Configure CSP, give inline scripts `nonce: true`, and put `csp_meta_tag` in `<head>`.
- `allow_browser versions: :modern`.
- When allowing third-party embeds, drive both the sanitiser and the CSP `frame-src` from one table,
  match host *and* path, cap permitted attributes in code, and version the policy so cached fragments
  re-scrub (`writebook/app/models/embed_provider.rb:1-24`).
- Run on every CI build, failing on warnings: `bundler-audit`, `importmap audit`, `brakeman
  --exit-on-warn`, and a secret scanner. Triage Brakeman in a checked-in `config/brakeman.ignore`
  (`fizzy/config/ci.rb:9-35`).

## Additional resources

- **`references/hardening.md`** — verbatim code for the Active Storage authentication and
  authorization concerns, the `Turbo::StreamsChannel` guard, session-end disconnect, the SSRF shim,
  and the embed allowlist.
