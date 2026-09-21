---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

Rails 8 app, deployed on one server. We already run a Redis instance on that box for a legacy PHP
service that isn't going away.

I now need background jobs, a cache store, and Action Cable for a live activity feed. Since Redis
is already there and running, what should I use for each?
