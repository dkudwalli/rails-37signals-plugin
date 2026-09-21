---
type: llm
weight: 1
---

The response must solve this with Stimulus over importmap (or native HTML), with no build step.

PASS if:
- It writes a Stimulus controller (`import { Controller } from "@hotwired/stimulus"`) wired with
  `data-controller` / `data-action`, or uses native `<details>` / `<dialog>` / popover.
- Any new dependency is added via importmap (`bin/importmap pin`).

FAIL if:
- It introduces npm, `package.json`, `node_modules`, esbuild, Webpack, Vite, or `yarn add`.
- It brings in React, Vue, Alpine, jQuery, Bootstrap JS, or a dropdown library.

Bonus signal, not required for PASS: private methods marked `#private`, and every listener added
in `connect()` removed in `disconnect()`.
