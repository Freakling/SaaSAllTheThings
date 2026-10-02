<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Workshop: tenancy, identity and data

**Purpose:** settle what a tenant is, how its users sign in, who may do what, how tenants are kept apart, and the rules for their data.
**Length:** 2 hours · **Unblocks:** stages 2 (Tenancy and identity) and 7 (Second tenant).
**Participants:** product owner · solution architect (decides within the reference) · security officer · the first customer's IT administrator (decides their directory) · data protection officer or legal, for data rules · facilitator · scribe.

## Prepare
- From the assessment: how sign-in works today, where users and roles live, and anything that already identifies a customer in the data.
- The reference's defaults as the starting point, in plain words: pooled tenancy, the tenant taken from the signed-in user's token only, each customer signing in with its own Microsoft Entra ID directory, no secrets anywhere.
- Ask the first customer's IT administrator beforehand whether they use Entra ID, and whether admin consent for a multi-tenant app is allowed.

## Agenda
| Time | Block | How |
|---|---|---|
| 0:00 | Frame | The defaults, and that a deviation needs a recorded reason. |
| 0:10 | What a tenant is | A company, a subsidiary, a site? One tenant or several for a customer group? |
| 0:25 | Sign-in | Per expected customer: Entra ID, another provider (then External ID federation), or local accounts (not offered). How consent and first sign-in work for a new customer. |
| 0:45 | Roles | The app roles from the capabilities workshop; who assigns them in the customer's directory. Operator access for our own staff. |
| 1:00 | Break | |
| 1:10 | Isolation | Pooled by default. Does any customer need its own deployment (a silo), and would they pay for it? |
| 1:25 | Data rules | Where data must stay (region), how long it's kept, what's personal, audit needs, export and deletion when a customer leaves. |
| 1:50 | Close | Read back the decisions and the open questions. |

## Decisions to reach
- What a tenant is.
- The identity providers to support, and the consent process.
- The app roles, and who assigns them.
- Pooled for everyone, or a silo for named customers (a product decision with a price).
- Region, retention, personal data and audit rules.

## Methods
- **Persona walk:** take one user per role through their first day: invitation, sign-in, what they see.
- **Data map:** a table of the main data, with owner, personal or not, and retention.

## Outputs
PRD › Customers and Tenants, Personas and Roles, Data and Compliance; an ADR for anything beyond the defaults (External ID, a silo, a credential that can't be avoided); human items for the app registrations and consent.
