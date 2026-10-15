# Changelog

Each entry lists what changed. An entry that requires changes to an app's own files (AGENTS.md, TASKS.md, the PRD, `tools/check.cfg`) ends with **Upgrade steps**, which onboarding carries out during an upgrade.

## Unreleased

- **New: `/research`, the research assistant** (`procedures/research.md`). When a product or architecture question depends on facts nobody has checked, or you ask for research, a read-only `researcher` subagent looks into it in a fresh context and reports a note. It informs; you decide: its recommendation is one option shown with its reason, and it never records a decision, edits the PRD, `product/decisions.md` or an ADR, answers an open question, accepts an ADR, or asks you anything. It states its assumptions in the note instead.
  - **Research is a task type.** Research items get their own IDs, `R<n>`, drawn from the `Next IDs` line like bugs. Instead of `Done when` they have `Question:` and, when they feed an open question, `Informs: Q<n>`. They are sized like any item, and the size picks the model. An item is done when its note exists.
  - **Two ways to start.** On the fly: a product or architecture session delegates a complex question, or you run `/research <question>`, and the item is created and run at once. For later: queue the item, and list it under `Depends on` of the tasks that need its findings. A task that needs the decision stays gated by the open question itself.
  - **`/next-task` hands research items to the `researcher`.** No check runs and no review: research changes no code. This session writes the note to `product/research/YYYY-MM-DD-<slug>.md` and commits it with the records. A finished item that informs `Q<n>` makes that question ready for a product or architecture call, and a run goes on to the next item.
  - **Product and architecture sessions** list `product/research/` first, show notes on the topic in the context brief, delegate a question that needs facts, and link the note afterwards: the decision line's `why` ends with its path, and the ADR's Context does.
  - **The note** is one dated file per topic: the conclusion first, the options and trade-offs, the recommendation, every claim with its source, source tier and confidence, the date the claims were verified, and what stays unknown.
  - **A domain file** (`.satt/research-domain.md`) is read when the question touches Azure, the reference architecture, the customer's security framework or an architecture decision. It sets out Azure first when Azure is central (current Microsoft guidance as input, never as the answer), the reference architecture's authority (a deviation starts with "comply"; costs start from `reference/cost.md`), the customer's security framework as a binding source (each requirement traced to a control and labelled direct, partial, interpretive or unverified, with the shared-responsibility boundary named), an ADR-ready summary for a significant decision, and a checklist for architecture questions.
  - **Confidentiality.** Project text, customer and tenant names, requirements, integration contracts and resource identifiers never go into a public search query or fetch.
  - **The researcher** has `Read`, `Grep`, `Glob`, `WebSearch` and `WebFetch`: no edit, write or shell tool. `.claude/settings.json` allows web search and fetch; Claude Code can't scope a permission to one subagent, so the allow applies to every session in the app, and the researcher's own tool list is the restriction. Everything with side effects keeps asking.
- **Align** checks that `Next IDs` has an `R` counter, that research items have a `Question:` and an `Informs:` instead of `Touches` and `Done when`, and that each done research item has its note.
- **The design-session skill** (`saas-design-session`) doesn't carry the research procedure, because the Claude apps have no subagents and no app folder to hold notes. Its bundled `rules.md`, `tasks.md`, `design.md` and `architect.md` are refreshed, and its `SKILL.md` says what to do where a procedure says to research first: check one fact yourself, otherwise make the missing facts open questions or ask.
- **Selftest** checks that the research files exist and are wired into the procedures, the item format, the seeds and the docs, that the researcher has no edit, write or shell tool, that only `permissions.allow` lists web search and fetch, that the installer ships everything (including with `--tools none`), that a research note commits without running the check, and that the design-session skill leaves the procedure out and says so.
- **The example** (`examples/order-desk`) shows the `R` counter and the note folder, and the scenarios gain three for research.

**Upgrade steps**

1. **TASKS.md:** add an `R` counter to the `Next IDs` line, so `**Next IDs:** T12 · B3` becomes `**Next IDs:** T12 · B3 · R1`.
2. **`product/research/`:** the installer creates the folder with a short `README.md` (a project file, yours from then on) when the app doesn't have it. Notes are added there as research runs; commit them like the other records.
3. `.claude/settings.json` is framework-owned, so it is replaced on upgrade. If you edited it, the new version arrives as `.claude/settings.json.satt-new`; merge it, and make sure `"WebSearch"` and `"WebFetch"` are in `permissions.allow`, which lets the researcher read the web without asking each time. Restart Claude Code afterwards so the new skill, subagent and permissions load.

No other app-owned file changes are required.

## 0.7.0 (2026-10-15)

- **README: "Part of Director-Driven Development".** A new section after the opening description places SaaSAllTheThings among the three Director-Driven Development frameworks (Godot-Director, App-Director, SaaSAllTheThings), and links the step-by-step guide to building a B2B SaaS on Azure with it.
- **The upgrade-file check ignores nested clones.** `git ls-files` lists a nested repository in an ignored folder (such as a clone in `work/`) as a directory, which blocked every commit while no upgrade file existed. The pre-commit hook, the `/align` check and onboarding now keep only paths that end in `.satt-new`, so a real upgrade file still blocks the commit.
- **selftest.sh** checks that a nested clone in an ignored folder doesn't block a commit, and that a real upgrade file still does.
- **selftest.sh skips .NET without an SDK.** A machine with the .NET runtime host but no SDK has `dotnet` on its PATH, so the self-test ran the .NET checks and three of them failed. It now skips the .NET part unless `dotnet --list-sdks` lists an installed SDK, with the same message as a machine without dotnet. Where an SDK is installed, the .NET part runs as before.
- **One commit model, shared with App-Director and Godot-Director.** One task, one commit, with the pre-commit check as the gate.
  - **A single `/next-task` pauses for your approval** of its commit (`next-task.md` step 7).
  - **A run commits without pausing.** `/next-task` now has a run mode, which it had no wording for before. When you ask for one ("grab tasks until you're blocked", "work through the queue", "the next N tasks"), each task commits as soon as its check passes. The run stops when an item is blocked on you, a build fails, or you decline a commit, and the final report lists every commit. A run approves commits in advance, not pushes, deploys or changes to cloud resources.
  - **`git commit` is allowed in `.claude/settings.json`** (it used to ask every time). `git push`, rebasing, restoring, `git config` and the `az` and `azd` commands listed under `ask` still ask, and skipping the check with `--no-verify` is still denied.
  - `rules.md` › Git and Azure says so; the `/next-task` skill description and the README's day-to-day table name the new phrase; the scenarios gain one for a run. The bundled copy of `rules.md` in `saas-design-session` is refreshed.

**Upgrade steps:** none to your own files. `.claude/settings.json` is framework-owned, so it is replaced on upgrade. If you edited it, the new version arrives as `.claude/settings.json.satt-new`; merge it, and make sure `Bash(git commit *)` is in `permissions.allow` and no longer in `permissions.ask` (an `ask` entry wins over `allow`, so the old entry would keep the prompt). Restart Claude Code afterwards so the changed skill description and permissions load.

## 0.6.0 (2026-10-09)

- **`/drift-reset`, the design drift reset** (`procedures/drift-reset.md`). When a design principle has been built in more than one way, patching makes it worse; the reset guides the director through a structured redo instead. Align often, reset when you have to.
  - **Only the director starts it.** The Claude Code skill sets `disable-model-invocation: true`, so the assistant can't start it on its own; `/align` may only recommend it.
  - **As built (read only):** one read-only analysis per area in a fresh context, with tenancy and identity always its own area, since drift there is a security finding. Writes `resets/YYYY-MM-DD/as-built.md` with `file:line` evidence.
  - **Interpretations (read only):** each pillar, PRD rule, contract rule and accepted ADR classified as consistent, divergent or contradictory, with its failure mode, in `interpretations.md`.
  - **Rewrite the design:** one design call per split item, as in `/design`, with room for the director's own answer. The old PRD is archived as `prd-before.md`; only the director's choices reach `decisions.md`. Accepted ADRs are never dropped without a new ADR, and framework rules (tenancy, identity, cost, the check) are out of scope: a real conflict goes through `/architect`.
  - **Plan the rebuild:** sized TASKS.md items with exact `Touches`, security bugs first. No application code; the rebuild runs through `/next-task`.
  - **`/drift-reset postmortem`:** checks each failure mode after the rebuild, writes `postmortem.md`, and proposes checks for `tools/check.local.sh` as design calls, so repeated judgment turns into checks.
- **`/align`** recommends a drift reset when a conflict has come up before, or one conflict involves several principles.
- `rules.md` lists the procedure and gives `resets/` its row in "Each fact lives in one place". README, ONBOARDING and the behaviour scenarios document it; the README's procedure list says `design` instead of the old `product`.
- **`selftest.sh`** asserts that `align.md` points to the reset and that the skill can only be started by the human.

**Upgrade steps:** none. Framework files are replaced on upgrade; `resets/` is created by the first reset.

## 0.5.6 (2026-10-09)

- **Integration session context surfaced to the director.** `integrate.md` › Work out the contract now instructs the session to quote or summarise the relevant guidance from `integrations.md` (including the Navision table) and the current contract value before offering options on each round.

**Upgrade steps:** none. Framework files are replaced on upgrade.

## 0.5.5 (2026-10-09)

- **Architecture session context surfaced to the director.** `architect.md` › Propose now has a first step that quotes or summarises the reference rule in question, the classification (open choice, deviation, gap or requirements conflict), and the title and status of any related ADRs before offering options.

**Upgrade steps:** none. Framework files are replaced on upgrade.

## 0.5.4 (2026-10-09)

- **Design session context surfaced to the director.** `design.md` › For each question now has a first step that quotes or summarises the applicable Product Pillars, the current PRD rule, and any related line from `decisions.md` before offering options. The director sees the full picture before choosing, not just the options.

**Upgrade steps:** none. Framework files are replaced on upgrade.

## 0.5.3 (2026-10-07)

- **En and em dashes removed throughout.** Every en dash (U+2013) and em dash (U+2014) replaced by its contextual equivalent: a hyphen for ranges (`1-3`, `2-4`), a colon or comma for asides, and parentheses for parentheticals. `selftest.sh` now asserts the count is zero. `.claude/CLAUDE.md` adds the typography rule for future edits.
- **Project seeds updated.** `AGENTS.md` Layout table, `TASKS.md` field values and human item headings, `product/prd.md` comment, and `validation/TEMPLATE.md` now use hyphens in place of dashes.

**Upgrade steps:**
- In your `AGENTS.md` Layout table, any empty "Layer" cell written as an em dash becomes `(none)`.
- In `TASKS.md`, field values written as a single em dash (`Depends on`, `PRD`, `Touches`) become `none`; human item headings with the size written as an em dash become `none`.
- In `product/prd.md` and `validation/TEMPLATE.md`, replace en dashes in numeric ranges with hyphens (`1-5`, `3-6`, `3-5`).
- Framework files are replaced on upgrade: no manual changes needed there.

## 0.5.2 (2026-10-07)

- **Model sizing aligned to canonical spec.** `rules.md` is now tool-neutral: the capability-tier description (XS/S → smallest capable, M → balanced, L/XL → most capable) replaces the Claude Code model IDs that were there. The default model IDs now live in exactly one place: `procedures/refresh-model-sizing.md` § Propose defaults. `ONBOARDING.md` step 8 reads the defaults from there instead of duplicating them. `README.md` model sizing paragraph updated to the canonical wording (adds session-model fallback and escalation note).
- **Escalation extended through L.** A failed build now retries once on the next size's model all the way up (XS→S, S→M, M→L, L→XL); only an XL failure stops and comes to the director. Previously only XS and S escalated.
- **`refresh-model-sizing` fable note corrected:** `claude-fable-5-1` listed as XL-only alternative (was L and XL).
- **`selftest.sh`** gains two assertions: default model IDs in `ONBOARDING.md` match `refresh-model-sizing.md`; `README.md` contains the canonical model sizing wording.

**Upgrade steps:**
- Run `/refresh-model-sizing` to update your AGENTS.md › Project rules block to the current defaults. Framework files (`rules.md`, `next-task.md`, `refresh-model-sizing.md`) are replaced on upgrade: no hand-editing needed.

## 0.5.1 (2026-10-07)

- **Model sizing corrected to five independent entries.** The two-tier rule (XS/S → smallest, M/L/XL → session model) was wrong: M, L and XL all ran on the same model regardless of complexity. `rules.md` now defines one model ID per size; for Claude Code the defaults are Haiku for XS+S, Sonnet for M, and Opus for L+XL. `next-task.md` reads the per-size entry and falls back to the session model if none exists. Escalation (XS→S, S→M) now uses the model mapped to the new size.
- **`/refresh-model-sizing` skill and procedure** (`procedures/refresh-model-sizing.md`): checks whether the tool can spawn a subagent with a chosen model (capability check: Claude Code: yes; if the tool cannot: skip), proposes the five defaults, and writes or updates the block in AGENTS.md › Project rules.
- **Onboarding step 8** updated: does the capability check inline, writes the full five-entry block for Claude Code (or skips for unsupported tools), mentions `/refresh-model-sizing` for later updates.
- **AI assistant support statement aligned.** All mentions unified to one position: designed to work with any assistant that reads AGENTS.md, built and tested on Claude Code only. Hedges ("supported in principle", "should work") and competitor names removed from user-facing text. Capability note added to the README "With another AI assistant" section. `CLAUDE.md` release-notes rule updated to include the canonical wording in "How to install".

**Upgrade steps:**
- Replace the `Model sizing: on` / `Model sizing: off` line in AGENTS.md › Project rules with the five-entry block. Run `/refresh-model-sizing` to do this: it will check capability and propose the defaults.

## 0.5.0 (2026-10-07)

- **Role terminology aligned.** The main session is now called the **orchestrator** throughout (was "designer", "designer and orchestrator", "designer/orchestrator"). The builder subagent is now called the **builder** (was "developer with a fresh context"). The human role is now called the **director** in role descriptions and Who-decides sections (was "the human"). Design as an activity (design sessions, design calls, design documents, `/design`) is unchanged.
- **`/product` renamed to `/design`.** The procedure `procedures/product.md` is renamed to `procedures/design.md`, and the skill folder `framework/.claude/skills/product/` is renamed to `framework/.claude/skills/design/`. All cross-procedure references updated. `/product` remains as a deprecated alias skill for one minor version; it redirects to `design.md`.

**Upgrade steps:**
- Run `/refresh-model-sizing` if not done (from 0.4.0).
- `project/` seeds updated: existing `AGENTS.md` files may keep the old role terms ("the human", "designer", "developer"); updating them is optional.
- `/product` is deprecated; use `/design` instead.

## 0.4.0 (2026-10-05)

- The README has Ko-fi and GitHub Sponsors buttons, at the top of "How to use it", and `.github/FUNDING.yml` turns on GitHub's Sponsor button for the repository.
- **README "Context and token use"**: full breakdown of the designer/orchestrator, builder and reviewer roles; a sequenceDiagram of the handoff loop; design-session clear-after-commit note; and model sizing summary. Replaces the earlier "How builds stay small" stub.
- **`architect.md`: industry best practices and requirements documents.** The Prepare step now reads product requirements from `product/requirements/` and security/compliance requirements from `compliance/` before proposing options, and flags any conflict between a requirement and the architecture. The Propose step now evaluates every option against a standing set of industry best practices (OWASP Top 10, least privilege, defence in depth, zero trust, data minimisation, and any standard named in the compliance requirements) and prefers the option with the stronger security and compliance posture.
- **`XS` and `XL` sizes** added to the task size ladder (`tasks.md`): `XS` for a single value, label, config line, copy change or comment (no logic, no tests); `XL` for a cross-cutting refactor, full subsystem redesign or migration touching 4+ layers. Split `XL` before building.
- **Model sizing recommended on** (was: off by default). The rule is now tool-neutral (`rules.md` › Reviews and model size): `XS` and `S` build on the smallest capable model, `M` through `XL` on the session model. An `XS` that fails escalates to `S`; an `S` escalates to `M`. Onboarding now asks every project whether to enable model sizing and recommends yes.
- **`rules.md` review trigger** updated to include `XL` items (was: `L` only).
- **Upgrade path fast/full choice** (`ONBOARDING.md` step 2): onboarding now summarises the changelog changes to the human before an upgrade, then asks Fast (carry out upgrade steps, recommended) or Full (re-run all content steps as a thorough re-install). The contract for all future CHANGELOG entries: every "Upgrade steps" block must bring existing projects to the same capability level as a fresh install.
- **Fresh-session prompt after design commits** (`product.md`, `architect.md`, `saas-design-session` skill): after each commit the Finish step now tells the human to start the next topic in a fresh session (`/clear` in Claude Code, new conversation elsewhere). The PRD, decisions.md, ADRs and TASKS.md hold everything; accumulated conversation history is noise.

**Upgrade steps:**
- In AGENTS.md › Project rules, confirm or set `Model sizing: on` (recommended) or `Model sizing: off`. Ask the human if it isn't already there.

## 0.3.0 (2026-10-02)

### Design sessions anywhere
- **The public skill `saas-design-session`** runs architecture and product sessions, integration contract sessions, and workshops (preparing them, keeping time and scribing live) in Claude Code, Cowork or the Claude apps, with or without the app's repository. In an app with SaaSAllTheThings installed it follows the app's own procedures and writes the records; anywhere else it ends each session with notes in the playbook's format, which "process the workshop notes" (or onboarding) turns into records later.
- **It carries what it argues from:** the rules, the reference architecture, the workshop playbook, the ADR and integration contract templates, and the architect, product and integrate procedures, in its `references/` folder. `bash bundle.sh` writes that copy from `framework/.satt/`, the only source, and the self-test fails when it drifts.
- **Workshop notes can carry ADR drafts** (`workshops/README.md` › Notes), as `ADR-?` with their headings two levels down. Processing the notes numbers each draft and turns it into an ADR, proposed until the human accepts it; onboarding does the same. The notes format also says how a one-to-one session fills in participants and dates, and records a declined deviation as "comply with the reference".
- `architect.md` gives effort on a scale (S, M, L, or person-days for anything bigger), and `reference/cost.md` prices a web front end (Static Web Apps Free), so every client option in `clients.md` has a cost.

## 0.2.2 (2026-10-02)

For the Claude plugin directory's submission:

- `PRIVACY.md`: what SaaSAllTheThings reads, writes and sends (nothing), linked from the README.
- `plugin.json` has a `homepage`, and the directory listing's documentation, support, privacy policy and terms URLs (the terms are the MIT license). Claude Code ignores those four fields; the directory reads them.
- `assess.md` counts contributors without showing the assistant a name or email.

## 0.2.1 (2026-10-02)

For the Claude plugin directory's review:
- The plugin ships no images except its listing icon. The README's picture now lives on the `assets` branch.
- `rules.md` › Git and Azure no longer spells out the Key Vault command it forbids; the command guard still blocks it.
- This repository's own instructions moved from `CLAUDE.md` to `.claude/CLAUDE.md`, where Claude Code still loads them.
- The roadmap skill's trigger phrase lost a leftover from the rename.

## 0.2.0 (2026-10-02)

### Assessment and workshops
- **`procedures/assess.md`**, with the public skill `saas-assessment` (works before installing: it clones this release) and the in-project skill `/assess`. It analyses an existing app without changing it, asks the human's stack preference, and writes `assessment/YYYY-MM-DD-assessment.md` from `templates/assessment.md`: readiness scored 0-3 with evidence, the target picture (each component's layer: keep, extract, rebuild or retire), the decisions needed as options, the roadmap by stage with rough effort ranges and their confidence, risks, and the workshops to hold.
- **The workshop playbook** in `.satt/workshops/`, one file per workshop: vision, capabilities, domain and events (event storming), tenancy and identity, integration (one per system, Navision first), clients, architecture, operations and planning. Each has its purpose, participants by role, preparation, a timed agenda, methods, the decisions to reach and where they're recorded. `workshops/README.md` covers the sequence, sizing for small and large apps, how to run a session, and the notes format.
- **Workshop notes become records:** `assess.md` › Process workshop notes records their decisions in the PRD, ADRs, integration contracts and TASKS.md. Onboarding reuses an assessment and workshop notes instead of asking again; `roadmap.md` starts from the assessment's roadmap; `align.md` reports unprocessed notes.
- The skills' clone no longer prints git's detached-HEAD advice.

## 0.1.0 (2026-10-01)

The first version: a workflow for building a B2B SaaS from scratch, or turning a proof of concept or an existing app into a mature multi-tenant SaaS on Azure, with an architecture the framework owns and enforces.

### Authority
- **The human owns the product; the framework owns the architecture; the AI builds.** The reference architecture is `.satt/reference/`, one topic per file: layers, tenancy, identity, messaging, data, API, clients, integrations, infrastructure, cost, observability, stacks.
- **Deviations are ADRs the human accepts** (`adr/`, procedure `architect.md`). The check accepts a violation only when an accepted ADR names it in an `Exception:` line; proposed ADRs excuse nothing, exceptions for every path are refused, and stale exceptions are reported.
- **A Claude Code authority hook** asks the human before the assistant edits a framework-owned file or writes `Status: accepted` into an ADR.

### The check
- **`tools/archcheck.awk`**, portable awk, enforces the rules `layers`, `domain-purity`, `tenant-source`, `tenant-branching`, `secrets`, `file-size`, `host-size`, `message-version` and `cost-sku`, for C#, VB.NET, F#, TypeScript and JavaScript, Python, Java and Kotlin, Dart, Swift, .NET project files and Bicep. `bash tools/check.sh --architecture` runs it alone in seconds, with no toolchain.
- **Stack profiles** in `tools/stacks/`: `dotnet` (the default), `typescript`, `python`, and `none` (builds and tests from `tools/check.local.sh`).
- Bicep compiles when the CLI is installed. The check never calls Azure or an external system.

### Workflow
- Procedures: `next-task`, `build`, `review`, `roadmap` (the stages of the move to SaaS: extract, foundation, tenancy and identity, first slice, delivery, clients, integrations, second tenant, capabilities), `product`, `architect`, `integrate` (Navision / Business Central first), `tenant`, `acceptance`, `feedback`, `release`, `align`, `prune`.
- Onboarding settles the backend stack with the human: on an existing app it asks for a preference, keeps a compatible stack, and lists the compatible ones otherwise. It records the choice as ADR-1.
- Records: `product/prd.md`, `product/decisions.md`, `adr/`, `integrations/<system>/contract.md`, `TASKS.md` with `(test)`, `(check)` and `(demo)` outcomes, `validation/` for acceptance checks and feedback.
- The command guard also blocks deleting Azure resources, complete-mode deployments, reading Key Vault secrets and creating client secrets.

### Install
- As a Claude Code plugin (`/plugin marketplace add Freakling/SaaSAllTheThings`, then `/saasallthethings:saas-all-the-things`), with the skills CLI (`npx skills add Freakling/SaaSAllTheThings`), or by hand. The skill is self-contained: outside the plugin it clones this release (`v0.1.0`) into a temporary folder and follows `ONBOARDING.md` from there.
