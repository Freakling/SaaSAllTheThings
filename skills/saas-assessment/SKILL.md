---
name: saas-assessment
description: 'Analyse a working proof of concept or an existing app and recommend what it takes to turn it into a mature, multi-tenant B2B SaaS on Azure: a readiness assessment with evidence, the development roadmap by stage with rough effort, and the workshop sessions to hold (vision, capabilities, event storming, tenancy and identity, integrations such as Navision, clients, architecture, operations, planning), with who takes part, the agenda and how to run each. Read-only apart from the report. Use when the user asks to assess an app or proof of concept for SaaS, what it takes to make an app a SaaS, for a SaaS readiness or transformation assessment, a modernisation roadmap, or which discovery workshops to run and how.'
license: MIT
compatibility: 'Needs git and bash (Git Bash on Windows). Outside the Claude Code plugin it downloads the framework from github.com with git clone.'
metadata:
  author: Freakling
  version: 0.5.1
---

The assessment follows a procedure in the SaaSAllTheThings repository, and assesses against its reference architecture. Find that folder, call it `$SATT`, then follow the procedure for the project in the current working directory.

1. **SaaSAllTheThings already installed in the project:** if `.satt/procedures/assess.md` exists, follow it, and stop here.
2. **Installed as the Claude Code plugin:** if `${CLAUDE_PLUGIN_ROOT}/ONBOARDING.md` exists, `$SATT` is `${CLAUDE_PLUGIN_ROOT}`.
3. **Otherwise** (installed with `npx skills add`, which copies only this folder): clone this skill's release into a temporary folder outside the project, and use that. Never clone it into the project.
   ```
   dir="$(mktemp -d)" && git -c advice.detachedHead=false clone -q --depth 1 --branch v0.5.1 https://github.com/Freakling/SaaSAllTheThings.git "$dir/SaaSAllTheThings" && echo "$dir/SaaSAllTheThings"
   ```
   `$SATT` is the folder it prints. If the clone fails (no network, no git), tell the human and stop.
4. Read `$SATT/framework/.satt/procedures/assess.md` and follow it; where it says `.satt/`, read `$SATT/framework/.satt/`. When the report is written, delete a temporary clone.
