# Security hardening, with code

## Active Storage write endpoints (all apps should do this)

`ActiveStorage::DirectUploadsController` and `ActiveStorage::DiskController` inherit from
`ActiveStorage::BaseController`, **not** `ApplicationController`. Campfire and writebook close this
with an identical concern and initializer.

`once-campfire/app/controllers/concerns/active_storage_authentication.rb:1-9`:

```ruby
module ActiveStorageAuthentication
  extend ActiveSupport::Concern
  include Authentication::SessionLookup

  private
    def require_active_storage_authentication
      head :unauthorized unless find_session_by_cookie
    end
end
```

`once-campfire/config/initializers/active_storage_authentication.rb:1-15`:

```ruby
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.include ActiveStorageAuthentication
  ActiveStorage::DirectUploadsController.before_action :require_active_storage_authentication

  ActiveStorage::DiskController.include ActiveStorageAuthentication
  ActiveStorage::DiskController.before_action :require_active_storage_authentication, only: :update
end
```

`only: :update` gates the PUT that writes bytes; the GET that serves them keeps its signed-URL
semantics.

## Active Storage read authorization (private-by-default apps)

`fizzy/lib/rails_ext/active_storage_authorization.rb:74-107`:

```ruby
Rails.application.config.to_prepare do
  module ActiveStorage::Authorize
    extend ActiveSupport::Concern

    include Authentication

    included do
      # Ensure require_authentication runs after set_blob.
      skip_before_action :require_authentication
      before_action :require_authentication, :ensure_accessible, unless: :publicly_accessible_blob?
    end

    private
      def ensure_accessible
        unless @blob.accessible_to?(Current.user)
          head :forbidden
        end
      end
  end

  ActiveStorage::Blobs::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Blobs::ProxyController.include ActiveStorage::Authorize
```

Callback order is part of the policy. `set_representation` runs the libvips/ffmpeg/mutool parser and
is registered on the parent class, so it would run before the appended authorization. Re-append it
(`fizzy/lib/rails_ext/active_storage_authorization.rb:109-119`):

```ruby
  [ ActiveStorage::Representations::RedirectController, ActiveStorage::Representations::ProxyController ].each do |controller|
    controller.include ActiveStorage::Authorize
    controller.skip_before_action :set_representation
    controller.before_action :set_representation
  end
```

> Divergence: fizzy authorizes reads per tenant because its content is private; campfire and
> writebook only authenticate writes because their served content is public or signed. A
> private-by-default app should start with fizzy's model.

## Guarding `Turbo::StreamsChannel`

`once-campfire/app/channels/concerns/room_streams_are_authorized.rb:1-13`:

```ruby
# Prepended onto Turbo::StreamsChannel. The subscriber names the channel it wants, so
# authorizing room messages only in RoomMessagesChannel would leave the stock channel as
# a way around it: same signed stream name, no membership check. Turn those names away
# here and RoomMessagesChannel becomes the only door.
module RoomStreamsAreAuthorized
  def subscribed
    if RoomMessagesChannel.guarded_stream?(verified_stream_name_from_params)
      reject
    else
      super
    end
  end
end
```

Wired in `once-campfire/config/initializers/turbo_streams_authorization.rb:1-3`:

```ruby
Rails.application.config.to_prepare do
  Turbo::StreamsChannel.prepend RoomStreamsAreAuthorized
end
```

## Closing live connections at sign-out

`fizzy/app/controllers/concerns/authentication.rb:107-111`:

```ruby
    def terminate_session
      Current.session.destroy
      Current.identity&.close_remote_connections(reconnect: true)
      cookies.delete(:session_token)
    end
```

`fizzy/app/models/user.rb:39-41`:

```ruby
  def close_remote_connections(reconnect: false)
    ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect:)
  end
```

Campfire makes it best-effort (`once-campfire/app/controllers/concerns/authentication.rb:70-81`):

```ruby
    def disconnect_remote_connections
      Current.user&.reset_remote_connections
    rescue => error
      Rails.logger.warn "Could not disconnect remote connections on sign out: #{error.class}"
    end
```

`reconnect: true` sends the client back through `Connection#connect` with no valid cookie, so it
fails closed onto the sign-in page.

## SSRF: resolve, check, pin

`fizzy/app/models/webhook/delivery.rb:100-111`:

```ruby
    def resolved_ip
      return @resolved_ip if defined?(@resolved_ip)
      @resolved_ip = Surfguard.resolve_public_ips(uri.host).first
    end
```

```ruby
        http.ipaddr = resolved_ip
```

`surfguard` is a 37signals-internal gem (`fizzy/Gemfile:41`). Outside 37signals, implement the same
contract: resolve with `Resolv`, reject loopback, RFC1918, link-local, IPv4-mapped IPv6, cloud
metadata and other special-use ranges, then connect to the checked address. Keep an app-level test
of the addresses the app will never serve (`fizzy/test/models/surfguard_policy_test.rb:1-11`).

Bounded delivery (`fizzy/app/models/webhook/delivery.rb:4-9, 68-88`):

```ruby
  ENDPOINT_TIMEOUT = 7.seconds
  MAX_RESPONSE_SIZE = 100.kilobytes
```

```ruby
    rescue ResponseTooLarge
      { error: :response_too_large }
    rescue Surfguard::Unresolvable, Resolv::ResolvTimeout, Resolv::ResolvError, SocketError
      { error: :dns_lookup_failed }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT
      { error: :connection_timeout }
```

## Embed allowlist driving sanitiser and CSP

`writebook/app/controllers/application_controller.rb:7-14`:

```ruby
    content_security_policy if: -> { EmbedProvider.configured? } do |policy|
      policy.frame_src(*EmbedProvider.csp_frame_sources)
    end
```

A provider entry matches host *and* path prefix (`writebook/app/models/embed_provider.rb:50-60`). A
fixed attribute ceiling excludes `srcdoc`, `sandbox`, `on*`, `style`, `allow` and `referrerpolicy`
for every provider (`embed_provider.rb:26-36`). The scrubber carries a `POLICY_VERSION` that
fragment caches key on, so tightening the rules re-scrubs cached content
(`writebook/app/models/html_scrubber.rb:16-23`).
