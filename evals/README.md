# Evals

Six cases that check whether the plugin actually changes what Claude writes — not whether it loads.

```bash
claude plugin eval . --ablation with-without --trust-plugin
```

`--ablation with-without` runs each case twice, once with the plugin and once without, and reports
the delta. **The delta is the result.** A case that passes in both arms proves nothing about the
plugin; it only shows the model already knew.

Each case is self-contained — no scaffold script, no fixture repo, no `--allow-tools`. The prompt
describes a situation and asks for code, and an LLM grader judges the answer against one rule.

## The cases

| Case | The rule it tests | The wrong answer it tempts |
|---|---|---|
| `no-service-layer` | Logic belongs on a model | `app/services/CheckoutService` |
| `state-as-record` | State that needs who/when is a record | `closed:boolean` + `closed_at` + `closed_by_id` |
| `noun-resource` | Transitions are CRUD on a noun | `post :publish, on: :member` |
| `minitest-fixtures` | Minitest and fixtures | RSpec and FactoryBot |
| `no-build-js` | Stimulus over importmap | npm, a bundler, a component library |
| `one-queue-family` | One runtime family, never mixed | Solid Queue + Redis cache |

## Results, 2026-09-21

Run at `--runs 1`, so single-sample and noisy; treat these as direction, not measurement.

| Case | With | Without | Δ |
|---|---|---|---|
| `minitest-fixtures` | 1.00 | 0.00 | **+1.00** |
| `no-service-layer` | 1.00 | 0.00 | **+1.00** |
| `noun-resource` | 1.00 | 0.00 | **+1.00** |
| `state-as-record` | 1.00 | 0.00 | **+1.00** |
| `no-build-js` | 1.00 | 1.00 | 0.00 |
| `one-queue-family` | 1.00 | 1.00 | 0.00 |

Mean Δ +0.67, about $1.20 for the suite.

**Four rules are doing real work.** Without the plugin the model reached for a service object, a
boolean column, a custom `publish` action and RSpec every time. With it, none of those.

**Two rules are not.** `no-build-js` and `one-queue-family` pass without the plugin. The baseline
model already prefers Stimulus over npm and already picks one queue family. `one-queue-family` was
rewritten to bait a mixed stack — "we already run Redis on this box for a legacy service" — and the
baseline *still* declined to mix. These two cases are kept as regression guards, not as evidence
the plugin adds anything. Do not quote the mean Δ as if all six contributed.

That is worth knowing in itself: those two chapters of the playbook are now consensus, and the
plugin earns its keep on structural rules the model does not hold by default.

## Adding a case

A useful case is one where the unaided model reliably does the wrong thing. If you cannot state
the wrong answer the prompt tempts, the case will score 1.00 in both arms and tell you nothing.

Write the grader as PASS/FAIL conditions, not a rubric — and say explicitly whether hedging counts.
Several graders here end with a line like "a response that does both is still a FAIL", because the
model's habit under a style constraint is to offer the house answer *and* the one it would have
given anyway.

## Caveats

- Graders are LLM judges (haiku by default), so scores move between runs. Use `--runs 3` or more
  before drawing a conclusion from a small delta.
- The suite costs real money and needs an API session, so it is not in CI. Run it before a release.
- A grader that errors is reported as a score of 0.00. Check the `NOTES` column before reading a
  zero as a failure — a rate limit looks exactly like a failed case in the summary table.
