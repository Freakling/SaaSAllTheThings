namespace OrderDesk.Contracts.Api;

public sealed record OrderLineRequest(string ItemNumber, int Quantity, decimal UnitPrice);
