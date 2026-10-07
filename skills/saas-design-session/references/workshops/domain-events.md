<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: domain and events (event storming)

**Purpose:** map how the business actually works, as the events that happen, the commands that cause them and the rules in between, so the event-driven backend follows the business, and the old code can be extracted area by area.
**Length:** 3-4 hours · **Unblocks:** stages 0 (Extract) and 3 (First slice).
**Participants:** 2-4 domain experts (the people who do the work) · product owner · development lead · solution architect · facilitator (experienced with event storming) · scribe.

## Prepare
- The capability list from the capabilities workshop.
- From the assessment: where the business rules live in the old code, and the integrations.
- A long wall or a large whiteboard, and stickies in the standard colours: events orange, commands blue, actors yellow, policies purple, external systems pink, read models green, hot spots red.

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | What event storming is, in five minutes; the scope (the musts from the capabilities workshop). |
| 0:10 | Chaotic exploration | Everyone writes domain events, in the past tense ("Order placed"), and puts them on the timeline. No discussion yet. |
| 0:40 | Enforce the timeline | Order the events, remove duplicates, name the pivotal ones. Disagreements become red hot spots. |
| 1:10 | Break | |
| 1:20 | Commands and actors | For each event: the command that causes it and who or what issues it (a user role, a timer, an external system such as Navision). |
| 1:50 | Policies | "Whenever X happens, then Y": the reactions that become message consumers. |
| 2:15 | Aggregates and boundaries | Group the commands and events around the things that enforce the rules (aggregates), then draw the boundaries between areas. |
| 2:45 | Hot spots | Walk the red stickies: each one decided now, or an open question with an owner. |
| 3:15 | Close | Photograph the wall; read back the areas, and the events that cross them. |

## Decisions to reach
- The areas (bounded contexts) and what each owns.
- The events and commands that cross areas or systems: they become versioned contracts.
- The policies (reactions), and which are automatic and which need a person.
- The order to extract the old code's areas in.

## Methods
- **Big-picture event storming,** then design level for the first slice's area only.
- **Past-tense events, imperative commands:** the same naming the contracts use (`OrderPlacedV1`, `SyncOrderToNavisionV1`).

## Outputs
A draft of AGENTS.md › Architecture (the areas and the messages between them); the event and command names for the contracts; the Extract stage's order for `procedures/roadmap.md`; open questions for the hot spots. Photos of the wall go in the notes.
