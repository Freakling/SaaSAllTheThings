namespace OrderDesk.Application.Ports;

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}
