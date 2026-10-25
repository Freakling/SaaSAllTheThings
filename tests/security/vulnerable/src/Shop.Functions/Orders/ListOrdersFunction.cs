using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Shop.Application.Orders;

namespace Shop.Functions.Orders;

// SEEDED (tests/security/README.md): the tenant is read from a request header instead of the
// validated token (A01, API1), and the customer filter goes to the store unvalidated (A05).
public sealed class ListOrdersFunction(IOrderStore store)
{
    [Function("ListOrders")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "v1/orders")] HttpRequest request)
    {
        string tenantId = request.Headers["x-tenant-id"]!;
        string customer = request.Query["customer"]!;
        return new OkObjectResult(await store.ListAsync(tenantId, customer, request.HttpContext.RequestAborted));
    }
}
