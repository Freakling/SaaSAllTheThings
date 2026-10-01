using OrderDesk.Application.Tenancy;
using OrderDesk.Contracts.Messaging;
using OrderDesk.Domain.Orders;

namespace OrderDesk.Application.Ports;

public interface IOrderStore
{
    // Saves the order and its events in one transaction: the outbox (.satt/reference/messaging.md › Outbox).
    Task AddAsync(TenantContext tenant, Order order, IReadOnlyList<EventEnvelope> events, CancellationToken cancellationToken);
}
