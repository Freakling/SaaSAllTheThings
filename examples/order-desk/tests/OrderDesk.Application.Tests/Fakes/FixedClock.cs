using OrderDesk.Application.Ports;

namespace OrderDesk.Application.Tests.Fakes;

public sealed class FixedClock(DateTimeOffset now) : IClock
{
    public DateTimeOffset UtcNow { get; } = now;
}
