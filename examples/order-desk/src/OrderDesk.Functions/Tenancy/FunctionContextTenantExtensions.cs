using Microsoft.Azure.Functions.Worker;
using OrderDesk.Application.Tenancy;

namespace OrderDesk.Functions.Tenancy;

public static class FunctionContextTenantExtensions
{
    public const string ItemKey = "orderdesk.tenant";

    // The token middleware (T4) puts the tenant context here after validating the bearer token.
    public static TenantContext GetTenant(this FunctionContext context) =>
        context.Items.TryGetValue(ItemKey, out var value) && value is TenantContext tenant
            ? tenant
            : throw new InvalidOperationException("No tenant context: the token middleware didn't run.");
}
