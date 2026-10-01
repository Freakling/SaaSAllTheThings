using OrderDesk.Domain.Tenancy;

namespace OrderDesk.Domain.Orders;

public sealed class Order
{
    private readonly List<OrderLine> _lines;

    private Order(OrderId id, TenantId tenantId, string customerNumber, DateTimeOffset placedAt, List<OrderLine> lines)
    {
        Id = id;
        TenantId = tenantId;
        CustomerNumber = customerNumber;
        PlacedAt = placedAt;
        _lines = lines;
    }

    public OrderId Id { get; }
    public TenantId TenantId { get; }
    public string CustomerNumber { get; }
    public DateTimeOffset PlacedAt { get; }
    public IReadOnlyList<OrderLine> Lines => _lines;
    public decimal Total => _lines.Sum(line => line.Amount);

    // The time and the id come in as inputs: the domain never reads the clock or makes ids.
    public static Order Place(OrderId id, TenantId tenantId, string customerNumber, DateTimeOffset placedAt, IEnumerable<OrderLine> lines)
    {
        if (string.IsNullOrWhiteSpace(customerNumber)) throw new OrderRejectedException("An order needs a customer.");

        var list = lines.ToList();
        if (list.Count == 0) throw new OrderRejectedException("An order needs at least one line.");

        return new Order(id, tenantId, customerNumber.Trim(), placedAt, list);
    }
}
