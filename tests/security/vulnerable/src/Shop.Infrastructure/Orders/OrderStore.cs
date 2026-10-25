using Microsoft.Azure.Cosmos;
using Shop.Application.Orders;

namespace Shop.Infrastructure.Orders;

// SEEDED (tests/security/README.md): the customer filter is joined into the query text (A03).
public sealed class OrderStore(Container orders) : IOrderStore
{
    public async Task<IReadOnlyList<string>> ListAsync(string tenantId, string customer, CancellationToken cancel)
    {
        var text = "SELECT VALUE c.id FROM c WHERE c.tenantId = '" + tenantId + "' AND c.customer = '" + customer + "'";
        var found = new List<string>();
        using var feed = orders.GetItemQueryIterator<string>(new QueryDefinition(text));
        while (feed.HasMoreResults) found.AddRange(await feed.ReadNextAsync(cancel));
        return found;
    }

    public Task DeleteAsync(string tenantId, string orderId, CancellationToken cancel) =>
        orders.DeleteItemAsync<object>(orderId, new PartitionKey(tenantId), cancellationToken: cancel);
}
