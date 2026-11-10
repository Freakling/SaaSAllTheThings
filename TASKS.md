# Tasks

This is SaaSAllTheThings' own work queue, for developing the framework itself. It is fed by [Director-Driven Development](https://github.com/Freakling/Director-Driven-Development)'s orchestrator through pull requests. `project/TASKS.md` is a different file: the template shipped to adopters, which never receives these items.

Item format: `framework/.satt/tasks.md`. Queue order is priority; reorder by moving items.

**Next IDs:** T50 · B4 · R1

## Queue

### B3 · Staging a new file changes the check's fingerprint · done · S · agent · med
- Touches: framework/tools/check.sh, selftest.sh, CHANGELOG.md, TASKS.md
- Repro: in an app with a committed `src/a.cs` and a new, untracked `src/b.cs`, run `bash tools/check.sh --fingerprint`, then `git add src/b.cs` and run it again → expected: the same hash, since no file's content changed / actual: a different hash, because `fingerprint()` hashes the paths in the order `git ls-files -c -o --exclude-standard` prints them, untracked files first, so `--if-changed` misses and the pre-commit hook runs the whole check again
- Found in: Director-Driven-Development B70 (the review of App-Director's fast check tier)
- PRD: none
- Stories: none
- Source: Director-Driven-Development B70

### T49 · The check workflow template pins every action by commit · done · S · agent
- Touches: framework/.satt/templates/check-workflow.yml, framework/.satt/reference/owasp.md, skills/saas-design-session/references/reference/owasp.md, selftest.sh, CHANGELOG.md, TASKS.md
- Done when: every `uses:` in the template is a full commit SHA with its version in a trailing comment, each SHA read from the action's own repository (check) · the A08 check in `owasp.md` says pinned by commit and the bundled copy matches it (check) · the selftest passes (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development T317

### T48 · The guard reads a quoted or backslash path to git or a shell as it reads the bare name · done · M · agent
- Touches: framework/.claude/hooks/guard-commands.sh, selftest.sh, CHANGELOG.md, TASKS.md
- Done when: `"C:\Program Files\Git\bin\git.exe" -c core.pager=calc log` and `--upload-pack` with a quoted git path, and `"C:\Program Files\Git\bin\bash.exe" -c "git push --force"` and `C:\Git\bin\bash.exe -c ...`, are blocked as the bare names are, with their cases (test) · the selftest passes (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development T294

### T47 · A heredoc's delimiter isn't read as a Python with nothing to run · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, selftest.sh, CHANGELOG.md, TASKS.md
- Done when: a heredoc that ends in a line named `PY` or `python` passes, whether a script or another interpreter reads it, and a bare `python3` after a heredoc with another delimiter is still blocked (test) · the selftest passes (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development B66

### T46 · The guard blocks a Python with nothing to run · done · M · agent
- Touches: framework/.claude/hooks/guard-commands.sh, selftest.sh, CHANGELOG.md, TASKS.md
- Done when: the guard blocks `python3 -`, `python`, `py -3` and the like with no script, no `-c`, no `-m` and nothing fed to it, bare, behind a path, a quote or a wrapper, in a chain, with a time limit or a redirect (test) · `python3 - < x.py`, a pipe into it, a script file, `--version` and `command -v python3` pass (test) · a command between two quoted strings (`echo "a"; sleep 999; echo "b"`) reaches the hang rules (test)
- PRD: none
- Stories: none
- Source: Director-Driven-Development B66

### T45 · A session reports processes that outlived the shell that started them · done · M · agent
- Touches: framework/.claude/hooks/orphan-report.sh (new), framework/.claude/settings.json, PRIVACY.md, README.md, selftest.sh, CHANGELOG.md, TASKS.md
- Done when: a new SessionStart hook, `orphan-report.sh`, added to the `startup|resume` entry of `.claude/settings.json` that already runs the release check, with a 10 second timeout, reads the process list and prints one line of JSON with a `systemMessage` for the human and an `additionalContext` for Claude (`Processes that outlived the shell that started them (parent gone, over an hour old): pid 35660 python3.13 (14 h), pid 25748 node (2 d). They may be left over from an ended session. Stopping them is your call.`, with the instruction to tell the human once, in the first reply, and not to stop them unless the human asks) only when a process is listed (check) · the list is PowerShell's `Get-CimInstance Win32_Process` on Windows (`uname -s` is `MINGW*`, `MSYS*` or `CYGWIN*`), under `timeout 8` when `timeout` exists, and `ps -A -o pid=,ppid=,etime=,comm=` elsewhere, with `etime`'s `[[dd-]hh:]mm:ss` read into seconds and `comm` cut to its base name; an orphan is named `python`, `python3`, `python3.<n>`, `pythonw`, `py`, `node`, `bash`, `sh`, `godot*` or `chrome-headless-shell` (any case, `.exe` dropped), an hour old or more, with a parent that is gone (a ppid of 0 or 1, no row with that id, or a parent row younger than the process); the oldest ten are listed, oldest first, ages as `<n> h` up to 48 hours and `<n> d` after, and `, and <n> more` ends a longer list; whatever comes from the list is reduced to `[A-Za-z0-9._-]` (check) · the hook only reads: it never stops, signals or changes a process and writes no file, `SATT_ORPHAN_REPORT=0` exits at once, a failed, timed out or missing process tool prints nothing, every path ends in exit 0, a healthy session prints nothing, and the check, the git hooks and the Stop hook don't run it (check) · `PRIVACY.md` says the hook reads the names, ids and ages of the processes on the machine, stores nothing and sends nothing, and how to turn it off, with "Only your app's repository" no longer claimed, and the README's hooks list names it (check) · the selftest runs the hook against stub `uname`, `ps`, `powershell.exe` and `timeout`, with a case for an hour-old `python3.13.exe` with a dead parent, a live parent, 59 minutes, a younger parent row, names that are and aren't listed, eleven orphans printing ten and `and 1 more`, odd characters in a name, the three `etime` shapes, the off switch, a failed, timed out or missing tool, and a stub `kill`, `taskkill` and `pkill` that are never called, plus the wiring and the install, and passes (check) · the entry sits under the 0.16.0 heading, with upgrade steps
- PRD: none
- Stories: none
- Source: Director-Driven-Development T310

### T44 · A session says when the project is behind the latest release · done · M · agent
- Touches: framework/.claude/hooks/release-check.sh (new), framework/.claude/settings.json, PRIVACY.md, README.md, selftest.sh, CHANGELOG.md, TASKS.md
- Done when: a new SessionStart hook, `release-check.sh`, wired in `.claude/settings.json` with the matcher `startup|resume` and a 10 second timeout, compares the version on the first line of `.satt/manifest` (without any ` + unreleased ...` tail) with the highest `v<major>.<minor>.<patch>` tag of `https://github.com/Freakling/SaaSAllTheThings.git`, compared field by field as numbers, and prints one line of JSON with a `systemMessage` for the human and an `additionalContext` for Claude (`SaaSAllTheThings <installed> is installed, and the latest release is <latest>. Ask the agent to upgrade it when it suits you.`, with the instruction to tell the human once, in the first reply) only when the latest is above the installed version (check) · the tag list is read with `GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs`, under `timeout 5` when `timeout` exists, at most once a day: the version found last is kept in `.satt/state/latest-release`, looked up again only when the file is missing or a day old, and a failed lookup keeps the old value and touches the file (creating it empty), so an offline machine pays for one try a day; tags of any other shape are ignored (check) · `SATT_RELEASE_CHECK=0`, no `.satt/manifest` and no version line exit at once, every path ends in exit 0, a healthy session prints nothing, and the check, the git hooks and the Stop hook don't run it, so a warning never fails `tools/check.sh` (check) · `PRIVACY.md` says the framework sends nothing apart from the release check, with a Release check paragraph that says what is read, that no project data is sent and how to turn it off, and the README's privacy line agrees (check) · the selftest runs the hook against stub `git` and `timeout` with a case for behind, 1.9.0 against 1.14.0 and the reverse, equal and newer, an unreleased install, a fresh cache, a day-old cache, a failed or timed out git, no git, no timeout, other tags, the switch, a missing manifest, the wiring and the install, and passes (check) · the entry sits under the 0.16.0 heading, with upgrade steps
- PRD: none
- Stories: none
- Source: Director-Driven-Development T308

### T43 · The guard blocks any Python that reads its script from a heredoc · done · M · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.satt/rules.md, skills/saas-design-session/references/ (`bash bundle.sh`), selftest.sh, CHANGELOG.md, TASKS.md
- Done when: the guard blocks a Python interpreter (`python`, `python3`, `python3.13`, `pythonw`, `py`, with or without `.exe`, bare or behind a path with `/` or `\`, quoted or not) that reads its script from a heredoc or a here-string, whatever the body, in place of the empty-body check: with `-` or without it, with options before it (`-u`, `-X utf8`, `py -3`), in each heredoc form (`<<E`, `<<'E'`, `<<"E"`, `<<\E`, `<<-E`), behind a wrapper or in a chain (`timeout 60`, `env X=1`, `cd x &&`, `2>/dev/null || true`), piped in from a heredoc (`cat <<'E' | python -`) or, in PowerShell, from a here-string (`@'` ... `'@ | python -`), split by a continuation, inside a heredoc body a shell runs, and as the first half of the node fallback form (`python3 - <<'E' 2>/dev/null || node -e "` on a line, its string closed on the next, then `E`), in the Bash and the PowerShell tool, with a message that names python and says what to do (check) · a script file fed data from a heredoc (`python tool.py <<'E'`), `python -c`, `python -m`, `python3 --version` and a message that names the form (a commit's or tag's body, `gh pr create --body-file - <<'E'`, an `echo` or `grep` of the text, a `cat > notes.md <<'E'` body that isn't run) still pass (check) · `rules.md` › Commands that may run long says never to feed Python its script from a heredoc, to put it in a file, and to probe with `python3 --version`, in place of the empty heredoc probe, and the `saas-design-session` copy is rewritten by `bash bundle.sh` (check) · the guard's own comments describe no empty-heredoc rule, a 30 KB body is still judged in the guard's timed case, the selftest has a case for each blocked and each allowed form above in both tools, with the cases that expected a Python heredoc with a body to pass now expecting a block, and passes (check) · the entry sits under the 0.16.0 heading
- PRD: none
- Stories: none
- Source: Director-Driven-Development T309

### T42 · Subagents write no shell heredocs, and the background commands they leave are stopped · done · M · agent
- Touches: framework/.satt/rules.md, framework/.satt/procedures/build.md, research.md, review.md and next-task.md, framework/.claude/agents/builder.md, researcher.md and reviewer.md, skills/saas-design-session/references/ (`bash bundle.sh`), CHANGELOG.md, TASKS.md
- Done when: `rules.md` › Doing the work has a Shell commands bullet: files are written with the file tools, never with a shell heredoc or an `echo` or `printf` redirect of multi-line content; a multi-line script goes in a file first; every shell call is one short command, and the only long runs are the check, a build and a host start, each with an explicit long timeout; a command moved to the background is stopped before a report or the end of a turn (check) · `build.md` says it before step 1, has a step 7 before Report that stops a command moved to the background and never reports while one is alive, and a `Background:` line in the report (check) · `research.md` › Core procedure and `review.md` say it in one sentence each (check) · `next-task.md` › 3. Build stops what a subagent left in the background before it deletes `.satt/state/building` and moves on, tool-neutral, with its In Claude Code bullet naming TaskStop, and Review and Research items point to it (check) · `builder.md`, `researcher.md` and `reviewer.md` each carry one line with the rule, and their tools lists are unchanged (check) · the entry sits under the 0.16.0 heading, and the selftest passes (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development T305

### T41 · The Stop hook runs the check only for the session that changed the code · done · M · agent
- Touches: framework/.claude/hooks/stop-check.sh, framework/.claude/hooks/session-touched.sh (new), framework/.claude/settings.json, framework/.satt/rules.md, README.md, selftest.sh, CHANGELOG.md
- Done when: the Stop hook runs the project check only when this session itself wrote or edited a source file (any file but `*.md`, with `adr/` counting as source, the hook's present rule) since its last passing check: a new PostToolUse hook, `session-touched.sh`, on Edit, Write, MultiEdit and NotebookEdit records the paths the tool touched in `.satt/state/sessions/<session_id>.touched` (the hook input's `session_id`), and for Bash and PowerShell a PreToolUse snapshot of `git status --porcelain --untracked-files=all` and the same hook after the command record the source files that are new in the list or modified since (one `find -newer` for all of them); a session that touched only docs (`*.md` outside `adr/`, product/, TASKS.md) never triggers the check; the builder marker, the fingerprint (the same failure isn't reported twice), `SATT_STOP_CHECK=0`, the prototype exit and the exit 0 when tools/check.sh is missing keep working; no or a malformed `session_id` behaves as before; the session's record is removed when the check passes, and records older than a day are ignored and deleted (check) · in a design session that edits only Markdown while another session has uncommitted a source file in the same folder, the Stop hook exits at once without running the check, tested with scripted hook input; a session that edits a source file still gets the check and is blocked once on failure; a Bash command that creates a source file is recorded; a passing check removes the record; a record older than a day is ignored; no session_id behaves as before; settings.json wires the hook; both hooks use no bash 4 form or GNU-only flag; the selftest passes (check) · the entry sits under the Unreleased heading, with upgrade steps
- PRD: none
- Stories: none
- Source: Director-Driven-Development T297

### T40 · The guard reads a command's name written as a path, so a quoted or backslash path can't hide git, az or a Remove-Az cmdlet · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, selftest.sh, CHANGELOG.md
- Done when: the guard blocks `"C:\Program Files\Git\bin\git.exe" push --force`, `& "C:\Program Files\Git\cmd\git.exe" push --force`, `& 'C:\Program Files\Az\Remove-AzResourceGroup' -Name rg`, `"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" group delete -n rg` and `C:\bin\az.cmd group delete -n rg` in the Bash and the PowerShell tool, as it blocks the bare names: a quoted command name with a space, and a backslash path, is read as its last part without .exe, .cmd or .bat, in any case, when it is the first word of a segment (after NAME=value or a wrapper) or the word after a PowerShell & or . call operator; `git commit -m "... C:\Program Files\Git\bin\git.exe push --force ..."`, `echo "C:\Program Files\Az"`, `& 'C:\Program Files\Git\bin\git.exe' status` and `"C:\Program Files\Git\bin\git.exe" log -1` still pass; the selftest covers each in both tools (check) and passes (check) · the entry sits under the Unreleased heading
- PRD: none
- Stories: none
- Source: Director-Driven-Development T290

### T39 · The guard reads a wait loop to its own done, a fractional pause, empty view flags, a 30 KB body in time, and a message's names as text · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, selftest.sh, CHANGELOG.md
- Done when: the hang check ends an until or while loop at the done that closes it as a command, with a nested loop's do and done counted (`until [ -f done ]; do sleep 5; done` and `while true; do for f in a b; do :; done; sleep 5; done` are blocked); a pause with a fraction is judged as its whole part is (`sleep 600.5`, `Start-Sleep -Seconds 600.5`); the view flags and the arrays they're read from start empty, so an exported vhang=1 skips no git rule; the checks over the command's text skip the bodies nothing runs (a cat or tee body, a commit's or gh message, a PowerShell here-string), so a 30 KB heredoc and here-string are judged in under 5 seconds, timed in each shell by the selftest; the credential-print rules read the text without a commit's or gh message, so `git commit -q -m "... gh auth token ..."` passes and `gh auth token` still blocks; the selftest covers each (check) and passes (check) · the entry sits under the Unreleased heading
- PRD: none
- Stories: none
- Source: Director-Driven-Development T288

### T38 · The Azure delete rule covers the Az PowerShell module's Remove-Az cmdlets · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, selftest.sh, CHANGELOG.md
- Done when: the guard blocks each `Remove-Az*` cmdlet (`Remove-AzResourceGroup`, `Remove-AzResource` and the rest) in any case, after a module or a path (`Az.Resources\Remove-AzResourceGroup`), through every reading the `az ... delete` rule takes (as written, joined after a continuation, after a comment, inside a substitution, a `powershell -Command` or `pwsh -c` script, `Invoke-Expression` in PowerShell, a heredoc body a shell runs), in the Bash and the PowerShell tool, and passes the `Get-Az` reads and a commit's or tag's `-m` value or a heredoc body that names one and runs nothing; `framework/.claude/settings.json` denies `PowerShell(Remove-Az*)` next to `PowerShell(az group delete *)`; the selftest covers each and checks the settings rule (check) and passes (check) · the entry sits under the Unreleased heading
- PRD: none
- Stories: none
- Source: Director-Driven-Development T286

### T37 · Nothing is written until the director approves a summary of it · done · L · agent
- Touches: framework/.satt/rules.md, framework/.satt/procedures/design.md, framework/.satt/procedures/research.md, framework/.satt/procedures/next-task.md, framework/.satt/procedures/drift-reset.md, framework/.satt/procedures/ui-design.md, framework/.satt/procedures/acceptance.md, framework/.satt/procedures/feedback.md, framework/.satt/procedures/architect.md, framework/.satt/procedures/integrate.md, framework/.satt/procedures/assess.md, framework/.satt/procedures/align.md, framework/.satt/procedures/roadmap.md, framework/.satt/workshops/README.md, framework/.claude/skills/design/SKILL.md, framework/validation/README.md, skills/saas-design-session/SKILL.md (and its references/, from bundle.sh), ONBOARDING.md, README.md, examples/scenarios.md, selftest.sh, CHANGELOG.md
- Done when: `rules.md` › Who decides has the bullet that nothing is written without the human's explicit approval, right after the product-call bullet, and its ADR bullet says an ADR is accepted only by the director's approval of the summary that lists it, keeping the hook's confirmation of `Status: accepted`; `design.md` holds an answer in the conversation instead of recording a part, has a Summary and approval section between For each question and Record each decision in one change (with each ADR and the status it will be written with), and its Finish writes and commits what the approved summary lists; the stories validation and the prototype harvest (with each ADR's status) summarise before they write; `research.md` holds the note and its `R<n>` item until the summary is approved, in a session and in a standalone `/research`; `next-task.md` › Report `blocked` records a product decision only after the summary is approved, and `blocked: architecture` points to `architect.md` › Summary and approval; `architect.md` writes the ADR, its exceptions, the TASKS.md items, the AGENTS.md lines and the compliance mapping rows only after that summary; `integrate.md` holds each round's answers and fills `contract.md` after its summary; `assess.md` › Process workshop notes, `acceptance.md` and `feedback.md` (whose bugs no longer become items "straight away") summarise before the first record; `drift-reset.md` shows one summary with the decisions, the design diff with `prd-before.md`, and the rebuild plan's items before anything but the analysis files is written, commits it as one change, and the postmortem's chosen checks and items likewise; `ui-design.md` process records once the director approves a summary of the spec, the decision lines, the open questions and the item; `align.md` lists its mechanical fixes in the summary, and they join a session's summary or, during onboarding, are approved at its step 10; `roadmap.md` writes the Milestones rows and the stage's items after a summary, which during onboarding joins onboarding's; a one-to-one design session writes its notes after the approved summary, and in a live group workshop the read-back is the summary the room approves (`workshops/README.md`, the `saas-design-session` skill); `ONBOARDING.md` writes the stack's records, ADR-1 accepted by the approval of their summary, and the content's records, the roadmap's included, after the summary at the end of its section; the design skill's description mentions the approval; `selftest.sh` checks the bullet, the ADR sentence, the section and each pointer, and the selftest passes (check) · the entry sits under the Unreleased heading
- PRD: none
- Stories: none
- Source: Director-Driven-Development T281

### T36 · The guard and the deny rules reach the PowerShell tool, and a continuation, a tab or a PowerShell read can't hide from it · done · M · agent
- Touches: framework/.claude/settings.json, framework/.claude/hooks/guard-commands.sh, selftest.sh, CHANGELOG.md
- Done when: the guard hook's matcher names `Bash|Monitor|PowerShell` and every Bash deny and ask rule in `framework/.claude/settings.json` has a `PowerShell(...)` twin, with no PowerShell allow rule; the guard closes the gaps Director-Driven-Development closed in its B25, B27 to B40, B42 to B52, B55 and B60 (a line continuation, a tab, PowerShell's readers and backtick, comments, command substitutions, variables, shell wrappers, wait loops, heredoc bodies, git configuration and program flags, a quoted or capitalised name, Invoke-Expression), including the readings of a continued command (as written, as joined, and joined from each line after a comment), and reads SaaSAllTheThings' own rules (deleting Azure resources, a complete-mode deployment, a Key Vault secret read, a client secret, a prototype that never deploys) the same way; every case is in the selftest, run in parallel batches; the hook uses no bash 4 form (case conversion, a negative substring offset, a quoted replacement string) and starts no other process; the selftest passes (check) · the entry sits under the Unreleased heading
- PRD: none
- Stories: none
- Source: Director-Driven-Development T277

### T35 · A quoted no-verify and a gate edit can't get a commit past the hooks · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/hooks/guard-authority.sh, framework/tools/prototype.sh, selftest.sh, CHANGELOG.md
- Done when: the guard blocks `git commit` with `-n` or `--no-verify` quoted or split; in a prototype, Edit and Write are refused on the hooks, the guard, `tools/prototype.sh`, `tools/setup-clone.sh` and the files that excuse a scan finding without the human, and `prototype.sh harvest` and `list` name any of those that differ from main's; the selftest covers each (check) · the entry sits under the 0.15.0 heading, and the release notes in #45 say so (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development T272

### T34 · A prototype routine, apart from real building · done · M · agent
- Touches: framework/.satt/procedures/prototype.md (new), framework/.claude/skills/prototype/SKILL.md (new), framework/tools/prototype.sh (new), framework/.githooks/pre-push (new), framework/.satt/rules.md, framework/.satt/tasks.md, framework/.satt/procedures/design.md, framework/.satt/procedures/build.md, framework/.satt/procedures/release.md, framework/.githooks/pre-commit, framework/tools/setup-clone.sh, framework/.claude/hooks/stop-check.sh, framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, skills/saas-design-session/SKILL.md, skills/saas-design-session/references/ (bundle.sh), README.md, ONBOARDING.md, selftest.sh, CHANGELOG.md
- Done when: a tool-neutral `prototype.md` procedure and a `/prototype` skill: `/prototype <name>` creates a git worktree beside the project on a new `proto/<name>` branch from the local `main` (no upstream; when `origin/main`, as last fetched, is ahead, it creates nothing and offers `git pull --ff-only`, which the director approves, or starting from main as it is), runs `bash tools/setup-clone.sh` there, writes and commits its `PROTOTYPE.md` (what we're trying, how it felt, what to keep), and starts or tells the director how to open a session in that folder; it refuses an invalid name and one whose branch or folder exists (check) · a prototype is a linked worktree on a `proto/` branch with `PROTOTYPE.md` at its root (`bash tools/prototype.sh here`); its session reads In a prototype session first, the loop in `rules.md` is off there (no items, records, builder or reviews), commits need no approval, the pre-commit hook skips the project check but keeps the secrets scan (`bash tools/check.sh --secrets`, the check's own) on every commit, blocks a commit while the scan can't run or `adr/`, `tools/check.cfg`, `tools/check.sh`, `tools/archcheck.awk` or a `.gitattributes` differs from main's in the index, on disk or untracked (and the scan reads the index too, and exits 3 when `git grep` fails), the Stop hook skips the check, the guard stays on, a pre-push hook refuses a `proto/` branch or any commit only a `proto/` branch has, and nothing is merged; `start` refuses unless main has the hooks, the scan and the script committed and this clone has SaaSAllTheThings' hooks and a scan that runs, and setup-clone installs both hooks even when the toolchain is missing (check) · a prototype never deploys to any Azure environment, dev included: the procedure and `rules.md` say so, and in a prototype session the guard blocks `az`, `azd`, `func azure` and `gh workflow run`, which the ask rules and `release.md` keep with the director elsewhere (check) · `/prototype harvest <name>` in the main session reads the prototype's diff against main and its notes and runs the product session on them, proposing decisions, user stories and items that each name the prototype (`Prototype: proto/<name>`) and land in the PRD's capabilities as usual, built from main like any item with the builder reading the prototype's diff as a reference; what the prototype did against the reference architecture goes through `/architect` and an ADR, as in any design; it files nothing without the director, and a drafted story they don't answer stays out; it then offers to remove the worktree, never forced (the guard blocks `git worktree remove --force` in any form, brace expansion and `$IFS` included), and, since the guard keeps branch deletion and overwrites with the director (`-D`, `-d` with force, `-M`, `-C`, `worktree add -B`), the director runs `git branch -D` themselves; `/prototype list` shows the prototypes; `rules.md`, the item format, the README and ONBOARDING describe it; `selftest.sh` checks the procedure, the skill, the hooks (a staged secret and a scan that can't run are still blocked in a prototype, and every near miss runs the check), the guard and the script on throwaway repositories, one in a folder with a space, and passes (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development T265

### T33 · User stories anchor every item · done · L · agent
- Touches: project/product/user-stories.md (new), framework/tools/stories.sh (new), framework/.satt/tasks.md, framework/.satt/rules.md, framework/.satt/procedures/design.md, framework/.satt/procedures/next-task.md, framework/.satt/procedures/acceptance.md, framework/.satt/procedures/align.md, framework/.satt/procedures/assess.md, framework/.satt/procedures/build.md, framework/.satt/procedures/ui-design.md, framework/.satt/procedures/drift-reset.md, framework/.satt/procedures/roadmap.md, framework/.satt/templates/assessment.md, framework/.satt/workshops/README.md, framework/.satt/workshops/capabilities.md, framework/.claude/skills/design/SKILL.md, framework/.claude/skills/align/SKILL.md, framework/.claude/skills/assess/SKILL.md, framework/.claude/settings.json, skills/saas-assessment/SKILL.md, skills/saas-design-session/SKILL.md, skills/saas-design-session/references/ (bundle.sh), project/product/prd.md, project/TASKS.md, project/tools/check.cfg, examples/order-desk/product/user-stories.md (new), examples/order-desk/product/prd.md, examples/order-desk/TASKS.md, examples/order-desk/tools/check.cfg, ONBOARDING.md, README.md, selftest.sh, CHANGELOG.md
- Done when: `project/product/user-stories.md` is a seed with a worked example: a header with the next story ID (`US-<n>`) and the date and commit the stories were last validated, the value in one paragraph per role, the roles (the personas in PRD › Personas and Roles, by the same names), and a table per area with the ID, the story ("As a <role> I <do something>, so <why>") and the date the director confirmed it, or `unconfirmed`; the PRD seed links it and each capability names the stories it serves (check) · the item format gains `Stories:` (the IDs an item serves, or `none` for foundation, tooling and infrastructure), the TASKS.md seed and the example show it, `rules.md` names the file in "Each fact lives in one place", the product session drafts the stories a design needs and puts them to the director, and a feature item with no story gets one drafted before it is built (check) · the director validates on a cadence: `bash tools/stories.sh --due` counts built items since the Last validated commit against `[stories] every` (10 by default) as next-task counts for the security assessment, next-task proposes the validation and names it in a run's final report, each acceptance check asks "still right?" of the stories behind its items, and align lists stories no item serves, feature items with no story and stories unconfirmed past the cadence; onboarding drafts a fresh app's stories from the interview and writes an existing app's from the code, unconfirmed; `/assess` writes the stories it finds in an existing app or proof of concept into its report, unconfirmed, and workshop notes name the stories a workshop adds or changes; `selftest.sh` checks the seed, the example, the field, the setting and the due count, and passes (check)
- PRD: none
- Stories: none
- Source: Director-Driven-Development T262

### T32 · The guard and the Read rules block reads of .env.local and the other .env.<suffix> files · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, selftest.sh, CHANGELOG.md
- Done when: the template's settings deny the Read tool `.env.local`, `.env.production`, `.env.development`, `.env.staging` and `.env.test` in their plain and `**/` forms, and `.env.*.local`, and the guard hook blocks shell reads of any `.env.<suffix>` file with `cat`, `head`, `tail`, `less`, `more` or `strings`, quoted paths and several files on one line included, and passes `.env.example`, `.env.sample`, `.env.template` and `.env.dist` (check) · `selftest.sh` runs each case through the guard, and fails when the settings template lacks any of the twelve Read rules (check)
- PRD: none
- Source: Director-Driven-Development T253

### T31 · The guard and the Read rules block reads of .env, .pem and .key files · done · S · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, selftest.sh, CHANGELOG.md
- Done when: the template's settings deny the Read tool `.env`, `*.pem` and `*.key` files (`.env`, `**/.env`, `*.pem`, `**/*.pem`, `*.key`, `**/*.key`), and the guard hook blocks shell reads of them with `cat`, `head`, `tail`, `less`, `more` or `strings`, quoted paths included, and passes `.env.example`, `README.md` and `docs/keys.md` (check) · `selftest.sh` runs each case through the guard, and fails when the settings template lacks any of the six Read rules (check)
- PRD: none
- Source: Director-Driven-Development T248

### T30 · The guard closes the git grep pager, the credential stores and the unscanned commits · done · M · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, framework/.githooks/pre-commit, framework/tools/check.sh, README.md, selftest.sh, CHANGELOG.md
- Done when: the guard hook blocks `git grep -O` and `--open-files-in-pager` in every short, combined and abbreviated spelling, and the shell reads of `~/.ssh`, git's credentials files and the gh CLI's `hosts.yml` in any spelling of the path, and `gh auth token`, `gh auth status -t` and `git credential fill|get`, and passes the plain forms the procedures use (check) · the settings template denies `Bash(git grep *--open*)`, `Bash(git grep *-O*)` and the Read tool the five credential stores, and `selftest.sh` fails when it allows `git grep *` without the two Bash rules or lacks any of the five Read rules (check) · the pre-commit hook runs the check's secrets rule (`bash tools/check.sh --secrets`) on every commit, so a Markdown-only commit holding a secret is blocked without running the whole check (check)
- PRD: none
- Source: Director-Driven-Development T242

### T29 · The guard blocks the git flags that write or read any file · done · M · agent
- Touches: framework/.claude/hooks/guard-commands.sh, framework/.claude/settings.json, selftest.sh, CHANGELOG.md
- Done when: the guard hook blocks the git flags that write a file (`--output`), read a file outside the repository (`--no-index`, `commit -F` and `--file`, a `git diff` of a path outside it) or run a configured command (`--ext-diff`), and passes the plain forms the procedures use (`git commit -F -`, `git commit -m "..."`) (check) · the settings template denies `Bash(git *--output*)`, `Bash(git *--no-index*)`, `Bash(git *--ext-diff*)` and `Bash(git commit *--file*)` (check) · `selftest.sh` feeds the hook each case, and fails when the template allows a wildcard git rule (`git diff *`, `git log *`, `git show *`, `git stash *`, `git commit *`) without all four deny rules (check)
- PRD: none
- Source: Director-Driven-Development T235

### T28 · The screen-capture tooling asks for Node 20, as Playwright does · done · XS · agent
- Touches: framework/tools/ui/package.json, framework/tools/ui/capture.mjs, framework/tools/ui_capture.sh, framework/.satt/procedures/ui-design.md, examples/order-desk/product/ui/README.md, project/product/ui/README.md, ONBOARDING.md, selftest.sh, CHANGELOG.md
- Done when: `engines.node` in `framework/tools/ui/package.json`, the Node check in `framework/tools/ui_capture.sh` and the message in `framework/tools/ui/capture.mjs` say Node 20 or newer, the lowest Node that `playwright` 1.64.1 declares (`npm view playwright@1.64.1 engines`) (check) · the docs, onboarding and selftest name Node 20 everywhere they named the old floor, and the selftest refuses a Node 19 with that wording (check)
- PRD: none
- Source: Director-Driven-Development T220

### T27 · The screen-capture tooling pins Playwright to one exact version · done · XS · agent
- Touches: framework/tools/ui/package.json, framework/tools/ui/.npmrc, tests/ui-web/package.json, selftest.sh, CHANGELOG.md
- Done when: `framework/tools/ui/package.json` and `tests/ui-web/package.json` pin `playwright` to `1.64.1` with no `^` or `~`, and `framework/tools/ui/.npmrc` keeps `package-lock=false` and says why (check) · the selftest fails when either pin is a range (check)
- PRD: none
- Source: Director-Driven-Development T219

### T26 · The OWASP baseline moves to the Top 10 (2025) · done · M · agent
- Touches: framework/.satt/rules.md, framework/.satt/reference/owasp.md, framework/.satt/procedures/security.md, framework/.satt/procedures/review.md, framework/.satt/procedures/align.md, project/compliance/mapping.md, ONBOARDING.md, README.md, selftest.sh, CHANGELOG.md
- Done when: the baseline, the checklist and the seed mapping rows use the OWASP Top 10:2025 categories and names, SSRF sits under A01, A03 covers supply chain checks, A10 Mishandling of Exceptional Conditions is added, and the CHANGELOG maps each 2021 row to its 2025 row (test)
- PRD: none
- Source: Director-Driven-Development T203

### T25 · A recurring security assessment validates what is built against the OWASP baseline · done · L · agent
- Touches: framework/.satt/procedures/security.md (new), framework/.satt/reference/owasp.md (new), framework/.claude/skills/security/SKILL.md (new), framework/.satt/reference/README.md, framework/.satt/procedures/release.md, framework/.satt/procedures/next-task.md, framework/.satt/rules.md, project/tools/check.cfg, examples/order-desk/tools/check.cfg, ONBOARDING.md, README.md, skills/saas-design-session/SKILL.md, skills/saas-design-session/references/ (bundle), tests/security/ (new), selftest.sh, CHANGELOG.md
- Done when: `/security` runs the tools first (each skipped with a note when not installed, never installed without asking), then a fresh-context reviewer through the OWASP Top 10 and API Security Top 10 checklist in `reference/owasp.md` citing file and line; findings become bug items with OWASP item, severity, evidence and a proposed fix, high first; people and process work goes to the director; the report is written to `assessment/security/YYYY-MM-DD.md` with a line per category (check) · it runs on request, in the release procedure before a release, and is proposed by `/next-task` every `[security] every` items, default 10 (check) · a tool passing never marks a category met, and the report says what a clean run doesn't prove (check) · the self-test proves the seeded vulnerable fixture is reported by the check's rules with their OWASP items and the clean twin isn't, with the dependency audits where installed (check) · the assessment updates the OWASP rows of `compliance/mapping.md` and flags the customer's rows a finding touches (check)
- PRD: none
- Source: Director-Driven-Development T201

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
