<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. Copy it to integrations/<system>/contract.md
and delete this comment. Each answer here is a human decision (procedures/integrate.md); anything
undecided is a Q<n> in PRD › Open Questions, named in the row. -->
# <System> integration contract

**Purpose:** <one line from PRD › Integrations › <System>>
**Reference:** `.satt/reference/integrations.md`

## The system
| | |
|---|---|
| Product and version | <Business Central online / Business Central on-premises <version> / NAV <year>> |
| API | <standard API v2.0 / custom API pages / OData web services / SOAP codeunits> |
| Reaching it | <public endpoint / outbound-only connector / VPN (ADR-<n>)> |
| Credentials | <federated credential on the integration app / Key Vault credential (ADR-<n>)> |
| Limits | <requests per minute, page size, known throttling> |
| Sandbox for testing | <environment name, who provides it> |

## Entities
One row per entity in scope. "Owner" is the system of record; split by field when ownership splits.

| Entity | Direction | Owner | Our contract | Their resource | Detect changes | Key mapping |
|---|---|---|---|---|---|---|
| <Customer> | <in / out / both> | <Navision / us / split: see below> | <CustomerV1> | <customers> | <webhook / poll every n min> | <their number ↔ our id> |

### Field ownership
(Only for entities whose ownership splits.)
| Entity | Field | Owner |
|---|---|---|

## Conflicts
- **Rule:** <the owner wins / last writer wins by timestamp / held for a person to resolve>
- **Who resolves held conflicts, and where:** <role, screen or report>

## Failures and reconciliation
- **Retries:** <backoff, maximum attempts>, then the dead-letter queue and an alert to <owner>.
- **Reconciliation:** <how often, which entities, what it repairs>

## Per tenant
- **Connection data in the registry:** <endpoint, environment, company id, credential reference>
- **Onboarding steps (human):** <consent, permission sets, connector install>

## Open questions
(The `Q<n>`s in PRD › Open Questions that concern this integration; the questions themselves live there.)
