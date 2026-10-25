using Microsoft.Azure.Cosmos;
using Shop.Application.Orders;

namespace Shop.Infrastructure.Orders;

// The clean twin (tests/security/README.md): the query is parameterized and scoped by the tenant.
public sealed class OrderStore(Container orders) : IOrderStore
{
    public async Task<IReadOnlyList<string>> ListAsync(string tenantId, string customer, CancellationToken cancel)
    {
        var query = new QueryDefinition("SELECT VALUE c.id FROM c WHERE c.tenantId = @tenant AND c.customer = @customer")
            .WithParameter("@tenant", tenantId)
            .WithParameter("@customer", customer);
        var found = new List<string>();
        using var feed = orders.GetItemQueryIterator<string>(query, requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(tenantId) });
        while (feed.HasMoreResults) found.AddRange(await feed.ReadNextAsync(cancel));
        return found;
    }

    public Task DeleteAsync(string tenantId, string orderId, CancellationToken cancel) =>
        orders.DeleteItemAsync<object>(orderId, new PartitionKey(tenantId), cancellationToken: cancel);
}
