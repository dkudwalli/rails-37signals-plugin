# What these codebases refuse to install

The omission is part of the architecture. These apps use Rails' built-ins and small application code
before adding a named layer.

## The evidence (checked 2026-09-18 across all three applications)

```text
$ find {fizzy,once-campfire,writebook}/app -maxdepth 1 -type d \
    \( -name services -o -name presenters -o -name serializers -o -name forms -o -name queries \) -print

$ rg -n -i 'rspec|factory_bot|shoulda|tailwind|sass|postcss|view_component|devise|pundit|cancan|sidekiq|webpack|esbuild|vite|sprockets' \
    {fizzy,once-campfire,writebook}/Gemfile

# both commands produce no output
```

The complete top-level `app/` directory lists are ordinary Rails directories:

```text
fizzy:         assets channels controllers helpers javascript jobs mailers models views
once-campfire: assets channels controllers helpers javascript jobs models views
writebook:     assets channels controllers helpers javascript jobs mailers models views
```

Three more absences are worth naming because the instinct to add them is strong:

```text
$ rg -n 'I18n\.|[^a-zA-Z_.]t\(' {fizzy,once-campfire,writebook}/app
$ rg -n '\bencrypts\b'          {fizzy,once-campfire,writebook}/app
$ rg -ni 'flipper|feature_flag' {fizzy,once-campfire,writebook}/Gemfile

# all three commands produce no output
```

- **No i18n.** Not one `t()` or `I18n.` call in `app/` in any of the three. Each ships
  `config/locales/en.yml` exactly as Rails generated it — 28 comment lines around
  `en:\n  hello: "Hello world"`. User-facing strings are written in English directly in the
  template. Do not introduce `t()` or locale files unless the product is actually shipping a second
  language; wrapping strings "for later" is the kind of anticipatory structure these codebases avoid.
- **No `ActiveRecord::Encryption`.** Zero `encrypts` declarations, including on session and
  credential-adjacent models. Encryption is handled below the application (disk, transport) rather
  than per column.
- **No feature-flag framework.** No Flipper, no rollout gem, no flag table. Work ships, or it
  branches on a real domain attribute that would exist anyway. `rails-tooling-deploy` makes the
  related point about `config.x`: do not add a setting for a value with one caller.

## Absence is a choice, not a prohibition

| Do not add by default | Use first | Add it only when |
|---|---|---|
| RSpec / FactoryBot / shoulda | Minitest, fixtures, Rails assertions | Rails' test support cannot express a real requirement |
| `app/services`, command/query/form layers | model method or a small namespaced model concern | behaviour has a stable boundary that is neither model nor controller |
| presenters / ViewComponent | ERB partial and helper | a component has a real independent lifecycle or public API |
| Tailwind / Sass / PostCSS | plain layered CSS, custom properties, native nesting | browser support or a measured design-system need demands tooling |
| npm, Webpack, esbuild, Vite | importmap plus browser modules | a required browser dependency cannot be loaded that way |
| Devise / Pundit / CanCan | authentication and authorization concerns plus scoped model lookups | the app's identity or policy matrix has outgrown clear local code |
| Sidekiq | Solid Queue (newer apps) or Resque (ONCE apps) | the selected queue cannot meet a measured operational need |
| Elasticsearch / OpenSearch | database full-text search | database-backed search cannot satisfy the query or scale requirement |
| i18n scaffolding (`t()`, locale files) | English strings written directly in the template | the product actually ships a second language |
| `encrypts` / application-level column encryption | ordinary columns; disk and transport encryption | a specific column has a regulatory or threat-model reason |
| Flipper / feature-flag frameworks | ship it, or branch on a real domain attribute | flags outlive a single deploy and need independent lifecycle |

The useful rule: **do not create a category until the code has earned it.** `Card` shows the
preferred growth path — a regular model that includes focused, namespaced concerns
(`fizzy/app/models/card.rb:1-26`), not a parallel application layer.

## The one important exception

"No service objects" is not an absolute ban. `fizzy/STYLE.md:179-183`:

> When justified, it is fine to use services or form objects, but don't treat those as special artifacts:

```ruby
Signup.new(email_address: email_address).create_identity
```

`Signup` lives in `app/models/signup.rb` alongside `Card` and `Board`, named for a domain concept,
not `SignupService` in a `services/` folder. Do not make `app/services` a default bucket.

## How to apply this when asked to add a dependency

State what the app would use instead, name the condition in the table that would justify the
dependency, and ask whether that condition holds. Do not silently add the gem, and do not refuse
outright — the table's right-hand column exists because the exceptions are real.
