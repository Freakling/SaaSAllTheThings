# {{PROJECT_NAME}}

{{ONE_PARAGRAPH_PITCH}}

Instructions for AI assistants working on this product. The workflow is SaaSAllTheThings: its rules are in `.satt/rules.md`, which names the procedure for each kind of request, and its reference architecture is in `.satt/reference/`. Read the rules before any work, unless your tool has already loaded them (Claude Code imports them: @.satt/rules.md).

## Project facts
- Backend: {{STACK}} on Azure Functions (ADR-1)
- Clients: {{CLIENTS}}
- Tenancy: pooled, silo-ready · Identity: Entra ID, multi-tenant
- Azure: {{REGION}} · environments: dev, prod
- Integrations: {{INTEGRATIONS}}

## Layout
<!-- The real folders of this project, and their layers. Setup fills this in; keep it current when
folders move, together with tools/check.cfg › [layers]. -->
| Folder | Layer | Holds |
|---|---|---|
| `src/{{APP}}.Contracts/` | contracts | API requests and responses, events, commands |
| `src/{{APP}}.Domain/` | domain | business rules |
| `src/{{APP}}.Application/` | application | use-case handlers, ports, the tenant context |
| `src/{{APP}}.Infrastructure/` | infrastructure | stores, the outbox publisher, Azure adapters |
| `src/{{APP}}.Functions/` | host | the product's Azure Functions |
| `src/{{APP}}.Platform/` | platform | the tenant registry and operator functions |
| `clients/windows/`, `clients/mobile/` | client | the client apps |
| `tests/` | tests | tests, fakes, recorded fixtures |
| `infra/` | (none) | Bicep: `main.bicep`, `modules/`, `env/` |

## Architecture
One row per system: a project, a function app or an area within one. Clients depend on contracts, hosts on handlers, never the other way round.

| System | Owns | Where | Talks to |
|---|---|---|---|
<!-- | `PlaceOrderHandler` | placing an order: validation, total, OrderPlacedV1 | `src/OrderDesk.Application/Orders/` | `IOrderStore`; called by `PlaceOrderFunction` | -->

## Project rules
<!-- Only where this project's workflow differs from the SaaSAllTheThings defaults, as agreed with the human.
Architecture never goes here: it changes through an ADR in adr/.
Examples:
- The agent may deploy to dev without asking each time; production stays with the human.
- No git remote: never push.
- Model sizing: on
-->
