---
name: rails-css
description: This skill should be used when writing or restructuring stylesheets in a Rails app — when the user asks to "style this", "add CSS", "add dark mode", "add a theme toggle", "set up design tokens", "add Tailwind", "add Sass", "fix specificity", "add a utility class", "make this accessible", or mentions `@layer`, custom properties, oklch, CSS nesting, BEM, focus styles, or Propshaft. Provides plain-CSS architecture (cascade layers, two-tier colour tokens, component custom-property APIs) and the accessibility baseline from three 37signals applications.
---

# CSS and design

Plain CSS served by Propshaft. No Sass, PostCSS, Tailwind, CSS-in-JS or build step — and 8,887 lines
of it in fizzy, so this is not a small-app shortcut.

## Files

- One file per component, named after what it styles (`buttons.css`, `cards.css`, `dialog.css`),
  flat, with no manifest. Link them with one `stylesheet_link_tag :app` (or `:all`)
  (`fizzy/app/views/layouts/shared/_head.html.erb:20`). Adding a component means adding a file.
- Load order is alphabetical. If a rule's correctness depends on file order, fix it with `@layer`,
  not by renaming files.

## Cascade layers, declared once

`fizzy/app/assets/stylesheets/_global.css:1`:

```css
@layer reset, base, components, modules, utilities, native, platform;
```

Every file opens with its layer (`@layer components { ... }`). Import third-party CSS straight into a
layer: `@import url("lexxy-content.css") layer(base);`.

> Divergence: campfire and writebook use no `@layer` (0 of 26 files); they predate it. Fizzy uses it
> in 60 of 64. Use layers — this is the clearest "newest wins" case.

## Two-tier colour tokens

`writebook/app/assets/stylesheets/colors.css:1-35`:

1. `--lch-*` hold bare oklch components: `--lch-blue: 54% 0.15 255;`
2. `--color-*` are semantic and wrap a raw token: `--color-link: oklch(var(--lch-blue));`

Components use only `--color-*`. No component file names a hue. Name by role — `--color-ink` and
`--color-bg` rather than black and white — with `-light` / `-dark` modifiers and
`--color-always-black` for the few things that must not invert.

## Dark mode lives in the token layer

Redefine only the `--lch-*` values in one `@media (prefers-color-scheme: dark)` block inside `:root`
(`writebook/app/assets/stylesheets/colors.css:37-50`). **If a dark-mode rule is being written inside a
component, the tokens are wrong.**

For a manual theme toggle, write each dark rule twice — `html[data-theme="dark"] &` and
`@media (prefers-color-scheme: dark) { html:not([data-theme]) & }` — and set `data-theme` before first
paint with a nonce'd inline script in `<head>` ahead of the stylesheet
(`fizzy/app/views/layouts/_theme_preference.html.erb:1-6`). Declare
`<meta name="color-scheme" content="light dark">`.

## Tokens beyond colour

Keep the design system in one `:root` (`fizzy/app/assets/stylesheets/_global.css:3-69`):

- Logical, relative spacing: `--inline-space: 1ch`, `--block-space: 1rem`, with `-half` / `-double`
  via `calc()`. Two axes, three sizes — not a 12-step scale.
- A type scale made responsive by redefining the tokens inside a `@media`, not by restating
  `font-size` per component.
- System font stacks (`ui-serif`, `ui-monospace`, `-apple-system`).
- Tokens for shadows, focus rings, component sizes, durations and named easings.

## Components expose custom properties as their API

Every visual property reads `var(--btn-*, <default>)` (`fizzy/app/assets/stylesheets/buttons.css:2-23`).
A variant sets variables instead of re-declaring properties
(`fizzy/app/assets/stylesheets/theme-switcher.css:10-27`). No `!important`, no specificity ladders.
Pass data from Ruby as one inline custom property and derive the rest with `color-mix()`
(`fizzy/app/assets/stylesheets/cards.css:5-16`).

## Naming, nesting, utilities

- BEM-ish: `block__element--modifier`, one element level. The class name states structure, so no
  descendant selectors and flat specificity.
- Native nesting for states, media queries, and ancestor context (`html[data-theme="dark"] &`) —
  not to mirror DOM structure.
- Utilities exist, but each is one hand-written rule resolving a **token** with a domain name
  (`.txt-subtle`, `.txt-alert`) in the `utilities` layer (`fizzy/app/assets/stylesheets/utilities.css:1-38`).
  The moment an arbitrary value is wanted (`mt-[13px]`), write a component class instead.
- Logical properties throughout: `inline-size`, `padding-block`, `margin-inline`, `text-align: start`.
- Vendor the reset with attribution rather than adding a dependency.
- Declare `allow_browser versions: :modern` once, then use `oklch()`, `color-mix()`, `:has()`, `clamp()`,
  `dvw`/`lh` units and view transitions without prefixes or fallbacks.

## Accessibility baseline, in shared rules

`fizzy/app/assets/stylesheets/base.css:35-53` gives every interactive element a
`:where(:focus-visible)` ring and a `:where([disabled])` state at zero specificity. Also:

- Skip link first in the DOM.
- Guard every hover effect with `@media (any-hover: hover)`.
- `.for-screen-reader` labels on icon-only buttons; icons `aria-hidden` by construction.
- Style from `aria-busy`, which the Stimulus controller sets.
- Strip list styling only on `:where(ul, ol):where([role="list"])`.
- Semantic elements: `<section>`, `<header>`, `<main>`, `<nav>`, `<dialog>`, `<kbd>`.
