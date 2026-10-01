<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. Never edit it in a project: a project deviates
through an accepted ADR in adr/ (procedures/architect.md). -->
# The SaaSAllTheThings reference architecture

This folder is the architecture every SaaSAllTheThings project follows. It has authority: the product decides *what* to build, this decides *how it's shaped*. A rule here holds in a project unless an accepted ADR in `adr/` says otherwise, and the check accepts a violation only when an accepted ADR names it in an `Exception:` line.

Read only the topics the work touches.

| Topic | Holds |
|---|---|
| `layers.md` | the layers, what each owns, what each may depend on, the default layout |
| `tenancy.md` | pooled tenancy, the tenant registry, isolation, silo-readiness |
| `identity.md` | OIDC sign-in, federated identity, authorization, no secrets |
| `messaging.md` | events and commands, the outbox, idempotency, ordering, versioning |
| `data.md` | storage, partitioning, concurrency, files, retention |
| `api.md` | HTTP functions: routes, versions, errors, idempotency keys |
| `clients.md` | the Windows and mobile clients |
| `integrations.md` | enterprise integrations; Navision / Business Central first |
| `infra.md` | Bicep, environments, delivery, deploys |
| `cost.md` | the default SKUs and the cost guardrails |
| `observability.md` | logs, traces, health, alerts |
| `stacks.md` | compatible backend stacks, the check's stack profiles, choosing a stack for an existing app |

## Choices left open
Some things the reference deliberately doesn't settle, because they depend on the project. Each is decided in an ADR (`architect.md`), with the human choosing:
- the backend stack (`stacks.md`); onboarding records it as the first ADR;
- each client's UI technology (`clients.md`);
- a data store or messaging alternative from the lists in `data.md` and `messaging.md`;
- per integration, how the external system is reached (`integrations.md`).

## What the check enforces
`tools/archcheck.awk` runs these rules on every file in a layer (`tools/check.cfg` › `[layers]`), plus `secrets` and `cost-sku` on every file. Files outside every layer are counted, not checked: that's where an existing app's code waits until a roadmap item moves it into a layer.

| Rule | Fails when | Reference |
|---|---|---|
| `layers` | a layer imports or references a layer it may not depend on, or the domain or contracts take an external package | `layers.md` › Dependencies |
| `domain-purity` | domain code reads the clock, makes ids or random numbers, reads the environment, or does I/O | `layers.md` › Domain |
| `tenant-source` | a host reads the tenant from a header, query, route or form, or an API contract carries a tenant id | `tenancy.md` › Where the tenant comes from |
| `tenant-branching` | code compares a tenant with a literal | `tenancy.md` › No tenant-specific code |
| `secrets` | a file holds something that looks like a key, password, connection secret or private key | `identity.md` › No secrets |
| `file-size` | a source file is longer than `max_lines` | `rules.md` › The three tenets |
| `host-size` | a host or platform file is longer than `host_max_lines` | `layers.md` › Host |
| `message-version` | a type in a contracts `events/` or `commands/` folder isn't named `…V<n>` | `messaging.md` › Versioning |
| `cost-sku` | Bicep asks for a premium, isolated or dedicated SKU, or provisioned Cosmos DB throughput | `cost.md` › Defaults |

The check reads text: comments are skipped, strings aren't. It's a strong net, not a proof; `review.md` covers what text can't show, such as a store that forgets the tenant in a query.

An exception is one line in an accepted ADR, naming a rule and a path pattern (`*` within a folder, `**` across folders):
```
- Exception: domain-purity src/OrderDesk.Domain/Legacy/**
```
