<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Cost

A SaaS with one customer should cost close to nothing when idle, and grow with use, not with the number of tenants.

## Defaults
| Need | Default | Why |
|---|---|---|
| Compute | Azure Functions **Flex Consumption** (Linux), no always-ready instances | scales to zero; pay per execution |
| Data | Cosmos DB **serverless** | pay per request; nothing idle |
| Messaging | one Service Bus **Standard** namespace per environment | the cheapest tier with topics and sessions |
| Files and Functions storage | Storage **Standard LRS** | |
| Secrets (ideally none) | Key Vault **Standard** | |
| Monitoring | one workspace-based Application Insights and Log Analytics per environment, sampling on, a daily cap | logs are the classic surprise bill |
| Identity | Entra ID app registrations (free); External ID only by ADR | |
| A web front end, if a client is web-based | Static Web Apps **Free** (Standard by ADR, for private endpoints or an SLA) | static hosting at no cost; the API stays in Functions |

The check's `cost-sku` rule fails Bicep that asks for a premium, isolated or dedicated SKU (`Premium*`, `Isolated*`, `EP1`–`EP3`, `P*v*` App Service plans) or provisioned Cosmos DB throughput. Each of those is an ADR that names the need and the expected monthly cost, plus an `Exception: cost-sku <path>` line.

## Guardrails
- **A budget per environment** in Bicep, alerting the owner at 50%, 80% and 100% of a monthly amount that the human sets (a `PLACEHOLDER` until then).
- **Log Analytics daily cap**, and sampling in `host.json`.
- **No always-on resources** without an ADR: no VMs, no dedicated plans, no always-ready instances, no gateways.
- **Pooled tenancy** (`tenancy.md`): a new tenant adds data and traffic, not resources. A silo stamp is a product decision with a price attached.

## When to spend
Spend is a product decision when it buys something a customer needs: availability across regions, isolation for a regulated tenant, steady high load where provisioned capacity is cheaper. The ADR records the trigger, the cost, and how to go back.
