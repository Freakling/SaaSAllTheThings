<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# API

The clients talk to the backend over HTTPS through HTTP-triggered functions in the `host` layer.

- **Routes** are versioned and plural: `/api/v1/orders`, `/api/v1/orders/{orderId}`. No route contains a tenant (`tenancy.md`). A breaking change is a new version (`v2`), served next to the old one until clients have moved.
- **Contracts.** Request and response types live in the contracts layer's `Api/` folder, one per file. An OpenAPI document generated from them is what clients build against.
- **Commands are POST** with an `Idempotency-Key` header. The handler stores the key with its result per tenant, and repeats the stored result for a repeated key.
- **Errors** are RFC 9457 problem details: 400 for invalid input, 401 without a valid token, 403 when the tenant or role doesn't allow it, 404 for what this tenant can't see (another tenant's data is always 404, never 403), 409 for a concurrency conflict, 429 when a plan limit is reached.
- **Lists** page with a continuation token and a bounded page size, never offsets.
- **Long work** answers 202 with a status resource; the work runs from a message.
- **Authorization level** is `Anonymous` at the Functions level, because the host validates the bearer token itself (`identity.md` › Validating a token). Function keys are never the protection.
- **No API Management by default.** Adding it (for external API customers, rate plans or a developer portal) is an ADR.
