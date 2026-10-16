<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Align

A consistency pass across the PRD, decisions, ADRs, integration contracts, TASKS.md, AGENTS.md, settings and code. Check everything below, fix what's mechanical, and list what needs the human, with a recommendation for each. Never change the product or the architecture.

1. **Placeholders.** No `{{…}}` left in AGENTS.md, TASKS.md, `product/`, `integrations/` or `validation/TEMPLATE.md`, or in `tools/check.cfg` (`git grep -n "{{" -- AGENTS.md TASKS.md product integrations validation/TEMPLATE.md tools/check.cfg`). The template's capability sections may wait until the first capabilities are decided, but only if an item for filling them exists.
2. **Entry files.**
   - AGENTS.md points to `.satt/rules.md`.
   - In Claude Code, CLAUDE.md contains `@AGENTS.md`.
   - No `*.satt-new` files are left unmerged: `git ls-files -o -i --exclude-standard -- '*.satt-new' | grep '\.satt-new$'` (the grep drops nested clones, which `ls-files` lists as directories).
3. **Items.**
   - IDs are unique and below `Next IDs`, which has a counter for each of `T`, `B` and `R` (add `· R1` to a line that lacks one), and every `Depends on` exists, in TASKS.md or the archive.
   - No `done` item depends on a `todo` one.
   - Every `agent` item has a Size, `Touches`, tagged `Done when` outcomes (or a Repro, for bugs) and a `PRD:` value. That value is an existing heading, or `none` for items that aren't about the product. A research item has a Size, a `Question:`, an `Informs:` and a `PRD:` value instead, and no `Touches`.
   - Every `Q<n>` an item that isn't done names, in `Done when` or `Informs:`, is still in Open Questions. If it's been answered, update the item.
   - Every `ADR:` an item names exists.
   - Every done research item has a note in `product/research/` whose second line starts with its ID (`grep -l "^R3 · " product/research/*.md`).
   - Items follow `.satt/tasks.md`.
   - Report `in-progress` items claimed before today.
4. **Coverage.** Every rule in PRD › Capabilities is either built (a done item), planned (a todo item), or reported to the human as a gap. Only report the gaps; the human decides which ones become items.
5. **Architecture.**
   - Every project or package in the solution, and every function app, has a row in AGENTS.md › Architecture, and every row points at something that exists.
   - AGENTS.md › Layout matches `tools/check.cfg` › `[layers]`.
   - `bash tools/check.sh --architecture` passes, and its notes list no stale ADR exceptions and no proposed ADR waiting for longer than a week. Report the count of source files outside any layer; for an existing app each area of them has an Extract item.
   - Every accepted ADR with a temporary deviation has its removal item.
6. **Brief against reality.** For this step only, read the whole PRD and the ADRs, not sections by heading.
   - Read `product/prd.md` and each ADR in `adr/` from its first line to its last.
   - For every statement of state, check it against what exists: the built system (its code, infrastructure and clients), the done items (`TASKS.md` and `TASKS-archive.md`) and, where the project tracks them, the latest releases (the deploys to `dev` and `prod`; `prod` deploys from a tag, and its contents are the done items since the last tag; see `release.md`). A statement of state is a section marked later or planned, a count, a list of what exists, a line saying work waits on something, and "once X exists". Fix a stale statement as mechanical drift when the fact is settled (the item is done, the page exists). Report it to the human when the fix is a design call.
     - An ADR's status is a statement of state too: an `accepted` ADR's Decision is in the code or infrastructure, or an open item builds it; a `proposed` ADR that the code already follows is stale; and `superseded by ADR-<m>` names an ADR that exists.
   - Check every line added to `product/decisions.md` since the last `docs: align` commit (`git log --grep="^docs: align"` for the last one; all lines if there is none) against the PRD, the ADRs and the integration contracts, one by one and not a sample. Each is reflected in them, and no older text contradicts it.
   - Report what was fixed and what needs the human, naming each stale statement, so the next align can tell a repeat.
   - Report workshop notes in `assessment/workshops/` that have no `Processed:` line.
7. **Undecided values.** Count them with `git grep -n "PLACEHOLDER" -- src infra clients`, and report the number with the files.
8. **Setup.**
   - `bash tools/check.sh` passes and prints no `note:` about the hook or the toolchain.
   - The `.gitignore` and `.gitattributes` lines that install.sh adds are still there. If any are missing, rerun the installer.
9. **Report.** Say what you fixed and what needs the human. Recommend a drift reset (`drift-reset.md`) when a conflict you report has come up before (an earlier `docs: align` commit, a `product/decisions.md` line or a `resets/` folder about the same rule), or when one conflict involves several pillars or principles. Only recommend it: the director decides whether to start one. Commit the fixes as `docs: align` after the human approves; during onboarding they go into the install commit instead.
