using OrderDesk.Application.Ports;
using OrderDesk.Application.Tenancy;
using OrderDesk.Contracts.Api;
using OrderDesk.Contracts.Events;
using OrderDesk.Contracts.Messaging;
using OrderDesk.Domain.Orders;

namespace OrderDesk.Application.Orders;

public sealed class PlaceOrderHandler(IOrderStore store, IClock clock, IIdGenerator ids)
{
    public const string Source = "/orderdesk/orders";

    public async Task<PlaceOrderResult> HandleAsync(TenantContext tenant, PlaceOrderRequest request, string correlationId, CancellationToken cancellationToken)
    {
        Order order;
        try
        {
            order = Order.Place(
                new OrderId(ids.NewId()),
                tenant.TenantId,
                request.CustomerNumber,
                clock.UtcNow,
                (request.Lines ?? []).Select(line => new OrderLine(line.ItemNumber, line.Quantity, line.UnitPrice)));
        }
        catch (OrderRejectedException rejected)
        {
            return PlaceOrderResult.Rejected(rejected.Message);
        }

        var placed = new OrderPlacedV1(order.Id.ToString(), order.CustomerNumber, order.Total, order.PlacedAt);
        var envelope = new EventEnvelope(
            ids.NewId().ToString(), Source, OrderPlacedV1.EventType, placed.OrderId,
            order.PlacedAt, tenant.TenantId.ToString(), correlationId, placed);
        await store.AddAsync(tenant, order, [envelope], cancellationToken);

        return PlaceOrderResult.Placed(new OrderResponse(placed.OrderId, order.CustomerNumber, order.Total, order.PlacedAt));
    }
}
