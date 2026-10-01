using OrderDesk.Application.Orders;
using OrderDesk.Application.Tenancy;
using OrderDesk.Application.Tests.Fakes;
using OrderDesk.Contracts.Api;
using OrderDesk.Contracts.Events;
using OrderDesk.Domain.Tenancy;

namespace OrderDesk.Application.Tests.Orders;

public sealed class PlaceOrderHandlerTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 1, 9, 0, 0, TimeSpan.Zero);
    private static readonly TenantContext Tenant =
        new(new TenantId(Guid.Parse("22222222-2222-2222-2222-222222222222")), "user-1", new HashSet<string> { "Tenant.User" });

    private readonly RecordingOrderStore _store = new();

    private PlaceOrderHandler Handler() => new(_store, new FixedClock(Now), new SequentialIds());

    [Fact]
    public async Task A_placed_order_is_saved_with_its_event_in_the_outbox()
    {
        var result = await Handler().HandleAsync(Tenant, new PlaceOrderRequest("C0001", [new OrderLineRequest("ITEM-1", 3, 2m)]), "corr-1", CancellationToken.None);

        Assert.NotNull(result.Order);
        Assert.Equal(6m, result.Order.Total);
        var saved = Assert.Single(_store.Saved);
        var envelope = Assert.Single(saved.Events);
        Assert.Equal(OrderPlacedV1.EventType, envelope.Type);
        Assert.Equal(Tenant.TenantId.ToString(), envelope.TenantId);
        Assert.Equal("corr-1", envelope.CorrelationId);
        Assert.Equal(Now, envelope.Time);
    }

    [Fact]
    public async Task The_order_belongs_to_the_tenant_of_the_context()
    {
        await Handler().HandleAsync(Tenant, new PlaceOrderRequest("C0001", [new OrderLineRequest("ITEM-1", 1, 1m)]), "corr-1", CancellationToken.None);

        var saved = Assert.Single(_store.Saved);
        Assert.Equal(Tenant.TenantId, saved.Order.TenantId);
        Assert.Same(Tenant, saved.Tenant);
    }

    [Fact]
    public async Task A_rejected_order_saves_nothing()
    {
        var result = await Handler().HandleAsync(Tenant, new PlaceOrderRequest("C0001", []), "corr-1", CancellationToken.None);

        Assert.Null(result.Order);
        Assert.NotNull(result.Rejection);
        Assert.Empty(_store.Saved);
    }
}
