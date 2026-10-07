---
name: saas-all-the-things
description: 'Build a B2B SaaS from scratch, or turn a working proof of concept or an existing app into a mature, multi-tenant SaaS on Azure, by installing or upgrading the SaaSAllTheThings workflow in the app open in this session: event-driven Azure Functions, OIDC with federated identity, Windows and mobile clients, Navision / Business Central integrations, with an architecture the framework enforces. Use when the user asks to build a SaaS, to turn a proof of concept or an app into a SaaS ("SaaS all the things"), to make an app multi-tenant on Azure, or to install, set up, add or upgrade SaaSAllTheThings.'
license: MIT
compatibility: 'Needs git and bash (Git Bash on Windows). Outside the Claude Code plugin it downloads the framework from github.com with git clone.'
metadata:
  author: Freakling
  version: 0.5.3
---

SaaSAllTheThings installs from its own repository: `ONBOARDING.md`, `install.sh` and the framework files beside them. Find that folder, call it `$SATT`, then follow `$SATT/ONBOARDING.md` for the project in the current working directory.

1. **Installed as the Claude Code plugin:** if `${CLAUDE_PLUGIN_ROOT}/ONBOARDING.md` exists, `$SATT` is `${CLAUDE_PLUGIN_ROOT}`.
2. **Otherwise** (installed with `npx skills add`, which copies only this folder): clone this skill's release into a temporary folder outside the project, and use that. Never clone it into the project.
   ```
   dir="$(mktemp -d)" && git -c advice.detachedHead=false clone -q --depth 1 --branch v0.5.3 https://github.com/Freakling/SaaSAllTheThings.git "$dir/SaaSAllTheThings" && echo "$dir/SaaSAllTheThings"
   ```
   `$SATT` is the folder it prints. If the clone fails (no network, no git), tell the human and stop.
3. Read `$SATT/ONBOARDING.md` and follow it. When onboarding is done, delete a temporary clone.
