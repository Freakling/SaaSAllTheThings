# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.satt/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`. The stages are explained in `.satt/procedures/roadmap.md`.

**Next IDs:** T9 · B2

## Milestones
| Stage | Status |
|---|---|
| 0 · Extract (existing apps only) | ⬜ not needed |
| 1 · Foundation: layered skeleton, check passing, first rule with a test | ✅ |
| 2 · Tenancy and identity | 🟨 in progress |
| 3 · First slice, end to end | ⬜ |
| 4 · Delivery: Bicep, CI, dev environment, budget | ⬜ |
| 5 · Clients: Windows and mobile | ⬜ |
| 6 · Integrations | ⬜ |
| 7 · Second tenant | ⬜ |
| 8 · Capabilities | ⬜ |

✅ done · 🟨 in progress · ⬜ not started

## Queue

### T1 · The check passes on a clean clone · done · S · agent
- Depends on: none
- Touches: tools/check.cfg
- Done when: `bash tools/check.sh` exits 0 after a fresh clone and `bash tools/setup-clone.sh` (check)
- PRD: none

### T2 · Orders have a customer, lines and a total · done · S · agent
- Depends on: T1
- Touches: src/OrderDesk.Domain/Orders/Order.cs (new), src/OrderDesk.Domain/Orders/OrderLine.cs (new), tests/OrderDesk.Domain.Tests/Orders/OrderTests.cs (new)
- Done when: an order without lines or customer is rejected (test) · the total is the sum of the lines (test)
- PRD: Capabilities › Place an order

### T3 · Place an order through the API · done · M · agent
- Depends on: T2
- Touches: src/OrderDesk.Contracts/Api/ (new), src/OrderDesk.Contracts/Events/OrderPlacedV1.cs (new), src/OrderDesk.Application/Orders/PlaceOrderHandler.cs (new), src/OrderDesk.Functions/Orders/PlaceOrderFunction.cs (new), tests/OrderDesk.Application.Tests/ (new)
- Done when: the order is saved with OrderPlacedV1 in its envelope (test) · a rejected order saves nothing (test) · POST /api/v1/orders answers 201 locally (demo)
- PRD: Capabilities › Place an order

### B1 · The same customer in two spellings becomes two customers · todo · S · agent · med
- Repro: place an order for customer `c0001`, then one for `C0001` → expected: both orders for customer C0001 / actual: the first is stored as `c0001`
- Found in: validation/2026-09-30-acceptance.md
- PRD: Capabilities › Place an order

### T4 · Validate the bearer token and build the tenant context · todo · M · agent
- Depends on: T5
- Touches: src/OrderDesk.Functions/Tenancy/TokenMiddleware.cs (new), src/OrderDesk.Functions/Program.cs, src/OrderDesk.Application/Ports/ITenantDirectory.cs (new), tests/OrderDesk.Application.Tests/Tenancy/ (new)
- Done when: a request without a valid token answers 401 (test) · a token from a directory that isn't an active tenant answers 403 (test) · the tenant context carries the tenant, user and roles (test)
- PRD: Personas and Roles

### T5 · A tenant registry in the platform layer · todo · M · agent
- Depends on: T1
- Touches: src/OrderDesk.Platform/ (new), src/OrderDesk.Application/Ports/ITenantDirectory.cs (new), tests/OrderDesk.Platform.Tests/ (new), tools/check.cfg
- Done when: a directory id maps to its tenant, and an unknown or suspended one to none (test) · only the Operator role can add a tenant (test)
- PRD: Customers and Tenants

### T6 · Store orders in Cosmos DB with the outbox · todo · M · agent
- Depends on: T3
- Touches: src/OrderDesk.Infrastructure/ (new), tests/OrderDesk.Infrastructure.Tests/ (new), src/OrderDesk.Functions/Program.cs
- Done when: an order and its events are written in one transactional batch (test) · tenant B can't read tenant A's order (test)
- PRD: none

### T7 · Register the API and client apps in Entra ID · todo · none · human
- Depends on: none
- Touches: none
- Done when: a multi-tenant API registration with the access_as_user scope and the app roles, and a public client registration for the Windows app, exist in the dev directory (check)
- PRD: Personas and Roles

### T8 · Decide: the Windows client's UI technology (architect.md) · todo · none · human
- Depends on: none
- Touches: adr/ADR-2-windows-client-ui.md
- Done when: ADR-2 is accepted or rejected (check)
- PRD: Clients › Windows
- ADR: ADR-2

## Notes
- T4 and T6 both change `src/OrderDesk.Functions/Program.cs`; build them one after the other.
