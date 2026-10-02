<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: operations, security and cost

**Purpose:** agree where the product runs, how it's delivered and secured, the service levels and support, and what it may cost.
**Length:** 2 hours · **Unblocks:** stage 4 (Delivery).
**Participants:** operations or platform lead · security officer · the customer's or our cloud governance owner (subscriptions, policies, access) · finance or controller (budget) · product owner (service levels) · solution architect · facilitator · scribe.

## Prepare
- From the assessment: how the app is deployed and run today, its environments, and its monitoring.
- The reference's defaults in plain words: dev and prod environments, Bicep, CI/CD signing in with workload identity federation, managed identities, serverless SKUs, a budget per environment, production deployed by people.
- Ask the governance owner beforehand which Azure landing zone or subscription the product goes into, and the rules that apply there (naming, policies, role assignments).

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | The defaults; the decisions to reach. |
| 0:10 | Where it runs | Subscription or landing zone, region (from the tenancy workshop), environments, naming and tags. |
| 0:30 | Delivery | The CI/CD platform, how pipelines sign in (workload identity federation), approvals for production. |
| 0:50 | Security | Access for people (groups, just-in-time for production), managed identities, Key Vault, threat review of the target picture. |
| 1:05 | Break | |
| 1:15 | Service levels and support | Availability, recovery point and time, support hours, who is alerted for what. |
| 1:35 | Cost | The defaults' expected monthly cost per environment; the budget amounts and alert thresholds; how cost per tenant is measured for pricing. |
| 1:50 | Close | Read back the decisions. |

## Decisions to reach
- The subscription or landing zone, region and environments.
- The CI/CD platform and the production approval.
- Access for people and services.
- Service levels, support and alert routes.
- The budget per environment.

## Methods
- **Defaults first:** present each default and ask only "does anything stop us from using it?"; every "yes" is either solved in the room or becomes an ADR.

## Outputs
PRD › Service Levels; `infra/env/<env>.bicepparam` values (the budget amounts replace their placeholders); ADRs for anything beyond the cost defaults or the governance's rules; human items for subscriptions, role assignments and pipeline setup.
