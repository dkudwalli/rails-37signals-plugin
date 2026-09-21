---
type: llm
weight: 1
---

The response must put the checkout logic in the Rails model layer, not a parallel service layer.

PASS if:
- The logic lands on a model (for example `Order`, or a namespaced concern like `Order::Checkout`
  in `app/models/order/`), or on a plain domain class in `app/models/`.
- No `app/services/` directory is proposed, and no class named `*Service`, `*Interactor`,
  `*Command`, `*UseCase`, `*Organizer` or `*Action` is introduced as the home for this logic.

FAIL if:
- The response creates `app/services/CheckoutService`, a service object, an interactor, or any
  new top-level `app/` directory for this behaviour.
- The response presents a service layer as the default or recommended approach, even if it
  mentions a model alternative afterwards.

Note: a domain class in `app/models/` named for a concept (for example `Checkout`) is a PASS —
what matters is that it is a named domain concept in the model layer, not a `services/` bucket.
