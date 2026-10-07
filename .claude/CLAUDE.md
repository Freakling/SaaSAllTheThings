> **Installing SaaSAllTheThings into an app?** Ignore this file and follow `ONBOARDING.md`. This file is
> only for working on SaaSAllTheThings itself.

# SaaSAllTheThings (the framework itself)

This repository is SaaSAllTheThings, the workflow for building a B2B SaaS from scratch, or turning a working proof of concept or an existing app into a mature, multi-tenant SaaS on Azure. It gets installed into the app's repository; it is not an app.

- **Templates, not instructions.** `framework/` and `project/` are templates. The rules, reference architecture, procedures, skills, agents and settings in them are the product being edited here: they're instructions for apps, not for this repository, so don't follow them while working on the framework. Claude Code shows `framework/.claude/skills` as nested skills; ignore them here.
- **What's where.**
  - `framework/` holds files installed into apps and replaced on upgrade. That's the tool-neutral core (`.satt/`, `tools/`, `.githooks/`, `validation/README.md`) plus one folder per assistant adapter (`.claude/`).
  - `project/` holds seeds, copied once and then owned by the app.
  - `.claude-plugin/` and `skills/` make this repository a Claude Code plugin, and a source of skills for the skills CLI: `saas-all-the-things` runs `ONBOARDING.md`, `saas-assessment` runs `framework/.satt/procedures/assess.md` before an app has the framework, and `saas-design-session` runs design sessions and workshops anywhere, including Cowork and the Claude apps. They must stay self-contained, because the skills CLI copies only a skill's folder: the first two clone this repository at its release tag; `saas-design-session` can't clone in the Claude apps, so it carries a copy of the files it needs in `references/`. `bash bundle.sh` writes that copy from `framework/.satt/`, which stays the only source; never edit the copy.
  - `examples/order-desk` is a small app that uses the workflow; the self-test runs against it.
- **One place per rule.** Workflow rules live in `framework/.satt/rules.md`, and architecture rules in `framework/.satt/reference/` (one topic per file). Each procedure lives in `framework/.satt/procedures/`, and the adapters only point at it. Install and upgrade are in `ONBOARDING.md`. If you find a rule copied into a second file, delete the copy and link to the original.
- **The architecture's rule IDs** (`layers`, `domain-purity`, …) appear in three places that must agree: `reference/README.md` › What the check enforces, `tools/archcheck.awk` (the `rules` list) and `selftest.sh`. A new rule needs all three, and a fault in the self-test that proves it fails.
- **Tool-neutral core.** Nothing in `.satt/`, `tools/` or `.githooks/` may depend on one assistant. Tool-specific behaviour belongs in that tool's adapter folder.
- **After any change:**
  1. If you changed anything in `framework/.satt/`, run `bash bundle.sh`. Then run `bash selftest.sh`. It must pass. Its .NET part runs only where the .NET SDK is installed.
  2. Add the change to `CHANGELOG.md`, with "Upgrade steps" if apps' own files need changing.
  3. For a release, bump `VERSION`, `.claude-plugin/plugin.json`, and in every `skills/*/SKILL.md` `metadata.version` and, where it clones, the `--branch v<version>`, together; the self-test checks that they match. Then tag the release commit `v<version>` and push the tag, since the skill clones it. The GitHub release body has three sections: **What's new** (bullet list from the CHANGELOG entry), **How to install** (the three options, preceded by the canonical support statement: "Designed to work with any AI coding assistant that reads AGENTS.md. Built and tested on Claude Code; other assistants are untested."), and **How to upgrade** (ending with "This release's upgrade steps").
  4. If the change affects what an app's files look like, update `examples/order-desk` too.
- **Scripts** must run in Git Bash on Windows, in macOS bash 3.2 with BSD tools, and on Linux. Use `/usr/bin/find`, `/usr/bin/sort` and `/usr/bin/tar` instead of the Windows programs with the same names. Avoid GNU-only flags, `declare -A` and gawk-only awk (no `match()` with an array, no `{n}` intervals in awk regexes, no `ENDFILE`). Keep process starts few, because they're slow on Windows. Keep files LF (see `.gitattributes`).
