# SaaSAllTheThings onboarding (for the AI assistant)

SaaSAllTheThings builds a B2B SaaS from scratch, or turns a working proof of concept or an existing app into a mature, multi-tenant SaaS. Follow these steps to install it into the app's repository, or to upgrade it. Work from a session opened in the app's repository root. You need to be able to run bash; on Windows, Git Bash.

The human makes every product, stack and ownership decision; you gather, propose and write. Ask choices as multiple-choice questions when your tool supports them, with your recommendation first.

`$SATT` below is the SaaSAllTheThings folder:
- With the Claude Code plugin, it's `${CLAUDE_PLUGIN_ROOT}`.
- With a manual install, it's the folder this file is in, usually `SaaSAllTheThings/` inside the app.
- With the skill installed by `npx skills add`, it's the temporary clone the skill made, outside the app.

## 1. Preconditions and mode
1. **Git.** The project must be a git repository. If it isn't, ask to run `git init`.
2. **Manual install inside the app:** if `$SATT` is inside the project, add its relative path (e.g. `/SaaSAllTheThings/`) to the file `git rev-parse --git-path info/exclude` names. Do it now, before any commit. That keeps it out of `git status`, the commits, the hooks and the check.
3. **Clean tree.** A new repository with files in it: commit them as they are first, so the install is one reviewable diff. Otherwise there must be no uncommitted changes (apart from the SaaSAllTheThings folder itself); ask the human to commit or stash them first.
4. **Mode.** Tell the human which mode you detected, and let them confirm:
   - **upgrade:** `.satt/manifest` exists.
   - **existing app:** source code without SaaSAllTheThings: a proof of concept, or an app in use. It becomes a mature SaaS area by area; an assessment (`.satt/procedures/assess.md`) often comes first.
   - **fresh start:** no source code yet (documents are fine). The SaaS is built from scratch.
5. **Assistant adapters.** For a first install, ask which assistants will work on the app. The answer is `claude`, the default, or `none` for other assistants only; the core works through `AGENTS.md`, which most assistants read. An upgrade keeps the earlier choice.

## 2. Install the files
Run `bash "$SATT/install.sh" --tools <claude|none> .` for a first install. For an upgrade, run `bash "$SATT/install.sh" .` without `--tools`. Then read its report.
- **`CONFLICTS`** (`<file>.satt-new`) mean the project already had its own version of a framework file:
  - `.claude/settings.json`: merge it, keeping the project's permissions, hooks and env and adding the framework's.
  - Anything else: show the human the difference and ask.

  Delete each `.satt-new` file once it's merged.
- **"project files kept"** means the project already had that file. Bring each one into the shape of `$SATT/project/<same file>`:
  - `CLAUDE.md` must contain the line `@AGENTS.md`, at the top. Move instructions meant for every assistant into AGENTS.md.
  - `AGENTS.md` keeps its content, gains the missing sections, and gets the line that points to `.satt/rules.md`.
  - `TASKS.md` and a requirements document convert to the seeds' formats (`TASKS.md`, `product/prd.md`), keeping their content.
- **Upgrade mode:**
  1. Read the entries in `$SATT/CHANGELOG.md` that are newer than the old version (the install report names it), and carry out their "Upgrade steps".
  2. Run step 4 only if `bash tools/check.sh` exits 3.
  3. Summarise what changed, using the CHANGELOG and `git diff --stat`.
  4. Go to step 10.

## 3. The backend stack
Read `.satt/reference/stacks.md`. The framework is biased to .NET, but the human decides.
- **Fresh start:** ask which stack, with .NET recommended, then TypeScript and Python, and say that other languages aren't compatible with Azure Functions. Mention it if the human's team clearly works in another compatible stack.
- **Existing app:**
  1. Find its languages and frameworks: count source files by extension, and read the project files (`*.sln`, `*.csproj`, `package.json`, `pyproject.toml`, `requirements.txt`, `pom.xml`, `build.gradle`, and anything for languages Functions can't run, such as `*.dpr`, `*.php`, `Gemfile`, `*.vbp`).
  2. Tell the human what you found, and ask whether they have a preference (a bias) for the backend stack.
  3. **The current stack is compatible:** offer to stay with it first (recommended when the team knows it), then .NET if it differs, then another compatible stack. Staying means reusing what fits, from `stacks.md` › Reusing what an existing app has.
  4. **It isn't compatible:** say why, then list the compatible stacks with a recommendation (.NET, unless the team points elsewhere), or ask for their preferred language. If that one isn't compatible either, say so and ask again. Never pick for the human. Converting means the roadmap's Extract stage rewrites each area in the new stack.
- **Record it:**
  1. `tools/check.cfg` › `[project] stack` (`dotnet`, `typescript`, `python`, or `none` for Java), and `[layers]` and `[imports]` from `stacks.md` › Profiles and their layouts, with the app's name in place of `{{APP}}`. For an existing app, point `[layers]` at where the layered code will live; the old code stays outside every layer until the Extract stage moves it.
  2. The stack's build output in `.gitignore` (for .NET, `bin/` and `obj/`).
  3. `adr/ADR-1-backend-stack.md` from `.satt/templates/adr.md`: what was found, the options, the human's choice. Set `Status: accepted`, since the human just decided (in Claude Code, a hook asks them to confirm).

## 4. Toolchain for this clone
Run `bash tools/setup-clone.sh --skip-hook`. It checks the stack's toolchain and restores dependencies. If it exits 3, tell the human what to install, and continue: `bash tools/check.sh --architecture` needs no toolchain.

Then run `bash tools/check.sh` once and keep the result. An existing app often fails at first; that's information, not a blocker. The pre-commit hook is installed at the very end (step 10), so the install commit isn't blocked.

## 5. Scan the project (read only)
If `assessment/` holds an assessment report (`.satt/procedures/assess.md`), start from it: check that its findings still hold, and scan only what it doesn't cover. Otherwise, for an existing app:
- **Shape:** projects and folders with file counts; entry points (UIs, APIs, services, scheduled jobs); what talks to what.
- **Data:** stores and how the code reaches them; whether anything identifies a customer (a tenant column, a database per customer, nothing).
- **Single-tenant habits:** customer names or ids in code or config, per-customer branches or builds, global state or singletons holding customer data, one connection string for everyone.
- **Identity:** how users sign in today, and where users and roles live.
- **Secrets:** run `bash tools/check.sh --architecture`; its `secrets` rule scans every file. Also note connection strings and keys in config files.
- **Integrations:** calls to Navision or Business Central (OData, SOAP web services, `/api/v2.0/`), other ERPs, file drops, email.
- **Clients:** desktop and mobile apps, and whether their screens hold business rules.
- **Tests, docs and TODOs:** existing test suites; README, requirements and design documents; `TODO`, `FIXME` and `HACK` comments, with file and line.

## 6. Content, by mode

**Workshop notes first.** If `assessment/workshops/` holds notes (`.satt/workshops/README.md` › Notes), their decisions are the human's answers: record them as the interview below would, confirm your reading with the human instead of asking again, and ask only what they leave open. ADR drafts in them become ADRs (`.satt/procedures/architect.md` › Record); a draft about the backend stack becomes ADR-1 in step 3. Then mark each file `**Processed:**` as `.satt/procedures/assess.md` › Process workshop notes says.

### Fresh start
1. **A short product interview,** in short rounds. For each question, give options with a recommendation and let the human pick:
   1. pitch, the customers (tenants), the first customer, and how they'd pay (plans);
   2. 3–5 Product Pillars;
   3. the first capabilities, in priority order;
   4. the clients: who uses the Windows app and who the mobile app, for what, and whether either must work offline;
   5. the integrations: which systems (Navision first?), their purpose and direction;
   6. data and compliance: residency, retention, personal data.
2. **Record it.** Write the answers into the PRD as current requirements, and add a line to `product/decisions.md` for each. Anything undecided becomes a `Q<n>`.

### Existing app
1. **PRD:** fill each section from the existing documents and code. Mark anything inferred `(inferred — please confirm)`, and turn anything unknown into a `Q<n>`. Delete a section the product doesn't need only after the human agrees.
2. **AGENTS.md › Architecture:** one row per existing area (a screen group, a service, a job, a store), marked `(outside the layers: Extract)`, plus the layered systems as they appear. Take "Owns" from the code, not from guesses.
3. **TASKS.md:** known bugs and the human's priorities become items, with bugs as `B` items. Secrets found in step 5 are `high` bugs: rotate first, then remove.
4. **Existing tests** run from the stack's test command if they fit, or from `tools/check.local.sh`.

### Both
Run `.satt/procedures/roadmap.md`. It fills TASKS.md › Milestones with the stages and writes the items for the current stage and the next one. For an existing app that's Extract and Foundation.

## 7. Project facts and settings
- **AGENTS.md:** name, pitch, the stack (ADR-1), the clients (their UI tech is a `Decide:` item until an ADR settles it), the Azure region (a `Q<n>` if unknown), the integrations. Fill in the Layout table from `tools/check.cfg` › `[layers]` and the real folders, deleting rows that don't apply.
- **`tools/check.cfg`:** as step 3 set it; adjust `[scan] skip` for generated code the project has.

## 8. Ownership and project rules
Walk the human through the defaults, and record only the workflow differences in AGENTS.md › Project rules. Say clearly that the architecture isn't a project rule: it changes only through an ADR.
- The human owns the product, priorities, customers and integrations' business rules, and accepts ADRs.
- The agent owns code, tests, infrastructure as code and the records.
- Commits: the agent proposes and the human approves. Pushes happen when the human asks, or never if there's no remote.
- Deploys: dev with the human's approval each time, prod by the human (`release.md`). Ask whether dev deploys may run without asking each time.
- Model sizing (Claude Code only): off by default. When it's on, the `builder` subagent builds `S` items on Haiku.
- Reviews: by default after `L` items, and after `M` items that change contracts, tenant isolation, identity or a stored schema.

## 9. Feedback template
Replace the `{{CAPABILITY…}}` parts of `validation/TEMPLATE.md` with one section per capability in PRD › Capabilities, usually 3–6. Each gets one fixed scored statement and 1–2 open questions. Update the "Capabilities covered" line to match.

If the capabilities aren't decided yet, leave the placeholders, and add an agent item "Fill the feedback template's capability sections" that depends on that question.

## 10. Verify, commit, hand off
1. Run `bash tools/check.sh` and report the result. For an existing app, also report how many source files are outside every layer.
2. Search for `{{` with `git grep -n "{{" -- '*.md' tools/check.cfg`. Only postponed template sections may remain, and only if an item exists for them. `git ls-files -o -i --exclude-standard -- '*.satt-new'` must print nothing.
3. Walk through the checks in `.satt/procedures/align.md`. Its fixes go into the install commit.
4. List every file created, changed or deleted (`git status`).
5. **Commit it all in one commit, after the human approves.**
   - Stage everything: `git add -A -- <those files>`.
   - Mark the scripts executable, listing only files that exist (`.claude/hooks` is there with the Claude adapter only): `git add --chmod=+x -- tools/*.sh tools/stacks/*.sh .githooks/pre-commit`, plus `.claude/hooks/*.sh`.
   - Use the message `chore: install SaaSAllTheThings <version>` (or `upgrade to`). The body names the mode, the stack, and anything you inferred.
6. **The pre-commit hook.**
   - If the check passes, run `bash tools/setup-clone.sh`, which installs it.
   - If the check fails or can't run, leave the hook off and add an item: "Install the pre-commit hook once the check passes (`bash tools/setup-clone.sh`)".
   - If setup-clone exits 4, tell the human what it printed (an existing hook or `core.hooksPath` needs a manual line).
7. **A temporary clone from the skill:** delete it. **Manual install:** offer to delete the SaaSAllTheThings folder from the app. Deleting it is recommended, since upgrades come from a fresh download or the plugin. If the human keeps it, leave it in `.git/info/exclude`.
8. **Offer a "Development" section for the app's README:** clone, then `bash tools/setup-clone.sh`, then the commands.
9. **Tell the human:**
   - what needs their confirmation (inferred PRD text, open questions, `Decide:` items, human items);
   - how to use it: "do the next task", "plan the next stage", "let's work out <capability>", "add the Navision integration", "which UI tech for the Windows client?", "prepare an acceptance check", "process this feedback", "release to dev", "check the docs are aligned" (in Claude Code also `/next-task`, `/roadmap`, `/product`, `/integrate`, `/architect`, `/acceptance`, `/feedback`, `/release`, `/align`, `/tenant`, `/prune`);
   - with the Claude adapter: to restart Claude Code, because skills, hooks and permissions load when a session starts;
   - that every new clone needs `bash tools/setup-clone.sh`.
