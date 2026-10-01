using OrderDesk.Application.Ports;
using OrderDesk.Application.Tenancy;
using OrderDesk.Contracts.Messaging;
using OrderDesk.Domain.Orders;

namespace OrderDesk.Application.Tests.Fakes;

public sealed class RecordingOrderStore : IOrderStore
{
    public List<(TenantContext Tenant, Order Order, IReadOnlyList<EventEnvelope> Events)> Saved { get; } = [];

    public Task AddAsync(TenantContext tenant, Order order, IReadOnlyList<EventEnvelope> events, CancellationToken cancellationToken)
    {
        Saved.Add((tenant, order, events));
        return Task.CompletedTask;
    }
}
