# {{PROJECT_NAME}} · Product Requirements

<!-- How this document works
- It states the current requirements only. History is in git, the reason for each decision is in
  product/decisions.md, and anything undecided is under Open Questions. Agents write down only what
  the human decided.
- Refer to sections by heading ("PRD › Orders"), never by number. Add a subsection rather than
  growing a long one, and delete sections this product doesn't need.
- Say what a number is for and how it should feel; undecided values are PLACEHOLDER in the code.
- How the system is built lives in .satt/reference/ and adr/, not here.
-->

## Pitch
{{ONE_PARAGRAPH_PITCH}}

## Product Pillars
<!-- 3–5 short statements every capability is checked against. -->

## Customers and Tenants
<!-- Who the customers (tenants) are, the first one, and the plans (tiers) with what each includes.
Limits that aren't decided yet are Open Questions. -->

## Personas and Roles
<!-- Who uses the product inside a tenant, and the app roles that authorize them
(e.g. Tenant.Admin, Tenant.User). -->

## Capabilities
<!-- One ### subsection per capability: who does it, on which client, the rules, and what other
capabilities or integrations it touches. Order is priority. -->

## Clients
### Windows
<!-- Who uses it, for which capabilities, offline needs. -->
### Mobile
<!-- Who uses it, for which capabilities, offline needs. -->

## Integrations
<!-- One ### per external system: its business purpose and direction. The details live in
integrations/<system>/contract.md. -->

## Data and Compliance
<!-- Data residency, retention, which data is personal, audit needs, export and deletion. -->

## Service Levels
<!-- Availability, recovery point and time, support hours. -->

## Glossary
| Term | Meaning |
|---|---|

## Open Questions
<!-- Numbered Q<n>, never reused. When one is answered: write the rule into its section, add a line
to product/decisions.md, and delete the question here. -->
**Next:** Q1
