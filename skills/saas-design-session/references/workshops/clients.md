<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: clients

**Purpose:** settle what the Windows and mobile apps are for, where and how they're used, and the information needed to choose each one's UI technology.
**Length:** 2 hours · **Unblocks:** stage 5 (Clients).
**Participants:** product owner (decides) · 2–3 key users per client · UX designer · client development lead · solution architect · the customer's device or workplace IT, if devices are managed · facilitator · scribe.

## Prepare
- From the assessment: the existing clients, what they show, and whether their screens hold business rules.
- The capability list, marked with which client each capability belongs to.
- The UI technology options per client from the reference, as cards: for Windows WinUI 3, WPF, .NET MAUI or a web app in a desktop shell; for mobile .NET MAUI, native, Flutter or React Native.

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | The clients are separate apps; they share only the API. The decisions to reach. |
| 0:10 | A day in the life | Per client, a key user walks through a real day: where they are, the device, what they do most, what slows them down. |
| 0:40 | Environment | Devices, input (keyboard, scanner, touch, gloves), screen sizes, managed devices, connectivity. |
| 1:00 | Break | |
| 1:10 | Offline | For each capability on each client: must it work without a connection, and for how long? |
| 1:30 | UI technology criteria | Agree what matters for each client (data entry speed, device support, the team's skills, reuse of the old client), then score the option cards. The architect brings a recommendation. |
| 1:50 | Close | Read back what each client does, offline needs, and the recommendation per client. |

## Decisions to reach
- Which capabilities each client has.
- Offline needs per capability.
- The criteria for each client's UI technology, and a recommendation (decided in an ADR).

## Methods
- **Day-in-the-life walkthroughs** told by users, not by the team.
- **Option scoring** against agreed criteria, so the recommendation is explainable.

## Outputs
PRD › Clients; a "Decide: <client> UI technology" item and its ADR through `procedures/architect.md`; open questions for anything device-specific.
