<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Tenancy

A tenant is one customer organisation. SaaSAllTheThings is **pooled and silo-ready**: one deployment serves every tenant, and any tenant can later move to its own deployment (a stamp) without code changes.

## The tenant registry
- The registry is the platform's record of every tenant: its internal `TenantId`, display name, status (`onboarding`, `active`, `suspended`, `offboarded`), plan, the identity providers it signs in with (for Entra ID, its directory id), its stamp, its feature flags, and its integration connections (references only; never secrets).
- It lives in the `platform` layer and its functions. Only operators (an app role, `identity.md`) change it.
- The internal `TenantId` is ours, not the identity provider's: a tenant can add a second provider, or move stamps, and keep its id.

## Where the tenant comes from
- **HTTP:** from the validated token only. The host maps the token's issuer and directory claim (`tid`) through the registry to a `TenantId`. A token whose directory isn't an active tenant is refused with 403.
- **Messages:** from the envelope's `tenantid`, which only our own code writes (`messaging.md`).
- **Timers and integrations:** a timer works through the registry's active tenants one at a time; an integration takes the tenant from the connection that received the data.
- Never from a header, a query string, a route, a form or a request body. API request contracts don't have a tenant field. Operator APIs in `platform` that address a tenant by id are the one exception, and they require the operator role.

## Isolation
- Every stored record and every message carries its `TenantId`, and the partition key of every store starts with it (`data.md`).
- Every port method takes the tenant context. A store builds every query from it; there's no method that reads "all tenants" outside `platform`.
- Every store has a tenant-isolation test: data written for tenant A can't be read, changed or listed as tenant B.
- Logs, traces and metrics carry the `TenantId` (`observability.md`). They never carry another tenant's data.
- Blobs live under a `<tenantId>/` prefix, and access to them goes through the same ports.

## No tenant-specific code
Tenants differ only by registry data: plan, feature flags, settings, connections. No code compares a tenant with a literal (`if (tenantId == "contoso")`), and there are no per-tenant branches, builds or config files. A customer-specific need becomes a feature flag or a plan capability, decided in the PRD.

## Plans and limits
Plans (tiers) are product decisions in PRD › Customers and Tenants. Their limits are data in the registry, enforced in the application layer (a handler refuses work beyond the plan). Undecided limits are `PLACEHOLDER` values.

## Silo-ready
- The registry holds each tenant's stamp: the set of endpoints its data and messages use. In pooled mode every tenant has the same stamp.
- Adapters resolve endpoints through the tenant's stamp, never from a single global setting.
- No cross-tenant joins, caches or singletons holding tenant data.
- A stamp is the same Bicep with different parameters (`infra.md`), so a silo is a deploy plus a data move, not a fork.
- Moving a tenant to its own stamp, and tenant export and deletion, are `platform` capabilities the roadmap adds before the second tenant (`procedures/roadmap.md` › Stages).
