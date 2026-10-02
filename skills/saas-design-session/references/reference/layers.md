<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Layers

Every source file belongs to one layer. `tools/check.cfg` › `[layers]` says which folders hold which layer, and AGENTS.md › Layout says the same for people.

## The layers
| Layer | Owns | Never holds |
|---|---|---|
| `contracts` | what crosses a process boundary: API requests and responses, events, commands, the message envelope | logic, defaults that mean something, tenant ids in API requests |
| `domain` | business rules: entities, value objects, policies, domain errors | I/O, time, ids, randomness, configuration, framework types |
| `application` | use cases (one handler per use case), authorization per use case, ports (interfaces) for stores, publishers, clocks, id generators and external systems, the tenant context | HTTP, message-broker or SDK types; storage details |
| `infrastructure` | adapters that implement ports: Cosmos DB stores, the outbox publisher, Service Bus senders, Key Vault, the clock | business rules |
| `integration` | one anti-corruption layer per external system: its client, its model, mapping to and from contracts | business rules of our product; the external model leaking out |
| `host` | Azure Functions for the product: HTTP, Service Bus, timer and change-feed triggers; composition (dependency injection) | business rules, data access, tenant parsing |
| `platform` | Azure Functions for operating the SaaS: the tenant registry, tenant onboarding, operator-only APIs | product features |
| `client` | the Windows and mobile apps (`clients.md`) | business rules, references to anything but contracts |
| `tests` | tests of every layer, fakes, fixtures | production code |

## Dependencies
What each layer may depend on (import, reference or call). Everything else fails the check's `layers` rule. This matrix is the framework's; a project can't widen it except through an ADR.

| Layer | May depend on |
|---|---|
| `contracts` | — |
| `domain` | — |
| `application` | `domain`, `contracts` |
| `infrastructure` | `application`, `domain`, `contracts` |
| `integration` | `application`, `contracts` |
| `host` | `application`, `infrastructure`, `integration`, `contracts` |
| `platform` | `application`, `infrastructure`, `contracts` |
| `client` | `contracts` |
| `tests` | anything |

`domain` and `contracts` take no external packages either: only the language's standard library.

## Domain
- Rules live in plain types that receive everything they need: the current time, new ids and random choices come in as arguments or through ports, never from `DateTime.UtcNow`, `Guid.NewGuid()`, `Date.now()` or `uuid4()`. Tests then build them directly and get the same answer every time.
- No I/O: no files, network, console or environment variables.
- Errors are domain types; the application translates them into results the host can map.

## Application
- One handler per use case, in its own file, named for the use case (`PlaceOrderHandler`). It loads, calls the domain, saves through a port, and returns a result.
- Every handler takes the tenant context as its first input and passes it to every port.
- Authorization happens here, per use case, from the roles in the tenant context. Never only in a client.

## Host
- One function per file. A function validates the input's shape, takes the tenant (`tenancy.md` › Where the tenant comes from), calls one handler, and maps the result to a response or message. If it needs more than `host_max_lines` lines, the work belongs in a handler.
- Composition lives in the host's startup file: it's the only place that knows the concrete adapters.
- Each external system's integration runs in its own function app (`integrations.md`), so its failures, scaling and credentials stay separate.

## Default layout (.NET)
```
<App>.slnx
Directory.Build.props
src/<App>.Contracts/          contracts: Api/, Events/, Commands/, Messaging/
src/<App>.Domain/             domain: one folder per area
src/<App>.Application/        application: one folder per area, Ports/, Tenancy/
src/<App>.Infrastructure/     infrastructure
src/<App>.Functions/          host: one folder per area
src/<App>.Platform/           platform
src/<App>.Integrations.<System>/            integration
src/<App>.Integrations.<System>.Functions/  host for that integration
clients/<client>/             client: one folder per app (windows, mobile)
tests/<App>.<Layer>.Tests/    tests
infra/                        infrastructure as code (infra.md)
```
Other stacks keep the same layers with their own conventions; `stacks.md` gives each one's layout and `[layers]` patterns.
