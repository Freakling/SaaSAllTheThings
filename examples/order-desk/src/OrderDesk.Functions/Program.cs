using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OrderDesk.Application.Orders;

var builder = FunctionsApplication.CreateBuilder(args);
builder.ConfigureFunctionsWebApplication();

builder.Services.AddScoped<PlaceOrderHandler>();
// The token middleware that builds the tenant context comes with T4; the Cosmos DB store with T6.

builder.Build().Run();
