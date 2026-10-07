<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Build one item

Build one TASKS.md item that has already been claimed, and report back briefly. Until you've written the report, don't pick items, don't edit TASKS.md, AGENTS.md, `product/` or `adr/`, and don't commit. Whoever handed you the item does that; if that's you, carry on with `next-task.md` afterwards.

1. **Read what the item needs.** You have the item's ID and full text, and on a rebuild also the previous report and the human's instructions. Read its `Touches`, the AGENTS.md › Architecture rows involved, the PRD sections under `PRD:` (`grep -n "^#" product/prd.md` lists the headings), the ADR under `ADR:` if any, and the reference topics the work touches (`.satt/reference/README.md` lists them). Follow references from there, reading by heading or line range.
2. **Open questions.** If `Done when` names a question still listed in PRD › Open Questions, build the rest and stand in for the answer:
   - a missing value becomes a default marked `PLACEHOLDER`, with the `Q<n>`;
   - a missing behaviour stays as it is, behind a named constant or feature flag with a comment citing `Q<n>`.
3. **Stop and report `blocked` instead of guessing** when:
   - you hit a product call the PRD doesn't settle (give 2-4 options and a recommendation);
   - a rule in `.satt/reference/` can't be met, or the item needs a choice the reference leaves open and no ADR settles: report `blocked: architecture` with the rule, why, and 2-4 options with "comply" first;
   - the item needs something it doesn't describe;
   - it would touch much more than its `Touches`.

   Never change `tools/check.cfg` › `[layers]`, add an ADR exception, or move code out of a layer to get past an architecture failure.
4. **Build** by `.satt/rules.md` › Architecture in code, and the reference topics you read. Write a test for every `(test)` outcome, a tenant-isolation test for every new store, and a regression test for a bug when it can have one. Stay inside the item.
5. **Verify.** While working, `bash tools/check.sh --architecture` answers in seconds. At the end, run `bash tools/check.sh` (foreground, long timeout) until it exits 0.
   - After two failed attempts at the same problem, stop and report.
   - A failure in files the item doesn't touch, which was there before you started, isn't yours: report `failed: pre-existing` with its lines.
   - Exit 3 means the check couldn't run; report that.
6. **Report** in at most about 20 lines. It's all the caller keeps, so no file dumps:
   ```
   Result: done | blocked: <question, options, recommendation> | blocked: architecture: <rule, why, options (comply first), recommendation> | failed: <last check lines> | failed: pre-existing: <lines>
   Files: <changed and new files>
   Done when: <each outcome → the test that proves it | the command and its result | what a human should look at>
   Systems: <systems, functions or messages added, removed or re-scoped, with a one-line "owns" | none>
   Contracts: <API routes, events, commands or stored schemas added or changed | none>
   Placeholders: <new PLACEHOLDER values | none>
   For the human: <questions or decisions | none>
   Found: <work outside this item, one line each | none>
   Touches: <files changed that aren't listed, and listed files not needed | same>
   ```
