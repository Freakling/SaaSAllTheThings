namespace Shop.Application.Orders;

public interface IOrderStore
{
    Task<IReadOnlyList<string>> ListAsync(string tenantId, string customer, CancellationToken cancel);
    Task DeleteAsync(string tenantId, string orderId, CancellationToken cancel);
}
