<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Roadmap

Plan the move to SaaS as stages in TASKS.md › Milestones, and write the items for the current stage and the next one. Onboarding runs this once; afterwards, run it when a stage is nearly done ("plan the next stage") or after a big product change ("replan").

Every SaaSAllTheThings project goes through the same stages, so any session knows where a project stands. A stage that doesn't apply (no integrations yet) stays in the table as `⬜ not needed yet`.

## Stages
| # | Stage | Done when |
|---|---|---|
| 0 | **Extract** (existing apps only) | every area of the old app that the product keeps has moved into the layers, or has an item; nothing outside the layers is still in use |
| 1 | **Foundation** | the layered skeleton builds, the check passes on a clean clone, one domain rule has a test |
| 2 | **Tenancy and identity** | requests are authenticated with Entra ID; the tenant comes from the token through the registry; a store has a tenant-isolation test |
| 3 | **First slice** | one capability works end to end: API → handler → store with its event in the outbox → a consumer |
| 4 | **Delivery** | Bicep deploys a dev stamp; CI runs the check and deploys dev with workload identity federation; a budget alerts |
| 5 | **Clients** | each client in PRD › Clients signs in and does the first capability; its UI tech is an accepted ADR |
| 6 | **Integrations** | each system in PRD › Integrations is planned with `integrate.md` and syncs its first entity |
| 7 | **Second tenant** | a second tenant onboards with `tenant.md` and sees none of the first one's data; export and deletion work; moving a tenant to its own stamp is a tested procedure |
| 8 | **Capabilities** | the rest of PRD › Capabilities, one slice at a time |

Stages 4–6 can overlap once stage 3 is done. The human may reorder them; file order in the table is their priority.

## Plan
1. **Read** TASKS.md › Milestones and the queue, PRD › Capabilities, Clients and Integrations, `AGENTS.md` › Layout and Architecture, and the ADRs' titles and statuses.
2. **Where are we?** The current stage is the first one not `✅`. Say which, and what's left in it.
3. **Write items for the current stage and the next one only.** Later stages stay as table rows; they'll be planned with what the earlier ones teach.
   - Follow `.satt/tasks.md`: each item with a Size, `Depends on`, `Touches`, tagged `Done when`, and `PRD:`.
   - Small: prefer `S`, split anything `L`. One capability's slice is contract, then domain and application with tests, then the host, then the client.
   - `human` items for what only the human can do: app registrations and consent, a Business Central sandbox, the budget amount, a production deploy.
   - Choices the reference leaves open become an item "Decide: <choice> (architect.md)" before the items that need it, owned by the human.
4. **Per stage, the usual items:**
   - **Extract:** for each area of the old app (a screen group, a service, a job), first "Characterise: <area>" (tests that pin today's behaviour, run against the old code), then "Extract: <area>" (move its rules into domain and application in the chosen stack, the old entry point calling the new code where it can). Secrets found in the old code become `high` bugs: rotate, then remove.
   - **Foundation:** the solution or workspace with the layers from `reference/layers.md`; `tools/check.cfg` › `[layers]` and `[imports]` matching it; the first domain rule with a test; the check passing after a fresh clone.
   - **Tenancy and identity:** the tenant context and its port; the registry in `platform` with a store and an isolation test; token validation in the host; the API and client app registrations (human); a local development story (a test issuer or the developer's own sign-in).
   - **First slice:** the first capability in PRD order, end to end, with its event through the outbox and one consumer.
   - **Delivery:** one Bicep module per resource, the dev parameters, the budget (`PLACEHOLDER` amount), CI with workload identity federation, the first deploy (via `release.md`).
   - **Clients:** per client, "Decide: <client> UI technology", then the shell with sign-in, then the first capability.
   - **Integrations:** per system, run `integrate.md`; it writes that system's items.
   - **Second tenant:** tenant export and deletion, the stamp-move procedure, a tenant onboarding dry run with `tenant.md`.
5. **Milestones.** Keep the stage table in TASKS.md › Milestones current: `✅ done · 🟨 in progress · ⬜ not started`.
6. **Report** the stage, the new items, the human items, and the decisions waiting. Commit as `docs: plan <stage>` after the human approves.
