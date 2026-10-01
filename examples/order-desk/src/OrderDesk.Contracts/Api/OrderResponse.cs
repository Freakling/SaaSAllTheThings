namespace OrderDesk.Contracts.Api;

public sealed record OrderResponse(string Id, string CustomerNumber, decimal Total, DateTimeOffset PlacedAt);
