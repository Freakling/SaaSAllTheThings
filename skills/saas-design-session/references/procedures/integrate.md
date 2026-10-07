<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Integrate

Add an enterprise integration, or change one: work out its contract with the human, then plan it in stages. The shape and rules are in `.satt/reference/integrations.md`; read it first. Navision (Dynamics NAV / Business Central) has its own table there.

The request names the system ("navision"). Its folder is `integrations/<system>/`, lowercase.

## 1. Prepare
- Read PRD › Integrations › <System> (add the subsection through `design.md` first if it's missing), the existing `integrations/<system>/contract.md` if any, and the open questions tagged with the system.
- If the integration exists, say what's built (TASKS.md, AGENTS.md › Architecture) before proposing changes.

## 2. Work out the contract
Copy `.satt/templates/integration-contract.md` to `integrations/<system>/contract.md` if it doesn't exist. Then go through it with the human in short rounds, each answer as options with a recommendation. Business answers are product decisions (`design.md` › Record each decision); how the system is reached and authenticated may be an ADR (`architect.md`).
1. **The system:** product and version, per tenant if they differ. For Navision: Business Central online, Business Central on-premises, or which NAV version.
2. **Entities in scope** and, for each, the direction: in, out or both. Start with the fewest that deliver the PRD's purpose.
3. **Ownership:** the system of record per entity, and per field where it splits. This is the decision that matters most for a bidirectional sync; never assume it.
4. **Change detection** per entity: webhooks, polling and how often.
5. **Conflicts:** what happens when both sides changed: the owner wins, the latest timestamp wins, or it's held for a person. Who resolves held conflicts.
6. **Reaching it and credentials:** from the reference's table. A Key Vault credential or a VPN is a deviation: an ADR.
7. **Failures and reconciliation:** retries, alerts and who receives them, and how often a reconciliation job compares both sides.
8. **Per-tenant connection data** and the human's onboarding steps for a tenant (consent, permission sets, a connector install).
9. **Testing:** which sandbox, who provides it, and the recorded responses the contract tests use.

Anything the human can't answer yet becomes a `Q<n>` in PRD › Open Questions, named in the contract row it gates.

## 3. Plan it in stages
Add items to TASKS.md (`.satt/tasks.md`), small and in this order, each stage usable before the next:
1. **Adapter skeleton:** the `integration` project and its function app host; the external client with recorded-response contract tests; the per-tenant connection in the registry.
2. **Inbound read, one entity:** detect changes, map them, publish the integration event, a handler that applies it; the mapping table with its tenant-isolation test.
3. **Outbound, one entity:** the command, the adapter's idempotent call, the outcome event; echo suppression.
4. **Conflicts and reconciliation:** the contract's conflict rule, the reconciliation job, dead-letter alerts.
5. **The next entities,** one item each, following the same pattern.
6. **Human items:** a sandbox, the integration app registration and the customer's consent, permission sets in the system, a connector install where it applies.

## 4. Records and finish
- AGENTS.md › Architecture: rows for the adapter and its function app, with the messages they publish and consume.
- PRD › Integrations › <System>: a one-line link to the contract, and its purpose.
- Summarise what was decided, what's open, and the first item. Commit as `docs: <system> integration contract` after the human approves.
