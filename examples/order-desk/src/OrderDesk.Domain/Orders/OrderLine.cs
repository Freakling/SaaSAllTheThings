namespace OrderDesk.Domain.Orders;

public sealed class OrderLine
{
    public OrderLine(string itemNumber, int quantity, decimal unitPrice)
    {
        if (string.IsNullOrWhiteSpace(itemNumber)) throw new OrderRejectedException("A line needs an item.");
        if (quantity <= 0) throw new OrderRejectedException("A line needs a quantity above zero.");
        if (unitPrice < 0) throw new OrderRejectedException("A line can't have a negative price.");

        ItemNumber = itemNumber.Trim();
        Quantity = quantity;
        UnitPrice = unitPrice;
    }

    public string ItemNumber { get; }
    public int Quantity { get; }
    public decimal UnitPrice { get; }
    public decimal Amount => Quantity * UnitPrice;
}
