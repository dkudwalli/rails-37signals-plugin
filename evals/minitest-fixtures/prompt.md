---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

Rails 8 app. Here's a model:

```ruby
class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :plan

  scope :active, -> { where(cancelled_at: nil) }

  def cancel!
    update!(cancelled_at: Time.current)
  end

  def active? = cancelled_at.nil?
end
```

Write tests for it.
