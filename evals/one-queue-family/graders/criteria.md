---
type: llm
weight: 1
---

The prompt is a trap: Redis is already running, which tempts a mixed stack. The response must pick
ONE coherent family for all three of jobs, cache and cable.

PASS if:
- All three come from the same family. Either all Solid (Solid Queue + Solid Cache + Solid Cable,
  leaving the legacy Redis alone for the PHP service), or all Redis (Resque/Sidekiq + Redis cache +
  Redis cable).
- If it recommends reusing Redis, it does so for all three consistently.

FAIL if:
- It mixes: for example Solid Queue for jobs but Redis for cache, or Solid Cache but Redis Cable.
- It says "use Redis for cache since it's already there" while recommending Solid for anything else.

Bonus signal, not required: noting that the existing Redis belongs to another service, so sharing
it couples this app's availability to the legacy one.
