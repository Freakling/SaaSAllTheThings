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

- **Heading.** It reads `ID · title · status · size · owner`, and a bug adds `· high|med|low`. New IDs (`T<n>`, `B<n>`, `R<n>`) come from the `Next IDs` line, which you then bump. If the line has no `R` counter yet, add `· R1`. IDs are never reused.
- **Status.** `todo`, `in-progress YYYY-MM-DD` (the claim date) or `done`. "Ready" isn't stored: a `todo` item is ready when everything in `Depends on` is `done`.
- **Size.**
  - `XS`: a single value, label, config line, copy change or comment; no logic changed, no tests needed.
  - `S`: 1-2 files, a setting, text, or a clear bug.
  - `M`: one capability through 1-2 layers, or a feature that follows a pattern.
  - `L`: 3+ layers or systems, new architecture, a stored schema or contract change, or a bug without a repro.
  - `XL`: a cross-cutting refactor, a full subsystem redesign, or a migration affecting 4+ layers. Split before building if you can.

  When in doubt, pick the smaller size. Split an `L` or `XL` when you can: contract first, then domain and application, then the host, then the client. An item that needed more is marked with the new size: `M (escalated from S)`, `S (escalated from XS)`, etc.
- **Owner.** `agent` or `human`. Human items have size `none`: app registrations, consent, customer conversations, production deploys, buying things.
- **`Touches`.** The files expected to change. Mark new files `(new)`, and contract or schema fields `(+field)`.
- **`Done when`.** 1-3 observable outcomes, each tagged `(test)`, `(check)` or `(demo)` (see `rules.md` › Doing the work). Naming `Q<n>` means an open question gates the real behaviour.
- **`PRD:`.** The heading(s) the item implements, or `none` for items that aren't about the product (foundation, infrastructure, tooling).
- **`ADR:`** (optional). The ADR the item implements or depends on.
- **`UI:`** (optional). `product/ui/<screen>.md`, the screen spec, for an item that builds or changes a screen (`procedures/ui-design.md`). The item builds to the spec and names its elements as the spec does. A `UI:` item sized `L` or `XL` is split per screen.
- **Bugs.** Instead of `Done when`, a bug has `Repro: steps → expected / actual` and `Found in:` (a validation file, a security assessment report in `assessment/security/`, an item ID or `ad hoc`). It's done when the repro no longer happens.
- **Research.** A research item (`R<n>`) answers one question and changes no code. It looks like this:

  ```
  ### R3 · Which Azure regions keep a tenant's data in the EU · todo · M · agent
  - Depends on: none
  - Question: Which Azure regions and services keep a tenant's data in the EU, and what does each cost to run? Assume under 50 tenants and the stores in reference/data.md.
  - Informs: Q4
  - PRD: Data and Compliance
  ```

  - The owner is always `agent`; status and `Depends on` work as for any item.
  - `Question:` replaces `Done when`: one question, stated so a reader can tell when it is answered. It may state assumptions and scope.
  - `Informs:` is the open question the research feeds (`Q<n>`), or `none`. `PRD:` is the heading the question concerns, or `none`. There is no `Touches`.
  - It is done when its note exists in `product/research/` (see `procedures/research.md`). A note that says what was searched and what stays unknown is a valid result; the human decides whether to queue a follow-up.
  - It is sized like any item (the same rules for doubt and escalation), and the size picks the model:
    - `XS`: one fact check against one primary source, such as a version, a licence, a limit or a date.
    - `S`: one narrow question with two options and a few sources, such as whether a service supports a feature.
    - `M`: a comparison of 2-4 options in one area, with trade-offs and a recommendation.
    - `L`: an architecture, security or requirements comparison across several areas, with sources to reconcile.
    - `XL`: several linked areas that feed more than one decision, such as a stack choice with security, cost and migration. Split it when you can.
- **`Note:`** (optional). An item paused partway through gets `- Note: <where it stands, what's next>`. Delete the note when the item is done.
- **Merge conflicts.** On a merge conflict in TASKS.md, keep both sides' items, give any duplicate ID a new number from `Next IDs`, and fix references to it.
