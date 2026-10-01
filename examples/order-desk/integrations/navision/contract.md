# Navision integration contract

**Purpose:** customers and items come from Navision; orders go to Navision as sales orders (PRD › Integrations › Navision).
**Reference:** `.satt/reference/integrations.md`

## The system
| | |
|---|---|
| Product and version | Business Central online (the pilot tenant). Other tenants: per tenant, in the registry |
| API | the standard API v2.0: `customers`, `items`, `salesOrders`, `salesOrderLines` |
| Reaching it | public endpoint |
| Credentials | multi-tenant integration app with a federated credential on the integration function's managed identity |
| Limits | Business Central throttles per environment (HTTP 429): back off on `Retry-After` |
| Sandbox for testing | the pilot's BC sandbox environment (T-item to request it, not yet written) |

## Entities
| Entity | Direction | Owner | Our contract | Their resource | Detect changes | Key mapping |
|---|---|---|---|---|---|---|
| Customer | in | Navision | `CustomerChangedInNavisionV1` | `customers` | webhook, and polling `lastModifiedDateTime` nightly | their `number` ↔ our customer number |
| Item | in | Navision | `ItemChangedInNavisionV1` | `items` | webhook, and nightly polling | their `number` ↔ our item number |
| Sales order | out, status in | split: see below | `SyncOrderToNavisionV1` | `salesOrders` | polling the status of open orders (Q7) | their `id` and `number` ↔ our order id |

### Field ownership
| Entity | Field | Owner |
|---|---|---|
| Sales order | customer, lines, quantities | Order Desk, until Navision posts the order |
| Sales order | status, posting, invoice number | Navision |

## Conflicts
- **Rule:** the owner wins. An order changed in Navision before posting: Q6.
- **Who resolves held conflicts, and where:** Q6.

## Failures and reconciliation
- **Retries:** exponential backoff, at most 10 deliveries, then the dead-letter queue and an alert to the tenant's admin and the operator.
- **Reconciliation:** nightly, for customers and items; for orders: Q7.

## Per tenant
- **Connection data in the registry:** BC tenant (directory) id, environment name, company id.
- **Onboarding steps (human):** the customer's admin consents to the integration app, adds it on Business Central's "Microsoft Entra Applications" page, and grants it permission sets for customers, items and sales orders.

## Open questions
Q6 (conflicts on unposted orders) and Q7 (reading back order status), in PRD › Open Questions.
