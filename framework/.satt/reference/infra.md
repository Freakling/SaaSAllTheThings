<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Infrastructure

## Bicep
- `infra/main.bicep` composes one stamp; `infra/modules/<resource>.bicep` holds one Azure resource concern per file (functions, cosmos, servicebus, keyvault, monitoring, budget, identity).
- `infra/env/<env>.bicepparam` holds one environment's parameters. No secrets in parameters: Key Vault holds what can't be avoided (`identity.md`).
- Names follow Azure's abbreviations: `func-<app>-<env>`, `cosmos-<app>-<env>`, `sbns-<app>-<env>`, `kv-<app>-<env>`, `log-<app>-<env>`, with a region or stamp suffix once there are several. Tags: `app`, `env`, `stamp`, `owner`.
- Local modules only; no registry modules unless an ADR adds them.
- The check compiles `infra/*.bicep` and `infra/env/*.bicepparam` when the Bicep CLI is installed, and fails premium SKUs (`cost.md`).

## Environments
- **dev** and **prod** by default. Each is its own resource group, with its own identities and budget. A permanent test or staging environment, or short-lived environments per branch, is an ADR.
- Local development uses the Functions host with emulators (Azurite, the Cosmos DB emulator, the Service Bus emulator) and `DefaultAzureCredential`. Nothing needs a shared cloud resource to run locally.

## Access
- Each function app has its own managed identity, with data-plane roles on its own resources only, assigned in Bicep.
- People get access through groups, never individual assignments; production access is just-in-time (PIM) where the customer's governance has it.
- Local authentication off (Cosmos DB keys, Service Bus SAS, storage shared keys) wherever the service allows it.

## Delivery
- CI runs `bash tools/check.sh` on every pull request.
- Deploys sign in with workload identity federation (`identity.md` › Pipelines). dev deploys from the main branch; prod deploys from a tag, behind an approval in the pipeline's environment.
- Every deploy starts with a what-if (`az deployment group what-if`) and ends with a smoke test. `procedures/release.md` is the procedure.
- Never a complete-mode deployment: it deletes what the template doesn't list.

## Dependencies and the SBOM
- The shipped workflow (`.satt/templates/check-workflow.yml`) has two jobs beside the check. `dependency-review` runs on pull requests and fails one that adds a dependency with a high or critical advisory from GitHub's advisory database. `sbom` runs on each push to main and keeps the dependency graph as an SPDX document, `sbom.spdx.json`, in an artifact.
- Both read GitHub's dependency graph for the repository. It's on by default for public repositories; private repositories need GitHub Advanced Security or the setting turned on.
- Not covered: vulnerabilities in the app's code, its container images and its Azure resources, and transitive dependencies the graph can't see. The SBOM lists what the graph knows, so it isn't a complete inventory.
- Vulnerability response stays the customer's process: triage, the patch timelines and who acts on an advisory are the customer's, and nothing here sets them.
