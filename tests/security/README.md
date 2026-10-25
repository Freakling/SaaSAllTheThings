# The security assessment fixture

Two small apps in the shape of the reference architecture, used by `selftest.sh` and by a manual acceptance check of `/security` (`framework/.satt/procedures/security.md`). They are never compiled: only the check's architecture rules and the dependency audits read them.

- `vulnerable/` has the seeded faults below.
- `clean/` is its twin with each fault fixed.
- The manifests carry `.fixture` names (`package.fixture.json`, `package-lock.fixture.json`, `Shop.Functions.csproj.fixture`), so GitHub's dependency graph doesn't read this repository's fixture as its own dependencies. The self-test, and the manual check, rename them to `package.json`, `package-lock.json` and `Shop.Functions.csproj` in the copy.

| Seeded fault | Where | OWASP item | Found by |
|---|---|---|---|
| A storage account key in a config file | `vulnerable/src/Shop.Functions/appsettings.json` | A02 | the check's `secrets` rule (the self-test writes the fake key in at run time, in place of `SEEDED_ACCOUNT_KEY`, so this repository holds nothing that looks like a secret) |
| The tenant read from a request header instead of the token | `vulnerable/src/Shop.Functions/Orders/ListOrdersFunction.cs` | A01, API1 | the check's `tenant-source` rule |
| A Service Bus namespace with public access and local authentication on | `vulnerable/infra/modules/bus.bicep` | A05 | the check's `network-public` rule |
| A dependency with a published high advisory | `vulnerable/src/Shop.Functions/Shop.Functions.csproj.fixture` (Newtonsoft.Json 12.0.1), `vulnerable/clients/web/package-lock.fixture.json` (lodash 4.17.20) | A06 | `dotnet list package --vulnerable` where the .NET SDK is installed, `npm audit` where npm is; both need the network, and the self-test skips them with a note otherwise |
| Input joined into a query | `vulnerable/src/Shop.Infrastructure/Orders/OrderStore.cs` | A03 | may be found by the reviewer pass (manual check below), and by Semgrep where it is installed |
| A delete with no authorization check | `vulnerable/src/Shop.Functions/Orders/DeleteOrderFunction.cs` | A01, API5 | may be found by the reviewer pass (manual check below) |

## What the self-test proves
- The check's rules fire on `vulnerable/` (`secrets`, `tenant-source`, `network-public`) and not on `clean/`, and `owasp.md` › What the tools cover files each rule under the OWASP item above.
- Where npm, or the .NET SDK, is installed and the advisory database answers, the audit reports the seeded package in `vulnerable/` and nothing in `clean/`.
- The wiring: the procedure, the checklist, the skill, the release and next-task steps, and the `[security] every` setting.

## Manual acceptance check: the reviewer pass
The reviewer is an agent, so its findings aren't deterministic and the self-test doesn't run it. Before a release that changes `security.md` or `owasp.md`:
1. Copy `vulnerable/` into a scratch repository, rename the three `.fixture` manifests to their real names, install SaaSAllTheThings into it (`bash install.sh <folder>`), and replace `SEEDED_ACCOUNT_KEY` with a fake `AccountKey=` of 40 or more letters.
2. Run `/security` there.
3. The reviewer and Semgrep are not deterministic: they may find what is listed below; neither is certain to. Expect, in `assessment/security/<date>.md` and as bug items in TASKS.md, and treat a miss as something to look into rather than a failure in itself:
   - an A03 finding at `src/Shop.Infrastructure/Orders/OrderStore.cs` (the query text built from input), with a parameterized query as the fix;
   - an A01 (API5) finding at `src/Shop.Functions/Orders/DeleteOrderFunction.cs` (no role check), with a role check in the handler as the fix;
   - the tenant from a header as a high A01 (API1) finding (a tenant isolation break), the key as A02, the Bicep as A05, and the advisories as A06 where the audits ran;
   - a people and process list for the director, a line per category, and no category marked verified on a tool result alone;
   - the OWASP rows of `compliance/mapping.md` updated, none to `direct`.
4. Run it on `clean/` the same way (renaming its manifests, without step 1's key): expect none of those findings.
