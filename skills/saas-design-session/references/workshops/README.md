<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshops

The working sessions that turn an assessment into decisions. Each file here is one workshop: its purpose, who takes part, the preparation, a timed agenda, the methods, the decisions it must reach, and where those decisions are recorded. `procedures/assess.md` picks the ones an app needs and tailors them in the assessment report.

## The workshops
| Workshop | Settles | Unblocks |
|---|---|---|
| `vision.md` | why, for whom, how it earns: pitch, customers, plans, pillars, constraints | everything |
| `capabilities.md` | what the product does: capabilities from the existing app, keep / change / retire, the first slice | stages 0, 3, 8 |
| `domain-events.md` | how the business works: events, commands, aggregates and boundaries (event storming) | stages 0, 3 |
| `tenancy-identity.md` | who the tenants are, how they sign in, roles, isolation, data rules | stages 2, 7 |
| `integration.md` | one per external system, Navision first: ownership, direction, conflicts, access | stage 6 |
| `clients.md` | the Windows and mobile apps: who, where, offline, the UI technology | stage 5 |
| `architecture.md` | the stack, reuse or rebuild, how to extract the old code, data store | stages 0, 1 |
| `operations.md` | environments, delivery, security, service levels, support, cost | stage 4 |
| `planning.md` | the order of the stages, the first slice, who does what next | the start of the build |

## Sequence
1. `vision.md` first: every other workshop checks its choices against the pillars it sets.
2. `capabilities.md`, then `domain-events.md`: the product view, then the business behind it.
3. `tenancy-identity.md`, `integration.md` (one per system), `clients.md` and `architecture.md`, in parallel tracks when different people are needed.
4. `operations.md` once the architecture is settled.
5. `planning.md` last, to close.

Typically two to three weeks for a mid-size app, with a day or two between sessions to process the notes and prepare the next one.

## Sizing
- **Small app** (one team, one integration): three sessions. Product (vision and capabilities), technical (domain and events, architecture, tenancy and identity), then integration and operations, then planning in the last hour.
- **Mid-size app:** the nine as listed.
- **Large app:** `capabilities.md` and `domain-events.md` once per area, then one architecture session per area that's extracted.

## Running a workshop
- **One decision owner** per decision is in the room: the product owner for product calls, the architect for architecture calls within the reference, the customer's owner for their systems and data. Without them, the topic becomes an open question instead of a guess.
- **Prepare from the assessment.** The facilitator sends a pre-read two working days before: the purpose, the decisions to reach, and the relevant findings. Participants come with answers, not questions.
- **Decide with options.** Each decision is put as 2-4 options, with a recommendation and what each costs, then the owner decides. The same shape as the rest of the workflow.
- **Timebox and park.** Each agenda block has a time. Anything that runs over, or can't be decided, goes to the parking lot and becomes an open question with an owner and a date.
- **Write down decisions, not discussion.** Only what was decided becomes a record; how the room got there is a one-line reason.
- **The AI assistant's role:** it prepares the pre-read and the options from the assessment, scribes live into the notes file, and proposes; it doesn't decide, and records only what the owner said.
- **Remote or on site.** Remote: a shared whiteboard, cameras on, 90 minutes at most per session with a break. On site: sticky notes and a wall, photos of the board into the notes. Either way, the scribe confirms each decision aloud before moving on.
- **Roles, not names,** in anything that goes into the repository.

## Notes
Each session's notes go to `assessment/workshops/YYYY-MM-DD-<name>.md`. For a workshop, the name is its file's (`2026-10-02-integration.md`); for any other design session, its kind and topic (`2026-10-02-architecture-windows-client-ui.md`); a second file of the same name that day adds `-2`. The shape:
```
# <Workshop> · YYYY-MM-DD
**Participants** (roles): product owner, sales lead, architect · **Facilitator:** · **Scribe:**

## Decisions
- <decision> · why: <one line> · owner: <role>

## Open questions
- <question> · owner: <role> · by: YYYY-MM-DD

## Actions
- <action> · owner: <role> · by: YYYY-MM-DD

## Notes
<anything else worth keeping, briefly>

## ADR drafts
### ADR-? · <title>
<only for architecture decisions: one per decision, in the shape of templates/adr.md with every
heading two levels down (#### Context, #### Options …), status proposed>
```
- **Who and when.** In a one-to-one session, Participants is the human's role (ask once; if they'd rather not say, `the human`) and the assistant, and the decisions' owner is that role. A date nobody gave is `by: none`, never a guess.
- **A deviation turned down is a decision too:** "comply with reference/<topic>.md › <heading>", with why.
- **ADR drafts** stay `ADR-?` and proposed in the notes: choosing an option is a decision in the room; accepting the ADR happens when the notes are processed, by the human.
Then `procedures/assess.md` › Process workshop notes turns them into records: the PRD, ADRs, integration contracts and TASKS.md. Before SaaSAllTheThings is installed, onboarding reads them instead.

The same notes come from a session held without the app's repository at hand, for example with the `saas-design-session` skill in Cowork or the Claude apps: they're processed the same way once they're in `assessment/workshops/`.
