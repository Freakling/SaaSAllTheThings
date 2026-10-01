<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Messaging

The backend is event-driven: a request changes state and records what happened; everything that follows runs from messages.

## Commands and events
- A **command** asks one owner to do something (`SyncCustomerToNavisionV1`). It goes to a Service Bus **queue**, which has one consumer.
- An **event** says something happened (`OrderPlacedV1`). It goes to a Service Bus **topic**, and any number of subscriptions consume it.
- Names: commands are imperative, events are past tense, both end in `V<n>`. The CloudEvents type is `<app>.<area>.<entity>.<verb>.v<n>`, for example `orderdesk.orders.order.placed.v1`.
- One type per file, in the contracts layer's `Commands/` and `Events/` folders. Everything in those folders is versioned; shared envelope types go in `Messaging/`.

## The envelope
Every message is a CloudEvents 1.0 envelope: `id`, `source`, `type`, `time`, `subject` (the entity id), `datacontenttype`, plus the extensions `tenantid`, `correlationid` and `causationid`. Only our own code writes the envelope. Its `tenantid` is how a consumer knows the tenant (`tenancy.md`).

## Outbox
State and the events it produces are saved together, so neither exists without the other:
1. The handler saves the entity and its event envelopes in one transaction through a store port. In Cosmos DB that's a transactional batch in the entity's partition (`data.md`).
2. A change-feed function (`infrastructure` + `host`) publishes new outbox records to Service Bus, then marks them sent.
3. Publishing is at least once. Nobody publishes straight from a handler.

## Consumers
- **Idempotent.** A consumer records each message id it has processed (per tenant, with a time to live) and skips repeats. Effects that leave the system carry an idempotency key.
- **Thin.** A message function reads the envelope, builds the tenant context, calls one handler.
- **Failures.** Transient errors are retried with backoff. After the queue's maximum delivery count the message goes to the dead-letter queue, which raises an alert (`observability.md`). Nothing is swallowed.

## Ordering
Messages whose order matters (an integration syncing one record) use Service Bus sessions with the session id `<tenantId>:<entityId>`. Everything else is unordered, and consumers are written to cope.

## Versioning
- Within a version, changes are additive only: new optional fields. Never rename, remove or change the meaning of a field.
- A breaking change is a new type (`OrderPlacedV2`) in its own file. The producer publishes both until every consumer has moved, then a later item removes the old one.
- Events carry what their consumers need, but no secrets, and personal data only where a consumer needs it.

## Defaults and alternatives
One **Service Bus Standard** namespace per environment (topics, sessions, duplicate detection and dead-lettering need Standard). Alternatives, each needing an ADR: Event Grid for high-fan-out notifications, Storage queues for very high volume with no ordering, Service Bus Premium for isolation or large messages.
