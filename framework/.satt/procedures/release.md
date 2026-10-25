<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Release

Deploy the current main branch to an environment. Every step that touches Azure needs the human's approval, each time. **Production is the human's to deploy**: for prod, prepare everything and hand over the commands. Never run a complete-mode deployment, and never delete resources.

The request names the environment: `dev` (the default) or `prod`. The setup is in `.satt/reference/infra.md` › Delivery.

## 1. Ready?
1. The tree is clean and on the branch the environment deploys from (main for dev, a tag for prod).
2. `bash tools/check.sh` passes. If the app has `.github/workflows/check.yml` (`.satt/templates/check-workflow.yml`), the CI run for the release commit and its `check-<run number>-<attempt>` artifact are where that result is recorded off the developer's machine: name the run in the release record.
3. `infra/env/<env>.bicepparam` exists, and has no `PLACEHOLDER` the deploy needs (the budget amount, for one).
4. List what's in this release: the `done` items since the last release tag (`git log <last tag>..HEAD --oneline`), and contract changes in their reports or commit bodies. A breaking contract change without its `V<n+1>` side by side is a stop.
5. **Security assessment.** Run `security.md` on main at the release commit (never on a detached tag) before the release is proposed when something was built since the newest report in `assessment/security/`, or there is none. Whether or not it runs, an open `high` bug that names an OWASP item blocks the release, unless an accepted ADR deviates from that item, naming it and why (`architect.md`): fix it, or the director accepts the deviation. Name the report in the release record.

## 2. What-if
With the human's approval, run a what-if of the Bicep for the environment's resource group:
```
az deployment group what-if --resource-group <rg> --template-file infra/main.bicep --parameters infra/env/<env>.bicepparam
```
Summarise it: what's created, changed and deleted. Anything deleted, or anything outside this app's resources, is a stop: show it to the human.

## 3. Deploy
- **dev:** with the human's approval, deploy the infrastructure, then the function apps (by the pipeline if the project has one, or the commands AGENTS.md › Project facts names).
- **prod:** give the human the pipeline run or the exact commands, and the what-if summary. They run it.

## 4. Smoke test
- `GET /api/health` on each function app answers 200.
- One read as a test user of the test tenant, if the environment has one.
- Report anything that failed, with the log query to look at it. A failed smoke test is a `high` bug and, for prod, the human's call on rolling back.

## 5. Record
- Record the check's result for the release commit: the CI run and its artifact (see step 1), or the local result when the app has no workflow, and the security assessment's report (step 1).
- Tag a prod release `v<YYYY.MM.DD>` (or the project's scheme) after the human approves; push the tag only when asked.
- The `(demo)` outcomes now deployed go into the next acceptance check, with `Environment:` set.
