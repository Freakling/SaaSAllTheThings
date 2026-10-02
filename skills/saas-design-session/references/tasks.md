<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# TASKS.md items

Read this before adding or editing an item.

```
### T12 · Place an order through the API · todo · M · agent
- Depends on: T10
- Touches: src/OrderDesk.Application/Orders/PlaceOrderHandler.cs (new), src/OrderDesk.Functions/Orders/PlaceOrderFunction.cs (new), tests/OrderDesk.Application.Tests/Orders/PlaceOrderHandlerTests.cs (new)
- Done when: an order without lines is rejected (test) · OrderPlacedV1 is saved with the order (test) · POST /api/v1/orders answers 201 in dev (demo)
- PRD: Capabilities › Orders
```

- **Heading.** It reads `ID · title · status · size · owner`, and a bug adds `· high|med|low`. New IDs (`T<n>`, `B<n>`) come from the `Next IDs` line, which you then bump. IDs are never reused.
- **Status.** `todo`, `in-progress YYYY-MM-DD` (the claim date) or `done`. "Ready" isn't stored: a `todo` item is ready when everything in `Depends on` is `done`.
- **Size.**
  - `S`: 1–2 files, a setting, text, or a clear bug.
  - `M`: one capability through 1–2 layers, or a feature that follows a pattern.
  - `L`: 3+ layers or systems, new architecture, a stored schema or contract change, or a bug without a repro.

  When in doubt, pick the smaller size. Split an `L` when you can: contract first, then domain and application, then the host, then the client. An item that needed more becomes `M (escalated from S)`.
- **Owner.** `agent` or `human`. Human items have size `—`: app registrations, consent, customer conversations, production deploys, buying things.
- **`Touches`.** The files expected to change. Mark new files `(new)`, and contract or schema fields `(+field)`.
- **`Done when`.** 1–3 observable outcomes, each tagged `(test)`, `(check)` or `(demo)` (see `rules.md` › Doing the work). Naming `Q<n>` means an open question gates the real behaviour.
- **`PRD:`.** The heading(s) the item implements, or `—` for items that aren't about the product (foundation, infrastructure, tooling).
- **`ADR:`** (optional). The ADR the item implements or depends on.
- **Bugs.** Instead of `Done when`, a bug has `Repro: steps → expected / actual` and `Found in:` (a validation file, an item ID or `ad hoc`). It's done when the repro no longer happens.
- **`Note:`** (optional). An item paused partway through gets `- Note: <where it stands, what's next>`. Delete the note when the item is done.
- **Merge conflicts.** On a merge conflict in TASKS.md, keep both sides' items, give any duplicate ID a new number from `Next IDs`, and fix references to it.
