# Tasks

This is SaaSAllTheThings' own work queue, for developing the framework itself. It is fed by [Director-Driven Development](https://github.com/Freakling/Director-Driven-Development)'s orchestrator through pull requests. `project/TASKS.md` is a different file: the template shipped to adopters, which never receives these items.

Item format: `framework/.satt/tasks.md`. Queue order is priority; reorder by moving items.

**Next IDs:** T7 · B3 · R1

## Queue

### T5 · align checks the PRD and ADRs against reality · done · S · agent
- Touches: framework/.satt/procedures/align.md, CHANGELOG.md
- Done when: align's item 6 is "Brief against reality", in place of the Decisions spot-check: it reads the whole PRD and the ADRs, checks every statement of state (including each ADR's status) against the built system, the done items and the latest releases, and checks every decision line since the last `docs: align` commit one by one (check)
- PRD: none
- Source: Director-Driven-Development T95

## Queue

### T6 · The repository's own queue has a research counter · done · XS · agent
- Touches: TASKS.md
- Done when: `Next IDs` carries the `R` counter that `align.md` asks for, `· R1` (check)
- PRD: none
- Source: Director-Driven-Development T119

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
