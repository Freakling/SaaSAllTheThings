<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Security assessment

Validate what is built against the OWASP baseline (`rules.md` › Architecture in code), with the checklist in `.satt/reference/owasp.md`: tools first, then a reviewer pass in a fresh context, then findings as bug items, a list for the director, a dated report, and the OWASP rows of `compliance/mapping.md` brought up to date. It finds and proposes; the director decides.

It runs:
- on request (`/security`, "run a security assessment", "check the app against OWASP");
- in `release.md`, before a release is proposed, when something was built since the last report or there is none;
- when `next-task.md` proposes it, once `tools/check.cfg` › `[security] every` items (10 when the key is absent) are done since the last report. The human can decline; a run of several items carries on picking and only names it.

Ground rules:
- **Never install a tool without asking.** A tool that isn't installed is skipped with a note in the report; offer the install command to the human.
- **Never call Azure or change cloud resources.** It reads the repository and, with `gh`, the repository's CI runs. The dependency audits send package names and versions to public advisory databases, never code.
- **It changes only** the report, TASKS.md and the OWASP rows of `compliance/mapping.md`. It fixes nothing itself: fixes are bug items, built as any item is.
- **Never quote a secret.** Evidence, the report and bug items never quote a secret, token, key or connection string, or the line that holds one: only `file:line` and the kind of secret ("a storage account key").
- **A tool passing never marks a category met.** A category is `verified` only when the reviewer has read the code and configuration each of its checks concerns. The report says what a clean run doesn't prove.

## 1. Tools
Note the date and the commit (`git rev-parse --short HEAD`, and whether the tree is clean). Run each tool that applies, with a time limit under five minutes where `timeout` is available (`timeout 240 …`), and keep each one's result for the report: ran (with its version, exit code and what it found), skipped (not installed, no manifest for it, or no network), couldn't run (with its reason: a package manager that isn't cached, a prompt it would need), or not applicable. Give every command `</dev/null`, so none waits for input. Each result goes under the OWASP item `owasp.md` › What the tools cover gives it.

A tool is clean only when it exits 0 and prints its nothing-found summary (`found 0 vulnerabilities`, `has no vulnerable packages`, `No known vulnerabilities found`, an empty Semgrep result with no errors). A timeout (exit 124), a network or restore error (`ENOTFOUND`, `ETIMEDOUT`, `NU1301`, an unreachable advisory database), or Semgrep `errors` entries make it "couldn't run", with the reason; never clean.
1. **The check's rules:** `bash tools/check.sh --architecture`. Its `[secrets]` lines are A04, `[tenant-source]` and `[tenant-branching]` A01 (and API1), `[network-public]` A02. When it notes that `network-public` is off, that is an A02 finding unless an accepted ADR says why.
2. **.NET**, where the app has a `*.csproj`: `dotnet list <target> package --vulnerable --include-transitive` on the target the check builds (`tools/stacks/dotnet.sh`): `tools/check.cfg` › `[project] target`, else the `.slnx` at the root, else the `.sln` at the root; never blindly in the root. Run `dotnet restore <target>` first if it asks for one.
3. **Web clients**, in each folder with a `package-lock.json`, skipping `node_modules/`: `COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 npm audit --omit=dev </dev/null`. The two settings stop Corepack downloading a package manager or prompting for one; a package manager that isn't cached is "couldn't run", with its reason. Probe a tool the same way (`npm --version </dev/null`). `tools/ui/` holds the framework's capture tools, which never ship with the app: report its audit as information, not as a finding.
4. **Python**, where the app has `requirements.txt` or `pyproject.toml`: `pip-audit --disable-pip --no-deps -r requirements.txt`, and only when every requirement in the file is pinned with `==`. Plain `pip-audit` builds a temporary environment and installs the requirements, which runs their build code, so never run it that way. A file with an unpinned requirement is skipped with a note naming it; so is a `pyproject.toml`, unless the project has a pinned export of it (a requirements file with every line pinned), which is audited instead.
5. **Semgrep**, when it's installed. It downloads the rules from the Semgrep registry. Its output holds the matched source lines, which may hold a secret, so it goes only to the gitignored `.satt/state/`, and only fixed commands read it, printing nothing but `path:line:col:rule id`:
   ```
   semgrep scan --config p/owasp-top-ten --metrics=off --quiet --emacs-output=.satt/state/semgrep.txt --json-output=.satt/state/semgrep.json </dev/null >/dev/null 2>&1; echo "exit $?"
   awk -F: '{ print $1 ":" $2 ":" $3 ":" $4 }' .satt/state/semgrep.txt
   grep -c '"errors": *\[\]' .satt/state/semgrep.json
   ```
   The awk keeps the path, line, column and `severity(rule id)` of each result and drops the matched line after them. The last command prints `1` when Semgrep reported no errors; `0` is "couldn't run". Never print, read or quote the two files otherwise, in the report or anywhere else. The OWASP item is the one the rule id names.
6. **The CI workflow**, when the app has `.github/workflows/check.yml` and `gh` is installed and signed in: the latest `dependency-review` job on a pull request and the latest `sbom` artifact on main (`gh run list --workflow check.yml --limit 10`, then `gh run view <id>`). Otherwise skip it, saying which was missing.

A dependency advisory is a finding with the advisory's severity (critical counts as high). The rest of the tool results are findings as they stand, or candidates the reviewer confirms in step 2.

## 2. Reviewer pass
Hand the checklist to a fresh context so this session's context stays small and the reviewer reads the code without the session's assumptions.
- **In Claude Code,** a subagent with read and search tools only (Read, Grep, Glob), in the foreground, with its model set explicitly as `next-task.md` › Build says, from the `L` entry of the mapping (the size `tasks.md` gives a security comparison across several areas).
- **Other tools:** a subagent if your tool has them, or a fresh session, with the same model.

Give it this section, `.satt/reference/owasp.md`, the tool results from step 1, AGENTS.md › Architecture and Layout, `tools/check.cfg` › `[layers]`, and the accepted ADRs that name an OWASP item (`grep -ln "OWASP" adr/*.md`). The reviewer:
1. Goes category by category: A01 to A10, then API1 to API10 when the app serves an API.
2. For each `code` and `config` check, reads the code or configuration it concerns (the Where of the check), and decides:
   - **holds:** cite the `file:line` that makes it hold;
   - **fails:** a finding;
   - **not applicable:** say why (no web client, no integrations);
   - **not checkable here:** what it would need (a running environment, the Azure portal, a log query).
3. Confirms or drops each tool candidate, and checks a deviation against the accepted ADRs: an ADR that names the OWASP item and why makes it an accepted deviation, not a finding.
4. Collects the `people` checks as they are, without judging them.
5. Never edits a file or runs a command that changes anything. It returns, per category, one line (verified, findings, not checkable here, or not applicable) with the files it read, then the findings and the people checks.

Each finding has:
- the OWASP item (`A01`, or `API3 (row A01)`);
- the severity from `owasp.md` › Severity (high, medium or low; a tenant isolation break is always high);
- the evidence: `file:line`, what is wrong, and a concrete way it is exploited;
- a proposed fix: the smallest change that closes it, in the layer the reference puts it.

## 3. Findings
1. **Drop repeats.** A finding with the same OWASP item and file as an open bug in TASKS.md is already filed: name that bug in the report instead.
2. **File each new finding as a bug item** in the format in `.satt/tasks.md`: `### B<n> · <OWASP item>: <what's wrong> · todo · <size> · agent · high|med|low` (medium is `med` in the heading), with `Touches`, `Repro: <steps> → expected <the fixed behaviour> / actual <what happens now>` and `Found in: assessment/security/YYYY-MM-DD.md`. The report holds its evidence and proposed fix. IDs come from `Next IDs`, then bump it.
3. **High first.** Put the high items first in the queue, above the others you add; `next-task.md` › Pick builds high bugs before anything else.
4. A finding that needs an architecture call (the fix would break a reference rule, or the deviation should be accepted) says so: it's offered as an `architect.md` session, whose ADR names the OWASP item.

## 4. People and process
List the `people` checks for the director, one line each: what to do, and why (the OWASP item and what goes wrong without it). They include access reviews, incident response, alert routing and who is on call, key and certificate rotation, vulnerability response, who may merge and deploy, and the security officer's sign-off on the assessment. Mark the ones an earlier report's list already holds and nothing has changed. Add a `human` item (size `none`) for each one the director agrees to; never add one without asking.

## 5. Report
Write `assessment/security/YYYY-MM-DD.md` (today's date; create the folder on the first run; a second run on the same day adds `-2`):

```
# Security assessment YYYY-MM-DD
- Commit: <short hash> (clean | uncommitted changes: <paths>)
- Ran: <tool, version, exit code, findings>; ...
- Skipped: <tool>: <why (not installed, no manifest, no network, no gh)>; ...

## Categories
| Item | Result | Evidence |
|---|---|---|
| A01 Broken Access Control | verified / findings: B12, B13 / not checkable here / not applicable | files read, or why |
...
| API1 Broken Object Level Authorization | ... | ... |

## Findings
<per finding: bug ID, OWASP item, severity, evidence (file:line), proposed fix>

## Accepted deviations
<ADR, OWASP item, what it allows>

## For the director
<the people and process list: what to do and why>

## What a clean run doesn't prove
<for each tool that ran clean, its line from owasp.md › What the tools cover; and that checks
marked not checkable here need a running environment or the customer's records>

## Mapping
<the OWASP rows changed, and the customer's framework rows a finding touches>
```

## 6. The compliance mapping
When `compliance/mapping.md` exists (the seed has it):
- **Only these columns of these rows change:** Met by, Label and Evidence of the `OWASP A01` to `OWASP A10` rows. Never delete a row; a missing baseline row is reported and restored from the seed as `align.md` says. Keep an existing Met by entry unless the report shows it no longer holds.
- **Update the OWASP rows** (`OWASP A01` to `OWASP A10`) from what this assessment verified. Met by names what the reviewer saw meet the category: check rules, workflow jobs, ADRs, tests by path. Evidence names this report, beside the CI artifact where a rule or job meets it.
- **Labels.** `unverified` until the reviewer has read the code for the category. `partial` when some checks hold and others fail, can't be checked here, or are people checks the director hasn't confirmed. `interpretive` when it holds only under a reading the report states. Never `direct` from a tool alone: `direct` only when every check of the category is verified in this report, its people checks confirmed by the director, and Met by names what meets each. A category with an open high finding is at most `partial`, and its Evidence names the bug.
- **Rows of the customer's own framework** stay unchanged. Name the ones a finding touches (by what their Requirement asks) in the report's Mapping section and in the bug item's Repro; the human decides, in an architecture session when it needs one.
- An API item updates the Top 10 row `owasp.md` names for it.

## 7. Hand over
Tell the human, in a few lines: the result per category, the findings by severity with their bug IDs, the director's list, what was skipped and why, and the mapping rows changed. Commit the report, TASKS.md and `compliance/mapping.md` as `docs: security assessment YYYY-MM-DD`, with the approval `rules.md` › Git and Azure describes.
