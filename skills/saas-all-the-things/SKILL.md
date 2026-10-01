---
name: saas-all-the-things
description: 'Install or upgrade the SaaSAllTheThings workflow in the app open in this session, to make it a multi-tenant SaaS on Azure: event-driven Azure Functions, OIDC with federated identity, Windows and mobile clients, Navision / Business Central integrations, with an architecture the framework enforces. Use when the user asks to install, set up, add or upgrade SaaSAllTheThings, to turn an app into a SaaS ("SaaS all the things"), to make an app multi-tenant on Azure, or to add the SaaSAllTheThings workflow to a project.'
license: MIT
compatibility: 'Needs git and bash (Git Bash on Windows). Outside the Claude Code plugin it downloads the framework from github.com with git clone.'
metadata:
  author: Freakling
  version: 0.1.0
---

SaaSAllTheThings installs from its own repository: `ONBOARDING.md`, `install.sh` and the framework files beside them. Find that folder, call it `$SATT`, then follow `$SATT/ONBOARDING.md` for the project in the current working directory.

1. **Installed as the Claude Code plugin:** if `${CLAUDE_PLUGIN_ROOT}/ONBOARDING.md` exists, `$SATT` is `${CLAUDE_PLUGIN_ROOT}`.
2. **Otherwise** (installed with `npx skills add`, which copies only this folder): clone this skill's release into a temporary folder outside the project, and use that. Never clone it into the project.
   ```
   dir="$(mktemp -d)" && git clone -q --depth 1 --branch v0.1.0 https://github.com/Freakling/SaaSAllTheThings.git "$dir/SaaSAllTheThings" && echo "$dir/SaaSAllTheThings"
   ```
   `$SATT` is the folder it prints. If the clone fails (no network, no git), tell the human and stop.
3. Read `$SATT/ONBOARDING.md` and follow it. When onboarding is done, delete a temporary clone.
