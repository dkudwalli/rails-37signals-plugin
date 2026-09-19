---
name: rails-profile
description: This skill should be used when the user asks to "choose an app profile", "start a new Rails app the 37signals way", "Solid Queue or Redis", "should I use Kamal", "pick a Rails stack", "record the application profile", or runs /rails-37signals:rails-profile. Walks through the ONCE-compatible versus Fizzy profile decision and records the result in the target app's AGENTS.md.
argument-hint: "[AGENTS.md | CLAUDE.md]  (default: whichever exists, else AGENTS.md)"
allowed-tools: Read, Edit, Write, Glob, Grep, AskUserQuestion, Bash(git status:*)
disable-model-invocation: true
---

# Choose and record the application profile

Do not assemble a Rails architecture one gem at a time. Choose one of two coherent profiles, then
record the product-specific deviations. Never average the two into a hybrid.

## The two profiles

| | ONCE-compatible | Fizzy |
|---|---|---|
| Product boundary | One self-hosted account | Multiple accounts, or a credible path to them |
| IDs | Integer | UUIDv7, base36 |
| Primary database | SQLite | SQLite or MySQL/Trilogy |
| Request context | `Current.user` / `Current.account` | Account-aware `Current` + serialized job context |
| Jobs | Resque + resque-pool | Solid Queue |
| Cache / Cable | Redis | Solid Cache / Solid Cable |
| Storage | Local disk, public when content is public | Local or S3, record-aware authorization |
| Deployment | Docker + Procfile processes | Kamal + Docker, persisted storage volume |
| Data portability | Back up the instance | Account export/import as a persisted resource |

ONCE-compatible is what Campfire and Writebook run. Fizzy is the newest 37signals stack and has no
Redis at all.

## Step 1: Inspect the target

Read `Gemfile`, `config/database.yml`, `config/environments/production.rb`, `Procfile*`,
`config/deploy.yml`, `config/queue.yml`, `config/cache.yml` and `config/cable.yml` where present.
Note what is already decided. If the target already mixes Solid and Redis families, say so first.

Read the target instructions file: the path from `$ARGUMENTS` if given, else `AGENTS.md` if it exists,
else `CLAUDE.md` if it exists, else `AGENTS.md` (created in Step 4). This matches `rails-adopt`, so the
profile sits in the same file as the rules. If it already has an
`## Application profile` block, show it and ask whether to revise it.

## Step 2: Decide the product boundary first

Ask with AskUserQuestion, in this order, skipping anything the inspection already settled:

1. **Tenancy** — one self-hosted account, or multiple isolated accounts?
2. **Existing ONCE constraint** — must it run alongside an existing Redis/Resque deployment?
3. **IDs** — must identifiers cross systems, be non-enumerable, or be generated outside the database?
4. **Storage** — is attached content public, or private per account/user?
5. **Deploy** — Kamal, or an ONCE-style Docker/Procfile layout?

Apply the default from the playbook: **for a new self-hosted product with no ONCE compatibility
requirement, take Fizzy's Solid runtime but keep SQLite and integer ids** until a real multi-account
or identifier requirement changes them. Do not inherit Redis merely because the product is
self-hosted.

Record that default as `Profile: Fizzy` with
`Deliberate divergences: integer ids (no multi-account or cross-system identifier requirement yet)`.
A divergence is one named decision with a reason; it is not a hybrid.

## Step 3: Enforce the non-negotiable combinations

- Solid Queue, Solid Cache and Solid Cable are one runtime decision.
- Redis, Resque and resque-pool are one ONCE operational decision. Do not import only the worker
  command or only the Redis cache setting.
- UUIDv7, deterministic fixture UUIDs, `id` tie-breakers and account context belong together.
- Private attachment authorization, tenant-aware routes and durable storage are designed as a group.
- Never combine Procfile workers with `SOLID_QUEUE_IN_PUMA`.

If an answer would break one of these, explain the conflict in one sentence and ask again.

## Step 4: Record it

Insert this block at the top of the target file chosen in Step 1, after its H1 if one exists (create
the file if absent):

```markdown
## Application profile

Profile: <Fizzy | ONCE-compatible>
Reason: <one product constraint>
Deliberate divergences: <each decision above that differs from the profile, or "none">
```

That is enough. Do not generate configuration files, a template generator, or a settings framework
for the two profiles. Report the block written and, in one line each, which existing config files
disagree with the chosen profile.
