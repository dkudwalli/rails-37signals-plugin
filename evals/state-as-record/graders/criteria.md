---
type: llm
weight: 1
---

The response must model the closed state as its own record, not as columns on `Card`.

PASS if:
- It introduces a separate record (for example `Closure`) associated with `has_one :closure`,
  where "who" and "when" come from that record's own columns (a `creator`/`user` association and
  `created_at`).
- Closing creates the record and reopening destroys it.

FAIL if:
- It adds `closed:boolean`, `closed_at:datetime` and `closed_by_id` columns to `cards` as the
  primary design.
- It uses an enum or a status string column on `Card` for this.

A response that adds the columns AND mentions the record alternative is still a FAIL — the
record must be the recommended design.
