---
type: llm
weight: 1
---

The response must express publishing as CRUD on a noun resource rather than as a custom verb
action.

PASS if:
- Routes nest a noun resource, for example `resource :publication` inside `resources :books`, and
  publishing is `POST`/`create` while unpublishing is `DELETE`/`destroy`.
- The controller is named for the noun (for example `Books::PublicationsController` or
  `PublicationsController`) with standard CRUD actions.

FAIL if:
- Routes use a custom verb on a member, for example `post :publish, on: :member`,
  `patch :unpublish`, or `member do post :publish end`.
- The controller defines a `publish` / `unpublish` action.
