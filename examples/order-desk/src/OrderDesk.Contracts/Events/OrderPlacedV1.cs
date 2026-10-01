namespace OrderDesk.Contracts.Events;

public sealed record OrderPlacedV1(string OrderId, string CustomerNumber, decimal Total, DateTimeOffset PlacedAt)
{
    public const string EventType = "orderdesk.orders.order.placed.v1";
}
