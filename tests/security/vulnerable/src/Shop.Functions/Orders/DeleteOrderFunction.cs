using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Shop.Application.Orders;

namespace Shop.Functions.Orders;

// SEEDED (tests/security/README.md): any signed-in user of the tenant can delete any order; no
// role is checked (A01, API5).
public sealed class DeleteOrderFunction(IOrderStore store)
{
    [Function("DeleteOrder")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "delete", Route = "v1/orders/{orderId}")] HttpRequest request,
        string orderId,
        FunctionContext context)
    {
        await store.DeleteAsync(context.GetTenant().TenantId, orderId, request.HttpContext.RequestAborted);
        return new NoContentResult();
    }
}
