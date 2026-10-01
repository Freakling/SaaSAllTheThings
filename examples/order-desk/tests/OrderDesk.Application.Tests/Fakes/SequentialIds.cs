using OrderDesk.Application.Ports;

namespace OrderDesk.Application.Tests.Fakes;

public sealed class SequentialIds : IIdGenerator
{
    private int _next;

    public Guid NewId() => new($"00000000-0000-0000-0000-{++_next:D12}");
}
