namespace OrderDesk.Domain.Orders;

public sealed class OrderRejectedException(string reason) : Exception(reason);
