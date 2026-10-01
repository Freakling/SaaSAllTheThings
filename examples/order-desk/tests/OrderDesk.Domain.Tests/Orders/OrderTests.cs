using OrderDesk.Domain.Orders;
using OrderDesk.Domain.Tenancy;

namespace OrderDesk.Domain.Tests.Orders;

public sealed class OrderTests
{
    private static readonly TenantId Tenant = new(Guid.Parse("11111111-1111-1111-1111-111111111111"));
    private static readonly DateTimeOffset PlacedAt = new(2026, 10, 1, 9, 0, 0, TimeSpan.Zero);

    private static Order Place(params OrderLine[] lines) =>
        Order.Place(new OrderId(Guid.Empty), Tenant, "C0001", PlacedAt, lines);

    [Fact]
    public void The_total_is_the_sum_of_the_lines() =>
        Assert.Equal(25.5m, Place(new OrderLine("ITEM-1", 2, 10m), new OrderLine("ITEM-2", 1, 5.5m)).Total);

    [Fact]
    public void An_order_keeps_its_tenant_and_time()
    {
        var order = Place(new OrderLine("ITEM-1", 1, 1m));
        Assert.Equal(Tenant, order.TenantId);
        Assert.Equal(PlacedAt, order.PlacedAt);
    }

    [Fact]
    public void An_order_without_lines_is_rejected() =>
        Assert.Throws<OrderRejectedException>(() => Place());

    [Fact]
    public void An_order_without_a_customer_is_rejected() =>
        Assert.Throws<OrderRejectedException>(() =>
            Order.Place(new OrderId(Guid.Empty), Tenant, " ", PlacedAt, [new OrderLine("ITEM-1", 1, 1m)]));

    [Theory]
    [InlineData("", 1, 1)]
    [InlineData("ITEM-1", 0, 1)]
    [InlineData("ITEM-1", 1, -1)]
    public void An_invalid_line_is_rejected(string item, int quantity, int unitPrice) =>
        Assert.Throws<OrderRejectedException>(() => new OrderLine(item, quantity, unitPrice));
}
