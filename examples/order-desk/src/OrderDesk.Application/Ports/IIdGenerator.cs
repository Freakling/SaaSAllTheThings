namespace OrderDesk.Application.Ports;

public interface IIdGenerator
{
    Guid NewId();
}
