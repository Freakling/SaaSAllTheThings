# Tasks

This is SaaSAllTheThings' own work queue, for developing the framework itself. It is fed by [Director-Driven Development](https://github.com/Freakling/Director-Driven-Development)'s orchestrator through pull requests. `project/TASKS.md` is a different file: the template shipped to adopters, which never receives these items.

Item format: `framework/.satt/tasks.md`. Queue order is priority; reorder by moving items.

**Next IDs:** T2 · B3

## Queue

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

## Notes
