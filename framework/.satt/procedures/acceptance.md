<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Acceptance check

Prepare or process an acceptance check: a human verifies, item by item, that built behaviour works in a running app. Feedback asks whether the product helps; an acceptance check asks whether each built rule works. `(test)` outcomes are proven by tests and `(check)` outcomes by commands the agent ran, so an acceptance check covers the rest: `(demo)` outcomes, and bug fixes that have no regression test.

The request is `prepare` (the default), `process`, or `all` (a full regression round).

## Prepare
1. Run `bash tools/check.sh`. If it fails, say so and stop: the build isn't worth checking by hand.
2. Collect the `(demo)` outcomes of `done` items in TASKS.md and TASKS-archive.md.
3. Keep those that haven't been ticked (Works or Broken) in an earlier `validation/*-acceptance.md`. Add done bugs without a regression test whose fix hasn't been ticked yet, with the outcome "the repro no longer happens".
4. **`all`:** keep every `(demo)` outcome, plus one item for each PRD rule that no done item covers. That second part picks up behaviour the app had before SaaSAllTheThings.
5. Write `validation/YYYY-MM-DD-acceptance.md`:
   ```
   # Acceptance check YYYY-MM-DD
   **Build:** <git rev-parse --short HEAD> · **Environment:** <local | dev> · **Covers:** T12, T14, B3
   Tick one box per item; leave both empty if you didn't check it. Say what went wrong in Notes.

   ## Orders
   - **T12** Placing an order shows it in the list with its total. *How:* Windows client, signed in as a Tenant.User of the test tenant.
     - [ ] Works   - [ ] Broken / missing
     - Notes:
   ```
   - Group items by PRD section.
   - Write each item as what the user sees, and on which client.
   - Add a *How:* hint: which client, which role, which test tenant. For tenant isolation, include "signed in as the second test tenant, the first one's data isn't visible".
   - Leave nothing for the tester to copy or format.

## Process
1. **Works:** nothing to record; the ticked file is the record.
2. **Broken:** make a `B` item.
   - Take the repro from the notes, and set `Found in:` to the file.
   - Judge the severity from the notes: `high` if it loses data, shows another tenant's data, fails sign-in or blocks work; `low` if it's cosmetic; `med` otherwise.
   - If the notes say the rule itself should change, it's a product question instead: offer options (`product.md`), or add an Open Question.
3. **Not ticked:** leave it. It comes back in the next round.
4. **Finish:** under the header, add `**Processed:** YYYY-MM-DD → B7, Q9`. Commit the file and the new items as `docs: process acceptance check YYYY-MM-DD` after the human approves.
