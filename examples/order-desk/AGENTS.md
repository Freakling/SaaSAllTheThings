# Order Desk

A multi-tenant order desk for wholesalers: sales staff place customer orders on a Windows client, warehouse staff pick them on mobile, and every order syncs with the wholesaler's own Navision (Business Central).

Instructions for AI assistants working on this product. The workflow is SaaSAllTheThings: its rules are in `.satt/rules.md`, which names the procedure for each kind of request, and its reference architecture is in `.satt/reference/`. Read the rules before any work, unless your tool has already loaded them (Claude Code imports them: @.satt/rules.md).

## Project facts
- Backend: .NET 10 (C#) on Azure Functions, isolated worker (ADR-1)
- Clients: Windows (sales; UI tech in ADR-2, proposed) · mobile (warehouse; not decided)
- Tenancy: pooled, silo-ready · Identity: Entra ID, multi-tenant
- Azure: Norway East (Q4) · environments: dev, prod
- Integrations: Navision / Business Central (`integrations/navision/contract.md`)

## Layout
| Folder | Layer | Holds |
|---|---|---|
| `src/OrderDesk.Contracts/` | contracts | `Api/` requests and responses, `Events/`, `Messaging/` (the envelope) |
| `src/OrderDesk.Domain/` | domain | `Orders/`, `Tenancy/` |
| `src/OrderDesk.Application/` | application | `Orders/` handlers, `Ports/`, `Tenancy/` |
| `src/OrderDesk.Functions/` | host | the product's functions, by area |
| `tests/` | tests | one test project per layer, `Fakes/` |

## Architecture
| System | Owns | Where | Talks to |
|---|---|---|---|
| `Order` | the order rules: a customer, at least one line, the total | `src/OrderDesk.Domain/Orders/` | (none) |
| `PlaceOrderHandler` | placing an order: builds it, saves it with `OrderPlacedV1` | `src/OrderDesk.Application/Orders/` | `IOrderStore`, `IClock`, `IIdGenerator` |
| `PlaceOrderFunction` | `POST /api/v1/orders` | `src/OrderDesk.Functions/Orders/` | `PlaceOrderHandler`; the tenant from `FunctionContext` |
| `TenantContext` | who is calling: tenant, user, roles | `src/OrderDesk.Application/Tenancy/` | built by the token middleware (T4) |

## Project rules
- No git remote: never push.
