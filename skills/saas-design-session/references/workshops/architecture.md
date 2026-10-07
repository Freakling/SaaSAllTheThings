<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: architecture and transformation approach

**Purpose:** agree the backend stack, what of the old code is reused or rebuilt, how it's extracted without stopping the business, and the few choices the reference leaves open.
**Length:** 3 hours · **Unblocks:** stages 0 (Extract) and 1 (Foundation).
**Participants:** solution architect (decides within the reference) · development lead and 2-3 developers who know the old code · operations lead · product owner, for the trade-offs that affect the product · facilitator · scribe.

## Prepare
- From the assessment: the readiness scores, the target picture (each component and the layer it becomes), the stack found and the human's preference, and the risks.
- The reference in plain words: the layers and what each may depend on, the event-driven backend on Azure Functions, the outbox, the cost defaults, and that a deviation is a recorded, accepted decision.
- The options for each decision, with a recommendation.

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | The reference and its rules; the decisions to reach. |
| 0:15 | The stack | Keep the current stack (if compatible), move to .NET (the default), or another compatible stack. Team skills, reuse, risk. |
| 0:45 | The target picture | Walk the component table: keep, extract, rebuild or retire. Developers correct the assessment where it's wrong. |
| 1:15 | Break | |
| 1:25 | Extraction strategy | Strangler approach per area: characterisation tests first, then move the rules into the domain, with the old entry point calling the new code. The order follows the domain-events workshop. |
| 1:55 | Open choices | Data store (Cosmos DB serverless by default; Azure SQL serverless when an existing relational model is kept), and anything else the target picture raised. |
| 2:25 | Risks | The top risks from the assessment, each with what reduces it and an owner. |
| 2:50 | Close | Read back the decisions. |

## Decisions to reach
- The backend stack.
- Per component: keep, extract, rebuild or retire.
- The extraction order and approach.
- The data store, and any other open choice.
- Owners for the top risks.

## Methods
- **Component table** on screen, edited live.
- **Options with a recommendation** for every decision; complying with the reference is always option one for a proposed deviation.

## Outputs
ADR-1 (the backend stack) and an ADR per other choice, through `procedures/architect.md`; `tools/check.cfg` › `[layers]` for the target folders; the Extract stage's items for `procedures/roadmap.md`.
