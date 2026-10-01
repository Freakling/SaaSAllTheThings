using OrderDesk.Contracts.Api;

namespace OrderDesk.Application.Orders;

public sealed record PlaceOrderResult(OrderResponse? Order, string? Rejection)
{
    public static PlaceOrderResult Placed(OrderResponse order) => new(order, null);
    public static PlaceOrderResult Rejected(string reason) => new(null, reason);
}
