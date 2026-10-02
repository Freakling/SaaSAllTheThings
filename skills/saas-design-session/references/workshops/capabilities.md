<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: capabilities

**Purpose:** turn the existing app into a list of capabilities the SaaS keeps, changes or retires, in priority order, and pick the first slice.
**Length:** 3 hours · **Unblocks:** stages 0 (Extract), 3 (First slice) and 8 (Capabilities).
**Participants:** product owner (decides) · 2–4 key users per persona · business analyst · development lead · facilitator · scribe.

## Prepare
- From the assessment: the inventory of screens, reports, jobs and integrations, each as a card with what it does and how much it's used, if known.
- The personas you expect, as a starting list.

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | The pillars from the vision workshop on the wall; the decisions to reach. |
| 0:10 | Personas and roles | Who uses the app, and for what; agree the app roles each needs (for example Tenant.Admin, Tenant.User). |
| 0:30 | Walk the app | Go through the inventory cards one by one. For each: the capability it serves, and keep, change or retire. Users say what they actually do with it. |
| 1:30 | Break | |
| 1:40 | Gaps | What users do outside the app today (spreadsheets, the ERP, email) that the SaaS should cover. New cards. |
| 2:00 | Prioritise | Order the capability cards: must, should, could, won't for the first release, then rank the musts. |
| 2:30 | First slice | Pick the capability for the first end-to-end slice: valuable, small, touching tenancy and the main integration early. |
| 2:50 | Close | Read back the list, the retirements and the first slice. |

## Decisions to reach
- The personas and their app roles.
- Each existing feature: keep, change or retire.
- The capability list in priority order, with what's out of the first release.
- The first slice.

## Methods
- **Card walk:** one card per screen, report or job; the users speak first, then the team.
- **MoSCoW** for the first release, then a strict ranking of the musts: no ties.

## Outputs
PRD › Personas and Roles and Capabilities (one subsection each, in priority order); `product/decisions.md`; the first slice for `procedures/roadmap.md`. Retired features become a note in the PRD so nobody rebuilds them.
