# Tasks

This is SaaSAllTheThings' own work queue, for developing the framework itself. It is fed by [Director-Driven Development](https://github.com/Freakling/Director-Driven-Development)'s orchestrator through pull requests. `project/TASKS.md` is a different file: the template shipped to adopters, which never receives these items.

Item format: `framework/.satt/tasks.md`. Queue order is priority; reorder by moving items.

**Next IDs:** T13 · B3 · R1

## Queue

### T12 · The repository ignores OS metadata files · done · XS · agent
- Touches: .gitignore, CHANGELOG.md
- Done when: `.gitignore` lists `.DS_Store`, `Thumbs.db`, `desktop.ini` and `__MACOSX/` (check)
- PRD: none
- Source: Director-Driven-Development T100

### T10 · Two sessions that build at once each get a worktree · done · XS · agent
- Touches: framework/.satt/rules.md, README.md, selftest.sh, CHANGELOG.md, skills/saas-design-session/references (bundled rules.md)
- Done when: the same rule as T160 in SaaSAllTheThings' rules and README, checked by its selftest (check)
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

## Queue

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

## Queue

### T9 · /ui-design with Playwright capture · done · L · agent
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
