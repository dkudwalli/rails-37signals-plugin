---
name: rails-jobs-async
description: This skill should be used when adding background jobs, callbacks that trigger async work, recurring/scheduled tasks, mailers, push notifications, or queue configuration in Rails — when the user asks to "add a background job", "do this async", "send an email later", "schedule a cron task", "add a recurring job", "add Sidekiq", "configure Solid Queue", "notify users", or mentions `perform_later`, `ActiveJob`, `recurring.yml`, Resque, `after_commit`, or `Current` inside a job. Provides the `_later`/`_now` convention, shallow job classes, tenant-context serialization, and recurring-task rules from three 37signals applications.
---

# Background work

Job classes are one line of delegation. The naming convention is what makes that possible.

## `_later` enqueues, `_now` performs, the job knows nothing

`fizzy/STYLE.md:185-213`. The real shape (`fizzy/app/models/concerns/notifiable.rb:1-22` and
`fizzy/app/jobs/notify_recipients_job.rb:1-7`):

```ruby
module Notifiable
  extend ActiveSupport::Concern

  included do
    after_create_commit :notify_recipients_later
  end

  def notify_recipients
    Notifier.for(self)&.notify
  end

  private
    def notify_recipients_later
      NotifyRecipientsJob.perform_later self
    end
end

class NotifyRecipientsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(notifiable)
    notifiable.notify_recipients
  end
end
```

**Rules:**

- Put the `_later` method on the model, usually private. It is the only place a job class is named.
- Name the pair after the domain action: `notify_recipients_later` / `notify_recipients`,
  `deliver_later`, `clean_inaccessible_data_later`. Add `_now` only when the synchronous name would
  collide.
- `perform` takes records (GlobalID), not ids, and calls one model method.
- Declare `retry_on` / `discard_on` per job, not globally — whether a vanished record is a bug or a
  normal race depends on the job. Keep `ApplicationJob` a stub.
- **Enqueue from `after_*_commit`, never `after_save` / `after_create`.** A worker in another process can
  only see committed rows.
- Namespace jobs under the model that owns them: `app/jobs/card/clean_inaccessible_data_job.rb`.

## Serialize request context across the queue boundary

Never rely on ambient `Current` surviving into a job. Fizzy prepends a concern onto `ApplicationJob`
that captures the account at enqueue and restores it at perform
(`fizzy/app/jobs/concerns/account_tenanted.rb:1-46`):

```ruby
module AccountTenanted
  extend ActiveSupport::Concern

  prepended do
    attr_reader :account
    around_perform :with_account_context
  end

  def initialize(...)
    super
    @account = Current.account
  end

  def serialize
    super.merge({ "account" => @account&.to_gid })
  end

  def deserialize(job_data)
    super
    @account_gid = job_data["account"]
  end
```

Resolution is deferred to `around_perform` so a deleted tenant raises inside the path where
`discard_on` can handle it. Copy this for any ambient context: tenant, locale, actor. Pair it with a
test harness that blanks `Current.account` inside `perform_enqueued_jobs` (see the `rails-testing`
skill) so a job that forgot its context fails in tests.

## Bulk and recurring work

- Fan out with `ActiveJob.perform_all_later(jobs)` inside `in_batches`, from a scheduled job whose only
  work is the fan-out (`fizzy/app/models/notification/bundle.rb:22-33`).
- Declare recurring work in `config/recurring.yml` (Solid Queue). Prefer `command:` calling a class
  method or a `*_later` method over `class:` naming a job created only to be scheduled
  (`fizzy/config/recurring.yml:1-30`).
- **Stagger the minutes** (`at minute 50`, `at minute 12`, `at 04:02`) so no two tasks fire together.
- Give every model that accumulates rows a `cleanup` class method and schedule it
  (`Webhook::Delivery.cleanup`, `MagicLink.cleanup`). Schedule cleanup of the queue's own finished
  jobs too.

## Queue configuration

One worker pool listening to named queues **plus `"*"`**, so a new queue name never strands jobs;
process count from `Concurrent.physical_processor_count` with an env override; the same config in
every environment (`fizzy/config/queue.yml:1-13`).

## The backend is a profile decision

| | Fizzy | Campfire / Writebook |
|---|---|---|
| Adapter | Solid Queue (database) | Resque + resque-pool (Redis) |
| Recurring | `config/recurring.yml` | none |

> Divergence — direction of travel: Solid Queue for new work. It removes Redis from the deployment.
> Keep Resque only for an ONCE-compatible app with an existing Redis/Resque constraint. **Never run
> both for the same work**, and do not combine Procfile workers with `SOLID_QUEUE_IN_PUMA`. The
> `_later`/`_now` convention is identical on either backend. See the `rails-tooling-deploy` skill and
> `/rails-37signals:rails-profile`.

## Mail and push are delivery paths chosen by the model

- An `ApplicationMailer` owns layout, sender, helpers and URL policy. A mailer action sets
  collaborators and calls `mail` (`fizzy/app/mailers/export_mailer.rb:1-18`). The domain operation
  selects and enqueues mail.
- Use configured `default_url_options` for absolute URLs in mail, never request state.
- Add one-click unsubscribe headers to subscription mail
  (`fizzy/app/mailers/concerns/mailers/unsubscribable.rb:1-11`).
- Push is opt-in and best-effort: persist the subscription and preference first, queue the network
  delivery, and send a destination plus compact display data — never authority to mutate state.
