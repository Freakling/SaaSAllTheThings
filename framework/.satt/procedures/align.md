<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Align

A consistency pass across the PRD, decisions, ADRs, integration contracts, TASKS.md, AGENTS.md, settings and code. Check everything below, fix what's mechanical, and list what needs the human, with a recommendation for each. Never change the product or the architecture.

1. **Placeholders.** No `{{…}}` left in AGENTS.md, TASKS.md, `product/`, `integrations/` or `validation/TEMPLATE.md`, or in `tools/check.cfg` (`git grep -n "{{" -- AGENTS.md TASKS.md product integrations validation/TEMPLATE.md tools/check.cfg`). The template's capability sections may wait until the first capabilities are decided, but only if an item for filling them exists.
2. **Entry files.**
   - AGENTS.md points to `.satt/rules.md`.
   - In Claude Code, CLAUDE.md contains `@AGENTS.md`.
   - No `*.satt-new` files are left unmerged: `git ls-files -o -i --exclude-standard -- '*.satt-new'`.
3. **Items.**
   - IDs are unique and below `Next IDs`, and every `Depends on` exists, in TASKS.md or the archive.
   - No `done` item depends on a `todo` one.
   - Every `agent` item has a Size, `Touches`, tagged `Done when` outcomes (or a Repro, for bugs) and a `PRD:` value. That value is an existing heading, or `—` for items that aren't about the product.
   - Every `Q<n>` an item names is still in Open Questions. If it's been answered, update the item.
   - Every `ADR:` an item names exists.
   - Items follow `.satt/tasks.md`.
   - Report `in-progress` items claimed before today.
4. **Coverage.** Every rule in PRD › Capabilities is either built (a done item), planned (a todo item), or reported to the human as a gap. Only report the gaps; the human decides which ones become items.
5. **Architecture.**
   - Every project or package in the solution, and every function app, has a row in AGENTS.md › Architecture, and every row points at something that exists.
   - AGENTS.md › Layout matches `tools/check.cfg` › `[layers]`.
   - `bash tools/check.sh --architecture` passes, and its notes list no stale ADR exceptions and no proposed ADR waiting for longer than a week. Report the count of source files outside any layer; for an existing app each area of them has an Extract item.
   - Every accepted ADR with a temporary deviation has its removal item.
6. **Decisions.** Spot-check that recent lines in `product/decisions.md` are reflected in the PRD and the integration contracts, and that no older text contradicts them. Report workshop notes in `assessment/workshops/` that have no `Processed:` line.
7. **Undecided values.** Count them with `git grep -n "PLACEHOLDER" -- src infra clients`, and report the number with the files.
8. **Setup.**
   - `bash tools/check.sh` passes and prints no `note:` about the hook or the toolchain.
   - The `.gitignore` and `.gitattributes` lines that install.sh adds are still there. If any are missing, rerun the installer.
9. **Report.** Say what you fixed and what needs the human. Commit the fixes as `docs: align` after the human approves; during onboarding they go into the install commit instead.
