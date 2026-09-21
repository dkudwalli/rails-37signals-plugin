---
name: rails-adopt
description: Copies the condensed 37signals Rails ruleset into the target repository's AGENTS.md or CLAUDE.md so every future session follows it. Edits the target file, so invoke it explicitly.
argument-hint: "[AGENTS.md | CLAUDE.md]  (default: whichever exists, else AGENTS.md)"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(diff:*), Bash(wc:*), Bash(git status:*)
disable-model-invocation: true
---

# Adopt the playbook in a target repository

Install the condensed ruleset at `assets/PLAYBOOK.md` in this skill's base directory
(`${CLAUDE_PLUGIN_ROOT}/skills/rails-adopt/assets/PLAYBOOK.md`) into the target repository's agent instructions file.

## Step 1: Confirm the target is a Rails app

Check for `Gemfile` containing `rails` and `config/application.rb`. If either is missing, say so and
stop.

## Step 2: Choose the destination file

Use `$ARGUMENTS` if it names a file. Otherwise use `AGENTS.md` if it exists, else `CLAUDE.md` if it
exists, else create `AGENTS.md`.

## Step 3: Avoid duplication

Search the destination for a `37signals Rails playbook` heading or a `Build shape` heading, at any
heading level. If found, the playbook is
already installed: show the differences between the installed section and the asset, and ask before
replacing it. Never append a second copy.

## Step 4: Install

Read the asset in full. Append it to the destination under a blank line, verbatim except for two
changes: omit the sentence beginning "Copy this into" (an instruction to the installer, not a rule),
and if the destination already has an H1, demote every heading in the installed section by one level
(`#` → `##`, `##` → `###`). The rules themselves are the playbook's own condensed form; do not reword
them. Its citations (`fizzy/...`,
`NN-chapter.md`) point into the 37signals source applications and the playbook chapters; they are
provenance, not paths in this repository. Add this note directly under the installed section's top heading:

```markdown
> Source: the 37signals Rails playbook. Citations refer to Fizzy, Once Campfire and Writebook and to
> the playbook's numbered chapters, not to files in this repository.
```

## Step 5: Reconcile with the application profile

If the destination has no `## Application profile` block, suggest running
`/rails-37signals:rails-profile` next, in one line. If it has one, list — without editing — any rule
in the installed section that the recorded divergences override, so the reader sees which wins.

## Step 6: Report

State the file written, the number of lines added, and whether the Rails version in `Gemfile.lock`
is a released version (in which case remind the user that `params.expect`,
`ActiveSupport::ContinuousIntegration`, `broadcasts_refreshes` morphing and UUIDv7 need a version
check). Do not commit.
