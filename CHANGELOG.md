# Changelog

Each entry lists what changed. An entry that requires changes to an app's own files (AGENTS.md, TASKS.md, the PRD, `tools/check.cfg`) ends with **Upgrade steps**, which onboarding carries out during an upgrade.

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
