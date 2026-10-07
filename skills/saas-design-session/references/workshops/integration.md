<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: integration

One per external system. Navision (Dynamics NAV / Business Central) usually comes first.

**Purpose:** agree what flows between the product and the system, which side owns which data, what happens when both change, and how the product reaches the system safely.
**Length:** 2-3 hours per system · **Unblocks:** stage 6 (Integrations).
**Participants:** the system's owner on the customer side (decides about their system) · a Navision or Business Central consultant or administrator · a key user from finance or operations · the customer's IT (network and access) · integration developer · solution architect · facilitator · scribe.

## Prepare
- From the assessment: how the app talks to the system today (web services, OData, files), and the entities involved.
- Ask beforehand: the product and version (Business Central online, Business Central on-premises, or which NAV version), and whether a sandbox can be had.
- An entity sheet: one row per entity in scope, with columns for direction, owner and change detection, left empty.

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | The purpose of the integration from the capabilities workshop; the decisions to reach. |
| 0:10 | The system | Product, version, hosting, how it can be reached, and the sandbox. |
| 0:25 | Entities and direction | Fill the entity sheet: each entity in or out or both. Start with the fewest that deliver the purpose. |
| 0:50 | Ownership | Per entity, and per field where it splits: which system is the record of truth. The decision that matters most for a two-way sync. |
| 1:15 | Break | |
| 1:25 | Conflict drills | Walk through concrete cases: both sides changed the same record; the system was down for a day; a record was deleted on one side. Decide the rule for each. |
| 1:55 | Access and credentials | Online: consent for an integration app, permission sets. On-premises: an outbound-only connector, or a VPN. No stored passwords unless there's no alternative. |
| 2:15 | Failures and reconciliation | Who is alerted, how fast; how often both sides are compared and drift repaired. |
| 2:35 | Close | Read back the entity sheet and the rules. |

## Decisions to reach
- Entities in scope, and the direction of each.
- The owner (system of record) per entity, and per field where it splits.
- The conflict rule per case drilled.
- How the product reaches the system, and with which credentials.
- Alerts and reconciliation.
- The sandbox, and who provides it.

## Methods
- **Entity sheet:** filled live, on screen, by the scribe.
- **Conflict drills:** concrete stories with real record examples, never abstract rules.

## Outputs
`integrations/<system>/contract.md` (through `procedures/integrate.md`, which then plans the stages); product decisions in `product/decisions.md`; an ADR for a stored credential or a VPN; human items for the sandbox, consent and permission sets.
