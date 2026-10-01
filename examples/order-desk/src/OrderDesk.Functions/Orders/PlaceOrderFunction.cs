using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using OrderDesk.Application.Orders;
using OrderDesk.Contracts.Api;
using OrderDesk.Functions.Tenancy;

namespace OrderDesk.Functions.Orders;

public sealed class PlaceOrderFunction(PlaceOrderHandler handler)
{
    [Function("PlaceOrder")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "v1/orders")] HttpRequest request,
        [Microsoft.Azure.Functions.Worker.Http.FromBody] PlaceOrderRequest body,
        FunctionContext context)
    {
        var result = await handler.HandleAsync(context.GetTenant(), body, context.InvocationId, request.HttpContext.RequestAborted);

        if (result.Order is null)
        {
            return new BadRequestObjectResult(new ProblemDetails { Title = "Order rejected", Detail = result.Rejection, Status = 400 });
        }

        return new CreatedResult($"/api/v1/orders/{result.Order.Id}", result.Order);
    }
}
