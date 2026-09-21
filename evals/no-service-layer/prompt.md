---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm working on a Rails 8 app that sells tickets. I need to add a checkout process: it should
charge the customer, mark the order as paid, send a confirmation email, and decrement the
remaining ticket inventory.

Where should this code live, and what should it look like? Show me the classes you'd add.
