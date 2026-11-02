# {{PROJECT_NAME}} · Product Requirements

<!-- How this document works
- It states the current requirements only. History is in git, the reason for each decision is in
  product/decisions.md, and anything undecided is under Open Questions. Agents write down only what
  the human decided.
- Refer to sections by heading ("PRD › Orders"), never by number. Add a subsection rather than
  growing a long one, and delete sections this product doesn't need.
- Say what a number is for and how it should feel; undecided values are PLACEHOLDER in the code.
- How the system is built lives in .satt/reference/ and adr/, not here.
- Why each capability is built lives in the user stories (product/user-stories.md); the capability
  says who does it and names the stories it serves.
-->

## Pitch
{{ONE_PARAGRAPH_PITCH}}

## Product Pillars
<!-- 3-5 short statements every capability is checked against. -->

## Customers and Tenants
<!-- Who the customers (tenants) are, the first one, and the plans (tiers) with what each includes.
Limits that aren't decided yet are Open Questions. -->

## Personas and Roles
<!-- Who uses the product inside a tenant, and the app roles that authorize them
(e.g. Tenant.Admin, Tenant.User). Each persona is a role in the user stories, by the same name. -->
What each persona does in the product, and why, is in the [user stories](user-stories.md).

## Capabilities
<!-- One ### subsection per capability: who does it, on which client, the rules, what other
capabilities or integrations it touches, and a last line naming the user stories it serves
(Stories: US-1, US-3). Order is priority. -->

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
