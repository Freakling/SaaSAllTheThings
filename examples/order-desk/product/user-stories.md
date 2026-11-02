# User stories: Order Desk

The roles the product serves, and why each feature is built: the value for each role, the roles, and one table of stories per area. Every feature item in `TASKS.md` names the stories it serves (`Stories:`), and so does each capability in `product/prd.md`. The AI drafts stories; the director confirms them.

**Next ID:** US-6 · **Last validated:** never

<!-- How this file works (.satt/procedures/design.md › User stories):
     - A story is one thing a role does and why, in the role's words: "As a <role> I <do something>, so <why>". It never says how it's built.
     - Confirmed: the date the director last confirmed the story as it reads now, or `unconfirmed` (drafted, not confirmed yet).
     - Next ID: the ID the next story gets; bump it. IDs are never reused: a dropped story's row is deleted.
     - Last validated: `never`, or the date and commit of the last validation, such as 2026-11-14 at `4e1f0c2`.
       /next-task proposes the next one after [stories] every built items (tools/check.cfg). -->

## The value in one paragraph per role

- **Sales clerk:** place a customer's order at the counter or on the phone faster than in Navision, and know it reaches Navision without typing it in twice.
- **Picker:** see today's orders to pick on a handheld, and mark lines picked as you go, without a printed list.
- **Admin:** connect the wholesaler's Navision company once, and decide who in the company can use the order desk.

## Roles

The personas in PRD › Personas and Roles, by the same names: who each one is, and the app role that authorizes them, is written there. Every story's role is one of them; a new role is added there first.

- **Sales clerk**
- **Picker**
- **Admin**

## Orders

| ID | Story | Confirmed |
|---|---|---|
| US-1 | As a sales clerk I place an order for a customer while they wait, so they hear it's confirmed before they hang up. | 2026-09-29 |
| US-2 | As a sales clerk I enter a customer's Navision number however I type it, so one customer never becomes two. | 2026-09-30 |

## Signing in

| ID | Story | Confirmed |
|---|---|---|
| US-3 | As a sales clerk I sign in with my company account, so I need no separate password for the order desk. | unconfirmed |

## Navision

| ID | Story | Confirmed |
|---|---|---|
| US-4 | As an admin I connect our Navision company once, so orders reach the books without anyone typing them in again. | 2026-09-28 |

## Picking

| ID | Story | Confirmed |
|---|---|---|
| US-5 | As a picker I see today's placed orders on my handheld, so I know what to pick. | unconfirmed |
