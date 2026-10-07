<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Integrations

An enterprise integration connects one external system, such as a customer's ERP, to the product. Each one is planned with `procedures/integrate.md`, and its decisions live in `integrations/<system>/contract.md`.

## Shape
- **One anti-corruption layer per system**, in the `integration` layer (`src/<App>.Integrations.<System>/`): the external system's client and model, and the mapping between that model and our contracts. The external model never leaks past it.
- **Its own function app** (`src/<App>.Integrations.<System>.Functions/`, a `host`), so a slow or failing system can't take the product down, and its credentials stay separate.
- **Per tenant.** Each tenant connects its own instance (its own Business Central environment and company, or its own Navision server). The connection is registry data: endpoint, company, credential reference (`tenancy.md`).

## Flow
- **Inbound** (external → us): a webhook or a timer detects changes, the adapter fetches and maps them, and publishes an integration event (`CustomerChangedInNavisionV1`). An application handler decides what it means for our data.
- **Outbound** (us → external): a handler sends a command (`SyncOrderToNavisionV1`) to the integration's queue. The adapter maps it and calls the external system with an idempotency key, then publishes the outcome as an event.
- **Bidirectional** is both, plus the contract's rules for who owns what.

## The rules every integration follows
- **A system of record per entity, and per field where they split.** Decided by the human in the contract. A change from the system that doesn't own a field is ignored or raised as a conflict, as the contract says.
- **A mapping table** per tenant: external key ↔ our id, with the last synced version or timestamp on each side. It's how a change knows whether it's new, an echo of our own write, or a conflict.
- **Echo suppression.** A change that comes back because we wrote it is recognised by the mapping table and dropped.
- **Ordering** per record with Service Bus sessions (`messaging.md` › Ordering).
- **Idempotent** in both directions: the same message twice changes nothing.
- **Throttling:** respect the system's limits (HTTP 429 and `Retry-After`), with backoff and a concurrency cap per tenant.
- **Failures** go to the dead-letter queue and raise an alert; a reconciliation job finds and repairs drift on a schedule the contract sets.
- **No network in tests.** Contract tests run the adapter against recorded responses in `tests/`. Talking to a real sandbox is a `(demo)` outcome, or a command the agent runs only with the human's approval.

## Navision and Business Central
"Navision" covers Microsoft Dynamics NAV and its successor, Dynamics 365 Business Central. The contract records which one each tenant runs:
| The tenant runs | API | Detecting changes | Reaching it | Credentials |
|---|---|---|---|---|
| Business Central online | the standard API (v2.0), or custom API pages for what it lacks | webhooks (subscriptions expire and are renewed on a timer), with `lastModifiedDateTime` polling as the safety net | public endpoint | multi-tenant integration app with a federated credential; the customer consents, and grants permission sets in Business Central |
| Business Central on-premises, or NAV 2017-2018 | OData v4 web services (pages, queries), SOAP codeunits for actions | polling on a timestamp or `SystemModifiedAt` | an outbound-only connector in the customer's network (recommended), or a site-to-site VPN with Functions VNet integration (ADR: cost) | Key Vault credential (ADR, `identity.md` › External systems) |
| NAV 2013-2016 | OData v3 / SOAP web services | polling | as above | as above |

Prefer the online API when a tenant can use it. A customer still on NAV gets the connector route, and the PRD may add an upgrade path as a product decision.
