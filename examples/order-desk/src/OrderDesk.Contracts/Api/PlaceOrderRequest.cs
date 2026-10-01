namespace OrderDesk.Contracts.Api;

public sealed record PlaceOrderRequest(string CustomerNumber, IReadOnlyList<OrderLineRequest> Lines);
