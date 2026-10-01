namespace OrderDesk.Contracts.Messaging;

// A CloudEvents 1.0 envelope (.satt/reference/messaging.md › The envelope). Only our own code writes it.
public sealed record EventEnvelope(
    string Id,
    string Source,
    string Type,
    string Subject,
    DateTimeOffset Time,
    string TenantId,
    string CorrelationId,
    object Data);
