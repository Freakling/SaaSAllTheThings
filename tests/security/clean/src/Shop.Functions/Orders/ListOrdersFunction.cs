using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Shop.Application.Orders;

namespace Shop.Functions.Orders;

// The clean twin (tests/security/README.md): the tenant comes from the validated token, through
// the tenant context the host builds, and the customer filter is validated before the store sees it.
public sealed class ListOrdersFunction(IOrderStore store)
{
    [Function("ListOrders")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "v1/orders")] HttpRequest request,
        FunctionContext context)
    {
        string customer = request.Query["customer"]!;
        if (string.IsNullOrEmpty(customer) || customer.Length > 40 || !customer.All(char.IsLetterOrDigit))
            return new BadRequestObjectResult(new ProblemDetails { Title = "Invalid customer", Status = 400 });
        return new OkObjectResult(await store.ListAsync(context.GetTenant().TenantId, customer, request.HttpContext.RequestAborted));
    }
}
