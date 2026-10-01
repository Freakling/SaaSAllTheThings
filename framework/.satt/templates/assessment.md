<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. The assessment report's shape
(procedures/assess.md). Copy it to assessment/YYYY-MM-DD-assessment.md, fill every section, and
delete this comment and the guidance in parentheses. Self-contained: no links into .satt/. -->
# <App> · SaaS assessment

- **Date:** YYYY-MM-DD · **Build:** <git rev-parse --short HEAD> · **For:** <internal planning / customer proposal>
- **Scope:** <the repository, and anything not looked at>

## Summary
(One paragraph: what the app is, how far it is from a multi-tenant SaaS on Azure, the recommended path, the top three risks, and the first step.)

## What the app is today
(Shape, entry points, business rules, data, identity, configuration, integrations, clients, tests and delivery. Short paragraphs or a table, each with evidence: file:line, counts, commands.)

## SaaS readiness
0: absent or blocking · 1: present, must be rebuilt · 2: reusable with changes · 3: already fits

| Dimension | Score | Evidence | What it takes |
|---|---|---|---|
| Stack | | | |
| Separation of business rules | | | |
| Data and tenant-awareness | | | |
| Identity | | | |
| Configuration and secrets | | | |
| Integrations | | | |
| Clients | | | |
| Tests | | | |
| Delivery and operations | | | |

## The target
The reference architecture in brief: an event-driven backend on Azure Functions; pooled multi-tenancy, with the tenant taken only from the signed-in user's token; sign-in through each customer's own directory (OIDC, federated identity); separate, thin Windows and mobile clients; one adapter per external system; serverless, pay-per-use Azure services.

| Today | Becomes | How |
|---|---|---|
| (component) | (layer: contracts, domain, application, infrastructure, integration, host, platform, client) | keep / extract / rebuild / retire |

(What the target adds that the app doesn't have yet.)

## Decisions needed
(Each with 2–4 options, a recommendation and a one-line reason. The stack comes first.)

## Roadmap
| Stage | What this app needs | Main items (size) | Effort, person-days (confidence) | Depends on | Workshop first |
|---|---|---|---|---|---|
| 0 · Extract | | | | | |
| 1 · Foundation | | | | | |
| 2 · Tenancy and identity | | | | | |
| 3 · First slice | | | | | |
| 4 · Delivery | | | | | |
| 5 · Clients | | | | | |
| 6 · Integrations | | | | | |
| 7 · Second tenant | | | | | |
| 8 · Capabilities | | | | | |

(Assumptions behind the estimates, and what would narrow them. The recommended first slice, and why.)

## Risks and assumptions
| Risk or assumption | Likelihood · impact | What reduces it |
|---|---|---|

## Workshops
(The sequence first: a table of workshop, purpose, length, the stage it unblocks, and which can run in parallel. Then one subsection per workshop.)

### <Workshop>
- **Why this app needs it:**
- **Participants** (roles):
- **Length and format:**
- **Prepare:** (pre-reads, what the facilitator brings)
- **Decisions and questions for this app:**
- **Agenda:**

  | Time | Block | How |
  |---|---|---|

- **Outputs:** (the decisions written down, and where they go)

## Open questions
(Everything the scan couldn't answer, each named for the workshop that answers it.)

## Next steps
(The first workshop: who to invite, the pre-read to send, the date to aim for. Then installing SaaSAllTheThings, whose onboarding reads this report and the workshop notes.)
