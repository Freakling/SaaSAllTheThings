<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Data

## Default store
**Azure Cosmos DB for NoSQL, serverless**: pay per request, nothing when idle, JSON documents that map directly to aggregates.
- One database per stamp; one container per area (orders, customers), plus the lease container for the change feed.
- **Hierarchical partition key** `/tenantId`, `/partitionId`. `partitionId` is the aggregate's id (or a grouping that's always queried together). Queries for one tenant stay within its partitions; the entity and its outbox records share a full key, so they save in one transactional batch (`messaging.md` › Outbox).
- Every document has `id`, `tenantId`, `partitionId`, `type` and `schemaVersion`. Updates use the document's ETag for optimistic concurrency; a conflict is retried by the handler or returned as 409.
- Data-plane access by managed identity only (`identity.md` › Services).

Serverless serves one region. When a tenant's load or availability needs more, moving to provisioned autoscale throughput is an ADR (`cost.md`).

## Alternatives
Each needs an ADR that says why the default doesn't fit:
- **Azure SQL Database, serverless** (auto-pause): relational data, heavy reporting joins, or an existing EF Core model kept from the app being moved to SaaS. Every table gets a `TenantId` column leading every index, and row-level security filters on the session's tenant.
- **Table Storage:** large, simple, key-value data at the lowest cost.

## Files
Blob Storage, under `<tenantId>/<area>/…`. Clients upload and download through short-lived user-delegation SAS URLs that the API issues per request, never with account keys.

## Stored schemas
- A document's shape is versioned by `schemaVersion`. Readers accept the current and the previous version; a migration item rewrites old documents and then removes the old reader.
- A change to a stored schema is reviewed (`rules.md` › Reviews and model size).

## Retention and personal data
- PRD › Data and Compliance decides retention, residency and which fields are personal. Until it does, they're Open Questions, not guesses.
- Personal data stays out of logs and partition keys. Deleting a tenant's or a person's data is a `platform` capability.
- Backups: Cosmos DB continuous backup (7 days) by default.
