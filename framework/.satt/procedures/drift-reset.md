<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Drift reset

When a design principle has been read in more than one way across the project, patching one place at a time makes it worse. A drift reset stops, describes the system as built, maps how each principle was interpreted, has the director rewrite the design where it splits, and plans the rebuild as items. `align.md` fixes small drift routinely; a reset is for when align keeps surfacing the same conflict, or one conflict spans several principles. Align often, reset when you have to.

**Only the director starts a reset.** Never start one on your own or from another procedure: `align.md` may recommend one, and the director decides. If the request is only "tidy the docs", offer `align.md` instead. Postmortem mode (`drift-reset postmortem`) runs after the rebuild; see Postmortem.

**Scope: the product design the director owns:** Product Pillars, the PRD, `product/decisions.md`, and the business rules in integration contracts. The architecture is not in scope. Never propose a change to tenancy, identity, cost or any other rule the check enforces, and never relax a check rule or add an ADR exception inside a reset. If the analysis shows a framework rule genuinely conflicts with the product, that's an architecture call: follow `architect.md`, where complying is option one and only the director accepts the ADR. Accepted ADRs are part of the design: a reset never drops or overrides one without a new ADR.

**No application code.** A reset writes the reset folder, the PRD, `product/decisions.md`, integration contracts, ADR drafts and TASKS.md items. The rebuild runs through `next-task.md`.

**Safety.** Recommend running the reset on its own branch (`git switch -c reset/YYYY-MM-DD`), and ask before creating it. Never run a destructive git command (`reset --hard`, `clean`, `checkout --`, `restore`, a force push). Never delete the old design or the analysis: the reset folder only grows.

The reset folder is `resets/YYYY-MM-DD/` (today; add `-2` for a second reset on the same day). It holds snapshots, like `assessment/`: what a reset decides is recorded in the PRD, `decisions.md`, ADRs and TASKS.md.

## 0. Frame it
1. Say what triggered the reset in one or two lines: the recurring or cross-cutting conflict, and the align report, item or decision it came from.
2. Check the tree is clean (`git status`), and recommend the reset branch.
3. List the areas to analyse from AGENTS.md › Architecture and › Layout: one per area of capabilities, client or integration, plus **tenancy and identity**, always its own area. Confirm the list with the director.

## 1. Analyse as built (read only)
Describe how the system behaves today, not how the PRD says it should. Change nothing but the reset folder.
- Run one read-only analysis per area, each in a fresh context: parallel subagents where the tool has them (in Claude Code, `Explore`), otherwise one area at a time, keeping only each area's summary. Give each its area, its folders, and the instruction to describe behaviour with `file:line` evidence and change nothing.
- **Per area:** what each capability does (inputs, rules, outputs, events), where its business rules live, what's stored and who owns it, and what the clients show and allow.
- **Tenancy and identity:** where the tenant comes from at every entry point; whether every store, query, blob path, cache key and message carries it; token validation and authorization per use case; anything that reads across tenants outside `platform`. Drift here is a security finding, not only a design one: mark it `security` and tell the director at once. It isn't a design call, because the reference already settles it (`reference/tenancy.md`, `reference/identity.md`): it becomes a `high` bug in step 4.
- Write `resets/YYYY-MM-DD/as-built.md`: one section per area, each statement with its `file:line`.

## 2. Map interpretations (read only)
For each Product Pillar, each PRD rule the analysis touched, each integration contract rule, and each accepted ADR, record:
- how it was implemented, and where (`file:line`, from `as-built.md`);
- its classification:
  - **consistent:** built one way, matching the text;
  - **divergent:** built two or more ways, each defensible from the text;
  - **contradictory:** the build contradicts the text, or two texts contradict each other (the PRD and `decisions.md`, the PRD and a contract);
- for an ADR, whether it's still honoured, and where it isn't;
- for anything not consistent, the failure mode in one line: what goes wrong for a user, a tenant or the data. The postmortem checks each one.

Write `resets/YYYY-MM-DD/interpretations.md`, one table per kind (pillars, PRD rules, contract rules, ADRs). Then present the summary to the director: the count per classification, then each divergent or contradictory item in one line, security findings first.

## 3. Rewrite the design (the director decides)
1. **Archive first.** Copy `product/prd.md` to `resets/YYYY-MM-DD/prd-before.md` before changing anything.
2. **One design call per divergent or contradictory item,** following `design.md` › For each question: surface the context (the text, the related decisions, and each interpretation found with where it lives), offer 2-4 options with a recommendation, and say the director can write their own answer instead. Prefer the option that keeps most of the system as built, unless it strains a pillar. Wait for each answer.
   - An ADR not honoured, or a framework rule in the way: stop and follow `architect.md`. Complying is option one; a new ADR stays proposed until the director accepts it.
   - A pillar in question: ask which gives way, the pillar or the implementation.
3. **Record** only the director's choices, following `design.md` › Record each decision: rewrite the PRD sections as the current requirements, append one line per choice to `product/decisions.md` with `from: resets/YYYY-MM-DD`, turn follow-up questions into `Q<n>`, and update `integrations/<system>/contract.md` where a choice changes one.
4. **Hooks.** If a hook asks the director to confirm an edit (an ADR's status, a framework-owned file), let it ask; never bypass or work around one. If the director declines, write the change as a proposal in the reset folder (`resets/YYYY-MM-DD/proposal-<file>.md`) and ask them to apply it.

## 4. Plan the rebuild (no code)
Compare the approved design with `as-built.md`. For every place the system differs, add items to TASKS.md in the format in `.satt/tasks.md`: a Size, `Depends on`, `Touches` naming the exact files the item may change, tagged `Done when` outcomes, `PRD:` the heading, and `ADR:` where one applies.
- Security findings from step 1 come first, as `high` bugs with `Found in: resets/YYYY-MM-DD/as-built.md`.
- Then contracts and stored schemas, then the rest as slices: contract, then domain and application, then the host, then the client.
- Split anything `L` or bigger, as `.satt/tasks.md` › Size says.
- Last, a `human` item: "Run the drift-reset postmortem", depending on all the others.

## Finish
- Summarise what was decided, what's still open, the items created, and the first one.
- Commit the reset folder and the records as `docs: drift reset YYYY-MM-DD` after the director approves. Merge the reset branch the way the director usually does.
- Tell the director to start the rebuild with `next-task.md` in a fresh session (in Claude Code: `/clear`, then `/next-task`). The reset folder and the records hold everything.

## Postmortem
Runs when the director asks (`drift-reset postmortem`), after the reset's items are done. Use the latest reset folder unless the director names one.
1. Check the reset's items are `done` (TASKS.md or `TASKS-archive.md`). If some aren't, list them and ask whether to go on.
2. For each failure mode in `interpretations.md`, check the rebuilt system: fixed (with `file:line`), still present, or moved elsewhere. Repeat step 1's tenancy and identity analysis for the areas the rebuild touched.
3. Write `resets/YYYY-MM-DD/postmortem.md`: per failure mode, the outcome, why the drift happened (an ambiguous rule, a missing decision, a missing check), and what would have caught it sooner.
4. **Turn repeated judgment into checks.** For each drift a script could catch next time, propose a rule as a design call: 2-4 options with a recommendation, and the director decides. A rule for this project goes in its `tools/check.local.sh`. A rule every project would need is a framework gap, for SaaSAllTheThings upstream (`architect.md` › Prepare). Never change the framework's check or relax a limit in `tools/check.cfg` to add one. Each agreed rule becomes an item.
5. Commit as `docs: drift reset postmortem YYYY-MM-DD` after the director approves.
