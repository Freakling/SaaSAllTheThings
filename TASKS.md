# Tasks

This is SaaSAllTheThings' own work queue, for developing the framework itself. It is fed by [Director-Driven Development](https://github.com/Freakling/Director-Driven-Development)'s orchestrator through pull requests. `project/TASKS.md` is a different file: the template shipped to adopters, which never receives these items.

Item format: `framework/.satt/tasks.md`. Queue order is priority; reorder by moving items.

**Next IDs:** T25 · B3 · R1

## Queue

### T24 · Onboarding and the assessment ask which compliance frameworks apply · done · M · agent
- Touches: ONBOARDING.md, framework/.satt/reference/compliance-questions.md (new), framework/.satt/reference/README.md, framework/.satt/procedures/assess.md, framework/.satt/workshops/vision.md, framework/.satt/workshops/tenancy-identity.md, skills/saas-design-session/references/ (bundle), selftest.sh, CHANGELOG.md
- Done when: when the brief's section 10 is blank or vague, onboarding and the assessment ask the one question set (security framework, markets and data, each regulation asked and never assumed, auditor and evidence, the customer's control list), the answers go to PRD › Data and Compliance and the section 10 table, controls reach `compliance/mapping.md` only from the human or a document, never from memory, an unknown answer stays an open question, the vision and tenancy-identity workshops use it, and nothing marks a control met because a framework is named (check)
- PRD: none
- Source: Director-Driven-Development T200

### T23 · OWASP is a non-negotiable baseline · done · M · agent
- Touches: framework/.satt/rules.md, framework/.satt/procedures/architect.md, framework/.satt/procedures/review.md, framework/.satt/procedures/align.md, project/compliance/mapping.md, ONBOARDING.md, skills/saas-design-session/references/ (bundle), selftest.sh, CHANGELOG.md
- Done when: `rules.md` states the OWASP Top 10 (and the API Security Top 10 for anything that serves an API) as a framework-owned baseline that no setting turns off, `architect.md` makes every option state its effect on it, `review.md` checks the listed kinds of change against it and reports the OWASP item, and a deviation is only an accepted ADR naming the item (check) · the seed `compliance/mapping.md` carries the ten OWASP Top 10 rows marked as the baseline, each with an honest label and none `direct`, and align reports a removed baseline row (check)
- PRD: none
- Source: Director-Driven-Development T198

### T22 · Dependency review and an SBOM in the shipped workflow · done · S · agent
- Touches: framework/.satt/templates/check-workflow.yml, framework/.satt/reference/infra.md, skills/saas-design-session/references/ (bundle), selftest.sh, CHANGELOG.md
- Done when: the shipped workflow reviews dependency changes on pull requests and exports an SPDX SBOM from GitHub's dependency graph as an artifact on each push to main, and the infra reference says what that covers and that vulnerability response stays the customer's process (check)
- PRD: none
- Source: Director-Driven-Development T172

### T21 · A compliance mapping table that review and align read · done · M · agent
- Touches: project/compliance/mapping.md (new), framework/.satt/procedures/architect.md, framework/.satt/procedures/review.md, framework/.satt/procedures/align.md, ONBOARDING.md, skills/saas-design-session/references/ (bundle), selftest.sh, CHANGELOG.md
- Done when: a seeded table with control id, requirement, met by (rule, ADR or test), label (direct, partial, interpretive or unverified) and evidence location; architecture sessions add or update rows as ADRs are accepted, review flags a change to a mapped rule, ADR or test that leaves its row stale, and align reports rows whose rule, ADR or test no longer exists; nothing marks a control met from a framework's name (check)
- PRD: none
- Source: Director-Driven-Development T171

### T20 · A shipped CI workflow keeps the check's output as evidence · done · M · agent
- Touches: framework/.satt/templates/check-workflow.yml (new), ONBOARDING.md, framework/.satt/procedures/release.md, selftest.sh, CHANGELOG.md
- Done when: a GitHub Actions workflow template runs `bash tools/check.sh` on every pull request and push to main and uploads its output and logs as an artifact, with how long it's kept left to the app's setting; onboarding offers to install it for new and existing apps; the selftest checks the template's steps (check)
- PRD: none
- Source: Director-Driven-Development T170

### T19 · The check fails public network access and local authentication in Bicep · done · M · agent
- Touches: framework/.satt/reference/network.md, framework/.satt/reference/README.md, framework/.satt/reference/cost.md, framework/tools/archcheck.awk, project/tools/check.cfg, ONBOARDING.md, skills/saas-design-session/references/, selftest.sh
- Done when: a new rule, named in reference/README.md › What the check enforces, archcheck.awk and selftest.sh, fails a Bicep resource that leaves public network access enabled or local authentication on, for the resource types the reference architecture uses where Azure offers the setting, and an accepted ADR with an exception for the rule and path excuses it (check) · the network topic gives the default posture, and cost.md says private-only needs Service Bus Premium, so an ADR with a `cost-sku` exception (check) · the rule is on for new apps and off on upgrade until the app turns it on in check.cfg, as the CHANGELOG's upgrade steps say (check)
- PRD: none
- Source: Director-Driven-Development T169

### T18 · The repository's own TASKS.md has one queue and unique IDs · done · XS · agent
- Touches: TASKS.md
- Done when: one `## Queue` heading; the second item numbered T9 renumbered T17; T10's Done when names its own rule rather than another repository's item (check)
- PRD: none
- Source: Director-Driven-Development T167

### T16 · The README says a claim protects only its own worktree · done · XS · agent
- Touches: README.md, CHANGELOG.md, TASKS.md
- Done when: the README's sentence that an `in-progress` claim stops two sessions touching the same item says what `rules.md` says instead: a claim protects only its own worktree, and sessions that build at the same time each take a git worktree (check)
- PRD: none
- Source: Director-Driven-Development T179

### T15 · The Bash guard blocks hangs, and the check limits its test runs · done · M · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, framework/.satt/rules.md, framework/tools/check.sh, framework/tools/cfg.sh, framework/tools/stacks/dotnet.sh, framework/tools/stacks/typescript.sh, framework/tools/stacks/python.sh, project/tools/check.cfg, selftest.sh, CHANGELOG.md
- Done when: the guard blocks an empty Python heredoc, a sleep loop without a `timeout` of 280 seconds or less, a loop reading a task's output without its end marker, and a lone sleep over 280 seconds, with messages that give the form that works, and passes the forms that work (test) · `rules.md` gives every long command a time limit, `run_in_background` and no empty-heredoc probes (check) · `tools/check.sh` runs test commands under GNU timeout (`[tests] timeout`, default 600) and exits 3 on a timeout (check)
- PRD: none
- Source: Director-Driven-Development T165

### T14 · A screen is re-arranged by dragging its grey boxes · done · M · agent
- Touches: framework/tools/ui/drawing.mjs, framework/.satt/procedures/ui-design.md, project/product/ui/README.md, examples/order-desk/product/ui/README.md, tests/ui-drawing, selftest.sh, CHANGELOG.md
- Done when: the starter's grey boxes are unlocked, a dragged or resized one is read as a blue keep box for that element at its new place, the reader agrees with Godot-Director's byte for byte on the shared fixtures, and the selftest passes (check)
- PRD: none
- Source: Director-Driven-Development T183

### T13 · The screen-design README is organised by feature · done · S · agent
- Touches: project/product/ui/README.md, examples/order-desk/product/ui/README.md, CHANGELOG.md
- Done when: `product/ui/README.md` follows Godot-Director's section order (workflow, setting up capture, what a capture gives you, boxes, colours, containment, patch or replace, re-arranging, states and sizes, processing, Excalidraw, files), keeps the grey boxes locked and re-arranging as a blue box, and the example's copy is identical (check)
- PRD: none
- Source: Director-Driven-Development T182

### T12 · The repository ignores OS metadata files · done · XS · agent
- Touches: .gitignore, CHANGELOG.md
- Done when: `.gitignore` lists `.DS_Store`, `Thumbs.db`, `desktop.ini` and `__MACOSX/` (check)
- PRD: none
- Source: Director-Driven-Development T100

### T11 · Every subagent launch passes its model explicitly · done · S · agent
- Touches: framework/.satt/procedures/next-task.md, framework/.satt/rules.md, selftest.sh, CHANGELOG.md, skills/saas-design-session/references (bundled rules.md)
- Done when: every subagent launch (the builder, the reviewer, the researcher and an escalated retry) sets its model explicitly from the sizing table for the item's size and never inherits the session's model, and a size with no entry, or model sizing off, passes the session model explicitly; rules.md states the rule and next-task.md applies it at each launch, and the selftest checks both (check)
- PRD: none
- Source: Director-Driven-Development T151

### T10 · Two sessions that build at once each get a worktree · done · XS · agent
- Touches: framework/.satt/rules.md, README.md, selftest.sh, CHANGELOG.md, skills/saas-design-session/references (bundled rules.md)
- Done when: `rules.md` and the README say that two sessions that build at the same time each take their own git worktree, checked by the selftest (check)
- PRD: none
- Source: Director-Driven-Development T161

### T9 · The README starts with writing your own product brief · done · S · agent
- Touches: README.md, project/product/director-brief.md, examples/order-desk/product/director-brief.md (the example copy must match the seed), selftest.sh, CHANGELOG.md
- Done when: the README's how-to-use section opens with a "Start here" step before the install, telling the reader to write the product brief in their own words first, with a link to the template at the `v<version>` release tag, to fill in what they know and leave the rest, and noting that the brief also carries the enterprise architecture, requirements, security requirements and control frameworks, which the assessment and the builds read (check) · the template's header comment carries the same link (check) · the selftest fails when either link doesn't name the `VERSION` tag (test)
- PRD: none
- Source: Director-Driven-Development T156

### T6 · The human-written SaaS brief · done · M · agent
- Touches: project/product/director-brief.md (new), examples/order-desk/product/director-brief.md (new), ONBOARDING.md, framework/.satt/procedures/assess.md, framework/.satt/templates/assessment.md, skills/saas-assessment/SKILL.md, skills/saas-design-session/references/procedures/assess.md (bundled), README.md, selftest.sh, CHANGELOG.md
- Done when: every project has a SaaS variant of the director's product brief template as a seed (`product/director-brief.md`), which also asks about the enterprise architecture, requirements, security requirements and the control frameworks the customer must meet, worded for the human to answer and anchored in the customer's security framework (check) · onboarding offers it before the interview, as an alternative or an addition to the chat interview, with a word on why it helps, and reads a filled one first for a new or an existing app, marking what it took `(from your document)` and what it inferred `(inferred, please confirm)` (check) · the assessment procedure and the `saas-assessment` skill read a filled one first and mark what came from the brief (check) · the README mentions it (check) · the selftest fails when the seed, the example copy or the wiring is missing, and checks a new app receives the seed (check)
- PRD: none
- Source: Director-Driven-Development T89

### T5 · align checks the PRD and ADRs against reality · done · S · agent
- Touches: framework/.satt/procedures/align.md, CHANGELOG.md
- Done when: align's item 6 is "Brief against reality", in place of the Decisions spot-check: it reads the whole PRD and the ADRs, checks every statement of state (including each ADR's status) against the built system, the done items and the latest releases, and checks every decision line since the last `docs: align` commit one by one (check)
- PRD: none
- Source: Director-Driven-Development T95

### T8 · An install from a non-release source marks itself unreleased · done · S · agent
- Touches: install.sh, selftest.sh
- Done when: an install from a source whose CHANGELOG.md has an Unreleased section with entries records `<version> + unreleased (<commit>)` in the manifest, and its closing lines say it's a development snapshot, not a release (test) · an install from a release records the plain version, with the source commit in a `# source` line (test) · an upgrade from a manifest carrying the unreleased suffix reads the old version without it (test)
- PRD: none
- Source: Director-Driven-Development T135

### T7 · The repository's own queue has a research counter · done · XS · agent
- Touches: TASKS.md
- Done when: `Next IDs` carries the `R` counter that `align.md` asks for, `· R1` (check)
- PRD: none
- Source: Director-Driven-Development T119

### T17 · /ui-design with Playwright capture (numbered T9 until a second T9 was found) · done · L · agent
- Touches: framework/.satt/procedures/ui-design.md (new), framework/.claude/skills/ui-design/SKILL.md (new), framework/tools/ui_capture.sh (new), framework/tools/ui/ (new: capture.mjs, lint.mjs, drawing.mjs, overlay.mjs, verify.mjs, common.mjs, package.json, .npmrc), project/tools/ui/screens.mjs (new), project/tools/ui_capture.cfg (new), project/product/ui/README.md (new), project/AGENTS.md, framework/.satt/rules.md, framework/.satt/tasks.md, framework/.satt/procedures/build.md, framework/.satt/procedures/review.md, framework/.satt/procedures/acceptance.md, framework/.satt/procedures/align.md, framework/.satt/procedures/design.md, framework/.satt/procedures/feedback.md, framework/.claude/settings.json, framework/.claude/hooks/guard-authority.sh, install.sh, ONBOARDING.md, README.md, skills/saas-design-session/ (SKILL.md and the bundle), examples/order-desk (the seeds, AGENTS.md, .gitignore), tests/ui-drawing/ (new), tests/ui-web/ (new), .gitignore (new), selftest.sh, CHANGELOG.md
- Done when: `/ui-design list` prints the catalog and `capture` writes a PNG, element map, map image and lint file per catalog screen, state and size of a web client on this machine, the same twice, opens the dev environment named in `dev_url` (`env: dev`) and refuses every other hosted address, Azure-hosted ones even when allowed (test) · a screen sent away to sign in, by a redirect or a script, or refused with 401 or 403 fails alone with the sign-in advice (test) · a tenant's screen opens as a test user of a seeded test tenant: a tenant that isn't seeded, or one without its test user's sign-in, fails the catalog entry, as does a state naming its tenant without its sign-in, and a sign-in that isn't saved exits 3 with what to set up and writes nothing (test) · the lint catches each of its seven rules on a fixture page built to break it and reports nothing on a clean one, and the reader gives the same `drawing.json` as Godot Director's for the shared fixtures (test) · `verify` reports no deviation on a page built as its spec says and exactly the element moved 10% (test) · the hook blocks writes to `director/`, and without Node, Playwright or a web client capture exits 3 with the reason while the check doesn't need them (test)
- PRD: none
- Source: Director-Driven-Development T85

### T4 · The manual install takes the latest release · done · XS · agent
- Touches: README.md, CHANGELOG.md, TASKS.md
- Done when: the manual install option in README.md clones the latest release tag instead of `main`, worded like App-Director's and Godot-Director's manual options (check)
- PRD: none
- Source: Director-Driven-Development T68

### T3 · The plugin installs the latest release · done · S · agent
- Touches: .claude-plugin/marketplace.json, .claude/CLAUDE.md, selftest.sh, README.md, CHANGELOG.md
- Done when: the marketplace's plugin entry pins `v<version>` and the selftest fails when its `ref` disagrees with `VERSION` (test) · `.claude/CLAUDE.md` › After any change lists the marketplace among the files that carry the version and says each release is tagged `v<version>` (check)
- PRD: none
- Source: Director-Driven-Development T39

### B1 · The upgrade-file check ignores nested clones · done · S · agent · med
- Touches: framework/.githooks/pre-commit, framework/.satt/procedures/align.md, ONBOARDING.md, selftest.sh
- Repro: clone a repository into an ignored folder (such as `work/`), with no upgrade file present, then commit → expected: the commit goes ahead / actual: "unmerged SaaSAllTheThings upgrade files (*.satt-new) exist", listing the clone's folder, because `git ls-files` lists a nested repository in an ignored folder as a directory
- Found in: Director-Driven-Development B2
- PRD: none

### B2 · The self-test's .NET part runs without an SDK · done · S · agent · med
- Touches: selftest.sh, CHANGELOG.md
- Repro: on a machine with the .NET runtime host but no SDK (`dotnet --list-sdks` prints nothing), run `bash selftest.sh` → expected: the .NET part is skipped ("no .NET SDK on this machine") / actual: "couldn't read the .NET SDK version ('')", and three .NET checks fail (setup-clone restores the example; the example builds and its tests pass; runs the example's tests)
- Found in: Director-Driven-Development T48
- PRD: none

### T1 · One commit model: a single task pauses for approval, a run commits without pausing · done · M · agent
- Touches: framework/.satt/procedures/next-task.md, framework/.satt/rules.md, framework/.claude/settings.json, framework/.claude/skills/next-task/SKILL.md, skills/saas-design-session/references/rules.md, README.md, examples/scenarios.md, CHANGELOG.md
- Done when: `next-task.md` step 7 pauses for approval unless the human asked for a run ("grab tasks until you're blocked", "work through the queue", "the next N tasks"), which commits each item without pausing and stops when an item is blocked on the human, a build fails, or the human declines a commit (check) · `git commit` is in `permissions.allow` and not in `permissions.ask` of `.claude/settings.json`, while `git push` and the `az` and `azd` commands still ask (check) · `rules.md`, the skill description, the README and the scenarios agree, and the bundled copy of `rules.md` matches (check)
- PRD: none
- Source: Director-Driven-Development T35 (the shared commit model)

### T2 · The research assistant · done · M · agent
- Touches: framework/.satt/procedures/research.md (new), framework/.satt/research-domain.md (new), framework/.claude/agents/researcher.md (new), framework/.claude/skills/research/SKILL.md (new), framework/.claude/settings.json, framework/.satt/tasks.md, framework/.satt/rules.md, framework/.satt/procedures/next-task.md, framework/.satt/procedures/design.md, framework/.satt/procedures/architect.md, framework/.satt/procedures/align.md, project/TASKS.md (+R counter), project/product/research/README.md (new), examples/order-desk/TASKS.md, examples/order-desk/product/research/README.md (new), examples/scenarios.md, skills/saas-design-session/SKILL.md, skills/saas-design-session/references (bundled copy), bundle.sh, README.md, ONBOARDING.md, selftest.sh, CHANGELOG.md
- Done when: `research.md`, `research-domain.md`, the `researcher` subagent and the `/research` skill exist, and `rules.md`, `next-task.md`, `design.md`, `architect.md`, `tasks.md`, `align.md`, the README and ONBOARDING.md name or use them (check) · the `researcher` has `Read, Grep, Glob, WebSearch, WebFetch` and no edit, write or shell tool, and only `permissions.allow` in `settings.json` lists web search and fetch (check) · `project/TASKS.md` carries an `R` counter on its `Next IDs` line, and the installer ships the procedure, the domain file, the note folder and the Claude adapter files, with `--tools none` too (check) · a commit with only a research note doesn't run the project check (check) · the bundled copy of `rules.md`, `tasks.md`, `design.md` and `architect.md` matches `framework/.satt/`, and `saas-design-session` leaves the research procedure out and says so (check)
- PRD: none
- Source: Director-Driven-Development T43 (product/anchors/research.md)

## Notes
