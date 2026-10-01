using OrderDesk.Domain.Tenancy;

namespace OrderDesk.Application.Tenancy;

// Built by the host from the validated token (.satt/reference/tenancy.md › Where the tenant comes from).
public sealed record TenantContext(TenantId TenantId, string UserId, IReadOnlySet<string> Roles);
