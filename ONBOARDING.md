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
5. **Assistant adapters.** For a first install, ask which assistants will work on the app. The answer is `claude`, the default, or `none`; the core works through `AGENTS.md`. An upgrade keeps the earlier choice.

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
- **Upgrade mode:** Read the CHANGELOG entries newer than the old version (the install report names it). Summarise them for the human: what changed in the framework, and what the "Upgrade steps" will do to the project's own files (AGENTS.md, TASKS.md, etc.). Then ask which mode to use: recommend Fast for routine upgrades:
  - **Fast (recommended):** carry out the CHANGELOG "Upgrade steps" only; run step 4 if `bash tools/check.sh` exits 3; then go to step 10.
  - **Full:** carry out the CHANGELOG "Upgrade steps", then re-run steps 3-9 as if a fresh install, reading existing files rather than creating them, confirming inferred content with the human, and asking all the questions a fresh install asks. Use this after many accumulated versions, when onboarding a new contributor, or when the human wants a thorough review.

  Every CHANGELOG entry must include "Upgrade steps" that bring existing projects to the same capability level as a fresh install of that version. Fast mode carries them out; Full mode also re-verifies everything else.

## 3. The backend stack
Read `.satt/reference/stacks.md`. The framework is biased to .NET, but the human decides.
- **Fresh start:** ask which stack, with .NET recommended, then TypeScript and Python, and say that other languages aren't compatible with Azure Functions. Mention it if the human's team clearly works in another compatible stack.
- **Existing app:**
  1. Find its languages and frameworks: count source files by extension, and read the project files (`*.sln`, `*.csproj`, `package.json`, `pyproject.toml`, `requirements.txt`, `pom.xml`, `build.gradle`, and anything for languages Functions can't run, such as `*.dpr`, `*.php`, `Gemfile`, `*.vbp`).
  2. Tell the human what you found, and ask whether they have a preference (a bias) for the backend stack.
  3. **The current stack is compatible:** offer to stay with it first (recommended when the team knows it), then .NET if it differs, then another compatible stack. Staying means reusing what fits, from `stacks.md` › Reusing what an existing app has.
  4. **It isn't compatible:** say why, then list the compatible stacks with a recommendation (.NET, unless the team points elsewhere), or ask for their preferred language. If that one isn't compatible either, say so and ask again. Never pick for the human. Converting means the roadmap's Extract stage rewrites each area in the new stack.
- **Record it:**
  1. `tools/check.cfg` › `[project] stack` (`dotnet`, `typescript`, `python`, or `none` for Java), and `[layers]` and `[imports]` from `stacks.md` › Profiles and their layouts, with the app's name in place of `{{APP}}`. For an existing app, point `[layers]` at where the layered code will live; the old code stays outside every layer until the Extract stage moves it. A first install keeps the seed's `[rules] network-public = on`, which fails Bicep that leaves public network access or local authentication on (`reference/network.md`); an upgraded app keeps its own file, where the rule is off until the app adds that line (the CHANGELOG's upgrade steps say when).
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

### Your own product brief (before the interview or the PRD)
Every project has `product/director-brief.md`: the human's own product brief template, in their own words. It is the SaaS variant of a product brief, with sections the customer's architect or product owner fills in about the enterprise architecture the SaaS must fit into (identity provider, data residency, hosting constraints, integrations), the requirements (functional and non-functional), the security requirements, and the control frameworks the customer must meet. It is the human's file: you read it and never edit it. The PRD stays the record of current requirements that you maintain, so each fact lives in one place; the human's brief is input that stays as they wrote it.
1. **Is it filled?** It is still the template while its title reads `[App Name]` and its sections hold only the prompts. If the human points to another document (a requirements document, a customer's architecture or security questionnaire, or a file in `assessment/`), read that too.
2. **If it is blank, offer it** before the interview, as an alternative to the chat interview or an addition to it:
   - what it is: the template for describing the product, the architecture it fits into, its requirements, its security requirements and the control frameworks the customer must meet, in their own words;
   - where it is: `product/director-brief.md`;
   - why it helps: a written brief gives you their intent and the context behind it, adds value that a chat interview alone doesn't, and sets the stage for later development, since every design session, assessment and build starts from it, anchored in the customer's security framework;
   - when: it can be filled before onboarding, now (you wait), or later, by them or by the customer's architect or product owner, for a new SaaS or an existing app; and the interview works without it.

   Ask which they prefer: fill it now, interview only, or both (interview first, brief later). Never fill it in for them. If they fill it later, the next session reads it as below.
3. **If it is filled, read it first.**
   - Fresh start: take the interview's answers from it (step 1 of Fresh start below). Show each answer taken, marked `(from your document)`, and ask only what it leaves open. An answer you worked out from the brief without it saying so is `(inferred, please confirm)`.
   - Existing app: read it with the existing documents, the code and any assessment report, and use it to build the initial assessment: PRD sections, Architecture rows and first items. Mark each statement it supplied `(from your document)` and each you inferred `(inferred, please confirm)`.
   - Both: where the brief and the code, the assessment or the workshop notes disagree, say so and let the human decide.
4. **Record it.** The PRD sections you write from it: Customers and Tenants, Capabilities, Clients, Integrations, Data and Compliance (the control frameworks named, the security requirements and the data residency), Service Levels (the non-functional requirements) and the rest as they fit. A `product/decisions.md` line for each decision (`why: from your document` when that is the reason). The enterprise architecture constraints (identity provider, hosting, residency) go into AGENTS.md › Project facts and into the ADRs they bind, as drafts for the human to accept. Anything the brief leaves undecided becomes a `Q<n>`. Don't copy the brief wholesale into the PRD; write the current requirements in the PRD's own sections.
5. **The security framework.** If section 10 of the brief is blank or vague, ask the questions in `.satt/reference/compliance-questions.md` instead of moving on; if it is filled, confirm it in one line. Where the brief or the answers name the security framework and the control frameworks, record them under PRD › Data and Compliance and tell the human to put the frameworks' requirements (or the customer's own control list) in `compliance/`, which architecture sessions and research read. Each framework's controls go into `compliance/mapping.md` only from the human or a document they provide, never from your memory (until then the PRD lists it with `controls: to add`). Never claim a requirement is met, or a control framework satisfied, because the brief names it; the work is anchored in them, and each requirement is traced to a control as `.satt/procedures/architect.md` and `research.md` describe. The seed `compliance/mapping.md` maps each control to the rule, ADR or test that meets it; it starts with the ten OWASP Top 10 (2025) rows, the security baseline every app meets (framework-owned; no setting turns it off, and only an accepted ADR naming the OWASP item deviates), and one example row to delete, architecture sessions fill it as ADRs are accepted, and review and align read it. On an upgrade, offer to add it when `compliance/mapping.md` is absent (copy it from the source's `project/compliance/mapping.md`; never overwrite an existing file); nothing else changes. An existing `compliance/mapping.md` is kept: bring its ten `OWASP A01` to `OWASP A10` baseline rows to the 2025 edition: rename each row to its 2025 name from the source's seed, move its Met by, Label and Evidence to the 2025 category the CHANGELOG's upgrade table maps it to, and add the new A10 row from the seed. Leave the rest of the file as it is.
6. **Upgrade.** On an upgrade the installer adds `product/director-brief.md` when it is missing; offer it as above. Later, when the human says the brief changed, read it again and bring the PRD in line, marking what you inferred.

### Fresh start
1. **A short product interview,** in short rounds, after reading the human's brief if they filled one (above): ask only what it leaves open, and confirm what you took from it. For each question, give options with a recommendation and let the human pick:
   1. pitch, the customers (tenants), the first customer, and how they'd pay (plans);
   2. 3-5 Product Pillars;
   3. the first capabilities, in priority order;
   4. the clients: who uses the Windows app and who the mobile app, for what, and whether either must work offline;
   5. the integrations: which systems (Navision first?), their purpose and direction;
   6. data and compliance: residency, retention, personal data.
2. **Record it.** Write the answers into the PRD as current requirements, and add a line to `product/decisions.md` for each. Anything undecided becomes a `Q<n>`.

### Existing app
1. **PRD:** fill each section from the human's brief (above), the existing documents and the code. Mark anything inferred `(inferred, please confirm)`, and turn anything unknown into a `Q<n>`. Delete a section the product doesn't need only after the human agrees.
2. **AGENTS.md › Architecture:** one row per existing area (a screen group, a service, a job, a store), marked `(outside the layers: Extract)`, plus the layered systems as they appear. Take "Owns" from the code, not from guesses.
3. **TASKS.md:** known bugs and the human's priorities become items, with bugs as `B` items. Secrets found in step 5 are `high` bugs: rotate first, then remove.
4. **Existing tests** run from the stack's test command if they fit, or from `tools/check.local.sh`.

### Both
Run `.satt/procedures/roadmap.md`. It fills TASKS.md › Milestones with the stages and writes the items for the current stage and the next one. For an existing app that's Extract and Foundation.

## 7. Project facts and settings
- **AGENTS.md:** name, pitch, the stack (ADR-1), the clients (their UI tech is a `Decide:` item until an ADR settles it), the Azure region (a `Q<n>` if unknown), the integrations. Fill in the Layout table from `tools/check.cfg` › `[layers]` and the real folders, deleting rows that don't apply.
- **`tools/check.cfg`:** as step 3 set it; adjust `[scan] skip` for generated code the project has. It also holds `[rules] network-public` (`on` or `off`; absent means off), and `[security] every`: the number of items done between security assessments, after which `/next-task` proposes one (default 10); the human can decline, and a run of several items carries on and only names it.
- **`tools/ui_capture.cfg`** › `[web]`, when a client is a web app (Flutter web and Blazor included): `base_url`, the address of the web client running on this machine (such as `http://localhost:5173`), `api_url` for the local Functions host, `start_command` if capture should start them, `tenants`, the seeded test tenants, and `dev_url` if the dev environment's web client should be captured too (never prod). Leave `base_url` empty when every client is native (Windows or mobile): capture isn't available for those yet. The catalog (`tools/ui/screens.mjs`) starts with the root route. Capture needs Node 20 or newer and, once per clone, `cd tools/ui && npm install && npx playwright install chromium`. Offer that install; the check never needs it. A screen behind the sign-in needs a test user's saved sign-in, which the human saves once (`.satt/procedures/ui-design.md` › The catalog); never ask for a password or a token.

## 8. Ownership and project rules
Walk the human through the defaults, and record only the workflow differences in AGENTS.md › Project rules. Say clearly that the architecture isn't a project rule: it changes only through an ADR.
- The director owns the product, priorities, customers and integrations' business rules, and accepts ADRs.
- The agent owns code, tests, infrastructure as code and the records.
- Commits: the agent proposes and the human approves. Pushes happen when the human asks, or never if there's no remote.
- Deploys: dev with the human's approval each time, prod by the human (`release.md`). Ask whether dev deploys may run without asking each time.
- **Model sizing** (recommended on): first check that this tool can both spawn a builder subagent and specify its model per call (in Claude Code: yes; if the tool cannot: skip this step and write `Model sizing: off` in AGENTS.md › Project rules). If supported, read the defaults from `.satt/procedures/refresh-model-sizing.md` › Propose defaults. Present them to the human, ask to confirm or adjust, then write the confirmed block to AGENTS.md › Project rules:
  ```
  Model sizing: on
  - XS: claude-haiku-4-5-20251001
  - S:  claude-haiku-4-5-20251001
  - M:  claude-sonnet-5-5
  - L:  claude-opus-5-5
  - XL: claude-opus-5-5
  ```
  To update models later, run `/refresh-model-sizing`.
- Reviews: by default after `L` items, and after `M` items that change contracts, tenant isolation, identity or a stored schema.

### Designing screens by drawing
Ask once whether the director wants to design screens by drawing over screenshots of the running product (`/ui-design`; free Excalidraw, no account).
- **Yes:** add `UI / screen layout: director designs (director/ui/), agent builds` to AGENTS.md › Project rules. Offer `director/` (below) with `director/ui/`, and tell them the loop: `/ui-design capture` writes a starter drawing per screen of a web client, they draw and save it as `director/ui/<screen>.excalidraw`, and `/ui-design process <screen>` turns it into the screen's spec.
- **No:** nothing changes; the agent lays out screens. Capture, the layout lint and the catalog still work. No open question and no item is added: drawing is optional, never a prerequisite.

### Protected workspace
If the director wants a space the agent will never touch (screen drawings, mockups, brand assets, notes, third-party API specs), offer to create `director/`. The agent reads files there for context but never creates, modifies or deletes anything inside it (`.satt/rules.md` › Protected space; in Claude Code a hook blocks it). If they want it:
1. Create `director/` and `director/README.md` saying what it is and that the agent won't touch it, and `director/ui/` if they design screens by drawing.
2. Ask whether to gitignore it (for large binary assets) or commit it (for drawings and notes). Update `.gitignore` accordingly.

## 9. Feedback template
Replace the `{{CAPABILITY…}}` parts of `validation/TEMPLATE.md` with one section per capability in PRD › Capabilities, usually 3-6. Each gets one fixed scored statement and 1-2 open questions. Update the "Capabilities covered" line to match.

If the capabilities aren't decided yet, leave the placeholders, and add an agent item "Fill the feedback template's capability sections" that depends on that question.

## 10. Verify, commit, hand off
1. Run `bash tools/check.sh` and report the result. For an existing app, also report how many source files are outside every layer.
2. Search for `{{` with `git grep -n "{{" -- '*.md' tools/check.cfg`. Only postponed template sections may remain, and only if an item exists for them. `git ls-files -o -i --exclude-standard -- '*.satt-new' | grep '\.satt-new$'` must print nothing (the grep drops nested clones, which `ls-files` lists as directories).
3. Walk through the checks in `.satt/procedures/align.md`. Its fixes go into the install commit.
4. **Offer the check workflow** (a GitHub Actions run of `bash tools/check.sh`, with its output kept as an artifact).
   - Ask once, in a first install and in an upgrade (Fast included): "Add a GitHub Actions workflow that runs the check on every pull request and push to main and keeps its output as an artifact? Today a passing check leaves no record off your machine; the artifact is evidence a reviewer can find. How long it's kept is your repository's or organisation's Actions setting." In an upgrade, offer it only if `.github/workflows/check.yml` doesn't exist yet.
   - Only if the human says yes, copy `.satt/templates/check-workflow.yml` to `.github/workflows/check.yml`, then adjust the toolchain steps to the stack from step 3 (delete the others, set the versions the app targets). If the app builds on self-hosted runners, say what to change in the file's comments.
   - Never overwrite an existing `.github/workflows/check.yml`: say it exists and leave it. If the human says no, copy nothing; they can ask for it later.
5. List every file created, changed or deleted (`git status`).
6. **Commit it all in one commit, after the human approves.**
   - Stage everything: `git add -A -- <those files>`.
   - Mark the scripts executable, listing only files that exist (`.claude/hooks` is there with the Claude adapter only): `git add --chmod=+x -- tools/*.sh tools/stacks/*.sh .githooks/pre-commit`, plus `.claude/hooks/*.sh`.
   - Use the message `chore: install SaaSAllTheThings <version>` (or `upgrade to`). The body names the mode, the stack, and anything you inferred.
7. **The pre-commit hook.**
   - If the check passes, run `bash tools/setup-clone.sh`, which installs it.
   - If the check fails or can't run, leave the hook off and add an item: "Install the pre-commit hook once the check passes (`bash tools/setup-clone.sh`)".
   - If setup-clone exits 4, tell the human what it printed (an existing hook or `core.hooksPath` needs a manual line).
8. **A temporary clone from the skill:** delete it. **Manual install:** offer to delete the SaaSAllTheThings folder from the app. Deleting it is recommended, since upgrades come from a fresh download or the plugin. If the human keeps it, leave it in `.git/info/exclude`.
9. **Offer a "Development" section for the app's README:** clone, then `bash tools/setup-clone.sh`, then the commands.
10. **Tell the human:**
   - what needs their confirmation (inferred PRD text, open questions, `Decide:` items, human items);
   - how to use it: "do the next task", "plan the next stage", "let's work out <capability>", "add the Navision integration", "which UI tech for the Windows client?", "research which Azure service fits…", "prepare an acceptance check", "process this feedback", "release to dev", "run a security assessment", "check the docs are aligned", "capture the screens" (in Claude Code also `/next-task`, `/roadmap`, `/design`, `/integrate`, `/architect`, `/research`, `/ui-design`, `/acceptance`, `/feedback`, `/release`, `/security`, `/align`, `/tenant`, `/prune`, and `/drift-reset`, which only the human starts, when `/align` keeps finding the same conflict);
   - with the Claude adapter: to restart Claude Code, because skills, hooks and permissions load when a session starts;
   - that every new clone needs `bash tools/setup-clone.sh`.
