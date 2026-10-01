# Changelog

Each entry lists what changed. An entry that requires changes to an app's own files (AGENTS.md, TASKS.md, the PRD, `tools/check.cfg`) ends with **Upgrade steps**, which onboarding carries out during an upgrade.

## 0.1.0 (2026-10-01)

The first version: Claude4Godot 2.0's workflow (records, procedures, the check, hooks, the installer) rebuilt for multi-tenant SaaS on Azure, with an architecture the framework owns.

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
