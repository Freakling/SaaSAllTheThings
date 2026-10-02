# Changelog

Each entry lists what changed. An entry that requires changes to an app's own files (AGENTS.md, TASKS.md, the PRD, `tools/check.cfg`) ends with **Upgrade steps**, which onboarding carries out during an upgrade.

## Unreleased

- The README has a Ko-fi support button, at the top of "How to use it".

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
- **`procedures/assess.md`**, with the public skill `saas-assessment` (works before installing: it clones this release) and the in-project skill `/assess`. It analyses an existing app without changing it, asks the human's stack preference, and writes `assessment/YYYY-MM-DD-assessment.md` from `templates/assessment.md`: readiness scored 0–3 with evidence, the target picture (each component's layer: keep, extract, rebuild or retire), the decisions needed as options, the roadmap by stage with rough effort ranges and their confidence, risks, and the workshops to hold.
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
