<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Acceptance check

Prepare or process an acceptance check: a human verifies, item by item, that built behaviour works in a running app, and whether the user stories behind it are still right. Feedback asks whether the product helps; an acceptance check asks whether each built rule works. `(test)` outcomes are proven by tests and `(check)` outcomes by commands the agent ran, so an acceptance check covers the rest: `(demo)` outcomes, and bug fixes that have no regression test.

The request is `prepare` (the default), `process`, or `all` (a full regression round).

## Prepare
1. Run `bash tools/check.sh`. If it fails, say so and stop: the build isn't worth checking by hand.
2. Collect the `(demo)` outcomes of `done` items in TASKS.md and TASKS-archive.md.
3. For a done item with `UI:`, regenerate its compare images first when capture can run: `bash tools/ui_capture.sh <id> --verify`. If it exits 3, link the images that exist and say they may be out of date.
4. Keep those that haven't been ticked (Works or Broken) in an earlier `validation/*-acceptance.md`. Add done bugs without a regression test whose fix hasn't been ticked yet, with the outcome "the repro no longer happens".
5. **`all`:** keep every `(demo)` outcome, plus one item for each PRD rule that no done item covers. That second part picks up behaviour the app had before SaaSAllTheThings.
6. Write `validation/YYYY-MM-DD-acceptance.md`:
   ```
   # Acceptance check YYYY-MM-DD
   **Build:** <git rev-parse --short HEAD> · **Environment:** <local | dev> · **Covers:** T12, T14, B3
   Tick one box per item; leave both empty if you didn't check it. Say what went wrong in Notes.

   ## Orders
   - **T12** Placing an order shows it in the list with its total. *How:* Windows client, signed in as a Tenant.User of the test tenant.
     - [ ] Works   - [ ] Broken / missing
     - **US-1** As a sales clerk I place an order for a customer while they wait, so they hear it's confirmed before they hang up.
       - [ ] Still right   - [ ] Needs a change
     - Notes:
   ```
   - Group items by PRD section.
   - Write each item as what the user sees, and on which client.
   - Add a *How:* hint: which client, which role, which test tenant. For tenant isolation, include "signed in as the second test tenant, the first one's data isn't visible".
   - Under each item's ticks, the stories its `Stories:` names, word for word from `product/user-stories.md`, each with its own ticks. A story that several items in the round serve appears once, under the first. An item with `Stories: none` gets none, and a story that's no longer in the file is left out.
   - Leave nothing for the tester to copy or format.
   - The entry for a done `UI:` item asks the human to judge the screen against their drawing, and links the compare image:
     ```
     - **T31** The orders screen matches your drawing. *Compare:* `product/ui/captures/orders.compare@1920x1080.png` (your drawing's screenshot on the left, the screen now on the right). *How:* web client, signed in as a Tenant.User of the test tenant; try mouse, touch and keyboard.
       - [ ] Works   - [ ] Broken / missing
       - Notes:
     ```
     It uses the item's own `(demo)` outcome for what to try, so the usual collection of outcomes picks it up. A note that the layout should change is a drawing for `ui-design.md`, not a bug.

## Process
Read the whole ticked file first and work out what it leads to. Write nothing until the human approves a summary of all of it (`design.md` › Summary and approval); a chat message or an "Other" answer before then re-opens the options. The summary lists the `B` items, the story rewrites and ticks, the records of product findings (decision lines, PRD changes, Open Questions), and the Processed line.
1. **Works:** nothing to record; the ticked file is the record.
2. **Broken:** draft a `B` item.
   - Take the repro from the notes, set `Found in:` to the file, and take `Stories:` from the item it was found under.
   - Judge the severity from the notes: `high` if it loses data, shows another tenant's data, fails sign-in or blocks work; `low` if it's cosmetic; `med` otherwise.
   - If the notes say the rule itself should change, it's a product question instead: offer options (`design.md`), or draft an Open Question.
3. **Not ticked:** leave it. It comes back in the next round.
4. **Stories** (`product/user-stories.md`):
   - **Still right:** its Confirmed becomes the check's date.
   - **Needs a change:** draft the rewritten story from the notes and date it. If you had to interpret the notes, show your reading to the human and keep it `unconfirmed` until they confirm it. If the notes say the built behaviour should change too, it's a product question, as for Broken.
   - **Not ticked:** leave it as it is.
5. **Finish:** show the summary and wait. Once the human approves it, write everything it lists: under the header, add `**Processed:** YYYY-MM-DD → B7, Q9, US-1` (the new items and questions, and the corrected stories). Commit everything the summary lists (the file, the new items, the stories, and the decision lines, PRD changes and Open Questions) as `docs: process acceptance check YYYY-MM-DD`; the approval of the summary is the approval to commit.
