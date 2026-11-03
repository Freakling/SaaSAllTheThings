<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Align

A consistency pass across the PRD, decisions, the user stories, ADRs, integration contracts, TASKS.md, AGENTS.md, settings and code. Check everything below, work out the fixes that are mechanical, and list what needs the human, with a recommendation for each. The fixes are part of the summary in Report: write one only after the human approves. Never change the product or the architecture.

1. **Placeholders.** No `{{…}}` left in AGENTS.md, TASKS.md, `product/`, `integrations/` or `validation/TEMPLATE.md`, or in `tools/check.cfg` (`git grep -n "{{" -- AGENTS.md TASKS.md product integrations validation/TEMPLATE.md tools/check.cfg`). The template's capability sections may wait until the first capabilities are decided, but only if an item for filling them exists.
2. **Entry files.**
   - AGENTS.md points to `.satt/rules.md`.
   - In Claude Code, CLAUDE.md contains `@AGENTS.md`.
   - No `*.satt-new` files are left unmerged: `git ls-files -o -i --exclude-standard -- '*.satt-new' | grep '\.satt-new$'` (the grep drops nested clones, which `ls-files` lists as directories).
3. **Items.**
   - IDs are unique and below `Next IDs`, which has a counter for each of `T`, `B` and `R` (the fix for a line that lacks one adds `· R1`), and every `Depends on` exists, in TASKS.md or the archive.
   - No `done` item depends on a `todo` one.
   - Every `agent` item has a Size, `Touches`, tagged `Done when` outcomes (or a Repro, for bugs) and a `PRD:` value. That value is an existing heading, or `none` for items that aren't about the product. A research item has a Size, a `Question:`, an `Informs:` and a `PRD:` value instead, and no `Touches`.
   - Every `Q<n>` an item that isn't done names, in `Done when` or `Informs:`, is still in Open Questions. If it's been answered, the fix updates the item.
   - Every `ADR:` an item names exists.
   - Every done research item has a note in `product/research/` whose second line starts with its ID (`grep -l "^R3 · " product/research/*.md`).
   - Items follow `.satt/tasks.md`.
   - Report `in-progress` items claimed before today.
4. **Coverage.** Every rule in PRD › Capabilities is either built (a done item), planned (a todo item), or reported to the human as a gap. Only report the gaps; the human decides which ones become items.
5. **Stories** (`product/user-stories.md`, `design.md` › User stories).
   - Story IDs are unique and below the header's Next ID, and the header has a Last validated line (the fix for a missing one adds it as `never`).
   - Every story's role is in the file's Roles and a persona in PRD › Personas and Roles, every capability in PRD › Capabilities has a `Stories:` line, and every ID named in a capability's `Stories:` line, or in the `Stories:` line of an item that isn't done, exists in the file. Report the ones that don't.
   - Every `agent` item that isn't done, other than a research item, has a `Stories:` line. The fix for a `T` item whose `PRD:` is `none` adds `- Stories: none`; the others are reported below.
   - Report to the human, with a recommendation for each:
     - **stories no item serves:** no item in TASKS.md or TASKS-archive.md names them in `Stories:`. Leave out the range the file's line `US-1 to US-<n> were written from the code on <date>, before the app kept user stories.` names. Recommend an item, or dropping the story;
     - **feature items with no story:** `T` items that aren't done whose `PRD:` names a heading but whose `Stories:` is `none` or missing (bugs are left out). Leave out a `none` the human confirmed in an earlier `docs: align` commit body. Recommend the story to draft, or confirming that `none` is right;
     - **bugs with no story:** `B` items that aren't done and have no `Stories:` line, security bugs included. Recommend the story whose behaviour each restores, or `none`;
     - **stories unconfirmed past the cadence:** when `bash tools/stories.sh --due` says `due`, every story still `unconfirmed`. Recommend a validation (`design.md` › Validate the stories).
6. **Architecture.**
   - Every project or package in the solution, and every function app, has a row in AGENTS.md › Architecture, and every row points at something that exists.
   - AGENTS.md › Layout matches `tools/check.cfg` › `[layers]`.
   - `bash tools/check.sh --architecture` passes, and its notes list no stale ADR exceptions and no proposed ADR waiting for longer than a week. Report the count of source files outside any layer; for an existing app each area of them has an Extract item.
   - Every accepted ADR with a temporary deviation has its removal item.
   - If `compliance/mapping.md` exists, report each row whose Met by names a rule id (not in `tools/archcheck.awk`), a workflow job (not in `.github/workflows/check.yml`), an `ADR-NNNN` (no such file in `adr/`) or a test path that no longer exists, and each row labelled `direct` whose Met by is `none yet`. Report them; the human decides whether to fix the row or restore what it names. Never mark a control met.
   - Report a removed baseline row: each of the ten OWASP Top 10 (2025) rows of the source's seed `compliance/mapping.md` (`OWASP A01` to `OWASP A10`) that the file lacks. A project may not delete them; offer to add the missing rows from the seed, with `none yet` and `unverified` until an architecture session fills them.
7. **Brief against reality.** For this step only, read the whole PRD and the ADRs, not sections by heading.
   - Read `product/prd.md` and each ADR in `adr/` from its first line to its last.
   - For every statement of state, check it against what exists: the built system (its code, infrastructure and clients), the done items (`TASKS.md` and `TASKS-archive.md`) and, where the project tracks them, the latest releases (the deploys to `dev` and `prod`; `prod` deploys from a tag, and its contents are the done items since the last tag; see `release.md`). A statement of state is a section marked later or planned, a count, a list of what exists, a line saying work waits on something, and "once X exists". A stale statement is a mechanical fix for the summary when the fact is settled (the item is done, the page exists). Report it to the human when the fix is a design call.
     - An ADR's status is a statement of state too: an `accepted` ADR's Decision is in the code or infrastructure, or an open item builds it; a `proposed` ADR that the code already follows is stale; and `superseded by ADR-<m>` names an ADR that exists.
   - Check every line added to `product/decisions.md` since the last `docs: align` commit (`git log --grep="^docs: align"` for the last one; all lines if there is none) against the PRD, the ADRs and the integration contracts, one by one and not a sample. Each is reflected in them, and no older text contradicts it.
   - Report what the fixes change and what needs the human, naming each stale statement, so the next align can tell a repeat.
   - Report workshop notes in `assessment/workshops/` that have no `Processed:` line.
8. **Undecided values.** Count them with `git grep -n "PLACEHOLDER" -- src infra clients`, and report the number with the files.
9. **Setup.**
   - `bash tools/check.sh` passes and prints no `note:` about the hook or the toolchain.
   - The `.gitignore` and `.gitattributes` lines that install.sh adds are still there (among them `/product/ui/captures/`, `/tools/ui/node_modules/` and `/tools/ui/.auth/`). If any are missing, the fix is to rerun the installer once the summary is approved.
10. **Screens** (skip it when the product has no `tools/ui/screens.mjs`). Report what is missing; none of it fails the pass. The first two need Node; without it, say they weren't checked.
    - `bash tools/ui_capture.sh --missing` lists the client files (`tools/check.cfg` › `[layers]` › `client`) that look like screens, with no catalog entry naming them as its `source` and not in `tools/ui_capture.cfg` › `[capture] skip`. With no client patterns set it says so, and nothing is listed.
    - Every `product/ui/<screen>.md` names a catalog entry that exists, and every name its Layout table lists is in the source: `node tools/ui/verify.mjs <screen> --static` prints where each is found (it exits 3 by design: no capture).
    - Every `director/ui/<screen>.excalidraw` has a spec whose recorded sha1 matches the file (`sha1sum`, or `shasum` on macOS). A newer drawing: report "drawing changed since it was processed".
    - Every item's `UI:` points at an existing spec.
    - On an upgrade, this is the check that lists the product's screens the catalog doesn't cover yet.
11. **Report.** Say what needs the human, and list the mechanical fixes before they are written, each as it will read. Write nothing until the human approves a summary of all of it (`design.md` › Summary and approval); a chat message or an "Other" answer before then re-opens the options. Inside a session the fixes join its summary; during onboarding they are approved at `ONBOARDING.md` › 10 (Verify, commit, hand off) and go into the install commit. Recommend a drift reset (`drift-reset.md`) when a conflict you report has come up before (an earlier `docs: align` commit, a `product/decisions.md` line or a `resets/` folder about the same rule), or when one conflict involves several pillars or principles. Only recommend it: the director decides whether to start one. Once the human approves, write the fixes and commit them as `docs: align`; the approval of the summary is the approval to commit.
