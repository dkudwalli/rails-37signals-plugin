# Sources

Every rule in this plugin was read out of one of three 37signals applications. This file pins the
commit each was read at, so a citation stays checkable as those repositories move.

## Pinned commits

Observed 2026-09-18.

| App | Repository | Commit | Commit date |
|---|---|---|---|
| Fizzy | `basecamp/fizzy` | `7355df9b60835c9cb1928d06fc144b2ff57d75ca` | 2026-09-16 |
| Once Campfire | `basecamp/once-campfire` | `977cbcd135783e09d631301bc39cbb4e7961ec4e` | 2026-09-11 |
| Writebook | `basecamp/writebook` | `1611741e83c47d0feca9b742bef561dad807b2f4` | 2026-09-12 |

Fizzy is the newest and wins where the three disagree. See the "Two warnings" section of the README.

## Citation format

A citation is a backticked, repo-relative path with an optional line range:

```text
`fizzy/app/models/card.rb:22-24`     preferred — path and line range
`writebook/app/helpers/forms_helper.rb`   acceptable when the whole file is the point
```

Rules:

- **Lead with the repository directory name**, lowercase: `fizzy`, `once-campfire`, `writebook`.
  Not `Fizzy`, not `campfire`.
- **Prefer a line range.** Cite the narrowest range that contains the rule.
- **One range per citation.** For a rule evidenced in two places, write two citations rather than
  `file.rb:4-9, 68-88` — the checker only reads the first range of a multi-range citation.
- **In prose, the applications are `Fizzy`, `Once Campfire` and `Writebook`.** The lowercase form is
  for paths only.

`writebook/AGENTS.md` and its siblings are legitimate sources: they are the applications' own
instructions to their agents. Cite them like any other file.

## Checking citations

```bash
scripts/check-citations.sh                    # looks in ~/Projects
scripts/check-citations.sh /path/to/parent    # or point it somewhere
RAILS_37SIGNALS_SRC=/path/to/parent scripts/check-citations.sh
```

The parent directory must contain `fizzy/`, `once-campfire/` and `writebook/`. The script asserts
every cited file exists and every line range is within its file. It exits 2 if the checkouts are not
there, so it is safe to skip in an environment that does not have them.

What it cannot check is whether the cited lines still *say* what the rule claims. That is why the
commits above are pinned: to re-verify a rule, check out that commit and read the cited lines.

## Scope of the citations

Citations record where a rule was observed. They are not a claim that every rule carries one — see
the plugin description, which says rules are "drawn from" these applications "with citations into
their source", not that every line is cited. Uncited rules are mostly connective tissue and
rationale. When adding a rule, cite it.
