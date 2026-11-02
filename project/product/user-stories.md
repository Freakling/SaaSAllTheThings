# User stories: {{PROJECT_NAME}}

The roles the product serves, and why each feature is built: the value for each role, the roles, and one table of stories per area. Every feature item in `TASKS.md` names the stories it serves (`Stories:`), and so does each capability in `product/prd.md`. The AI drafts stories; the director confirms them.

**Next ID:** US-6 · **Last validated:** never

<!-- How this file works (.satt/procedures/design.md › User stories):
     - A story is one thing a role does and why, in the role's words: "As a <role> I <do something>, so <why>". It never says how it's built.
     - Confirmed: the date the director last confirmed the story as it reads now, or `unconfirmed` (drafted, not confirmed yet).
     - Next ID: the ID the next story gets; bump it. IDs are never reused: a dropped story's row is deleted.
     - Last validated: `never`, or the date and commit of the last validation, such as 2026-11-14 at `4e1f0c2`.
       /next-task proposes the next one after [stories] every built items (tools/check.cfg).
     The roles and stories below are a worked example, a wholesaler's order desk. Onboarding replaces them with this product's own. -->

## The value in one paragraph per role

- **Sales clerk:** place a customer's order while they're at the counter or on the phone, faster than in the ERP, and know it reaches the books without typing it in twice.
- **Picker:** see what to pick today on a handheld, in the order the warehouse is walked, and mark it picked as you go, without a printed list.
- **Admin:** connect the company's ERP once, and decide who in the company can do what, without asking the vendor.

## Roles

The personas in PRD › Personas and Roles, by the same names: who each one is, and the app role that authorizes them, is written there. Every story's role is one of them; a new role is added there first.

- **Sales clerk**
- **Picker**
- **Admin**

## Orders

| ID | Story | Confirmed |
|---|---|---|
| US-1 | As a sales clerk I place an order for a customer while they wait, so they hear it's confirmed before they hang up. | 2026-11-01 |
| US-2 | As a sales clerk I find a customer by their ERP number however I type it, so one customer never becomes two. | 2026-11-01 |
| US-3 | As an admin I connect our ERP company once, so orders reach the books without anyone typing them in again. | unconfirmed |

## Picking

| ID | Story | Confirmed |
|---|---|---|
| US-4 | As a picker I see today's orders on my handheld in the order I walk the warehouse, so I walk it once. | 2026-11-01 |
| US-5 | As a picker I mark each line picked as I go, so the sales clerk can tell a customer where their order is. | unconfirmed |
