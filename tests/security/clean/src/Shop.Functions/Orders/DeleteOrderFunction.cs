using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Shop.Application.Orders;

namespace Shop.Functions.Orders;

// The clean twin (tests/security/README.md): only an admin of the tenant may delete an order.
public sealed class DeleteOrderFunction(IOrderStore store)
{
    [Function("DeleteOrder")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "delete", Route = "v1/orders/{orderId}")] HttpRequest request,
        string orderId,
        FunctionContext context)
    {
        var caller = context.GetTenant();
        if (!caller.Roles.Contains("Tenant.Admin")) return new ForbidResult();
        await store.DeleteAsync(caller.TenantId, orderId, request.HttpContext.RequestAborted);
        return new NoContentResult();
    }
}
