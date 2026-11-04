<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Integrate

Add an enterprise integration, or change one: work out its contract with the human, then plan it in stages. The shape and rules are in `.satt/reference/integrations.md`; read it first. Navision (Dynamics NAV / Business Central) has its own table there.

The request names the system ("navision"). Its folder is `integrations/<system>/`, lowercase.

## 1. Prepare
- Read PRD › Integrations › <System> (add the subsection through `design.md` first if it's missing), the existing `integrations/<system>/contract.md` if any, and the open questions tagged with the system.
- If the integration exists, say what's built (TASKS.md, AGENTS.md › Architecture) before proposing changes.

## 2. Work out the contract
Go through the contract with the human in short rounds: the existing `integrations/<system>/contract.md`, or `.satt/templates/integration-contract.md` when there is none yet. Hold each round's answers in the conversation; the contract is filled from them after the summary (4. Records and finish). Write nothing until the human approves a summary of all of it (`design.md` › Summary and approval); a chat message or an "Other" answer before then re-opens the options. For each round, first quote or summarise the relevant guidance from `.satt/reference/integrations.md` (including the Navision table where it applies) and the current contract value if one already exists, then offer options with a recommendation. This gives the human the full picture before choosing. Business answers are product decisions (`design.md` › Record each decision); how the system is reached and authenticated may be an ADR (`architect.md`).
1. **The system:** product and version, per tenant if they differ. For Navision: Business Central online, Business Central on-premises, or which NAV version.
2. **Entities in scope** and, for each, the direction: in, out or both. Start with the fewest that deliver the PRD's purpose.
3. **Ownership:** the system of record per entity, and per field where it splits. This is the decision that matters most for a bidirectional sync; never assume it.
4. **Change detection** per entity: webhooks, polling and how often.
5. **Conflicts:** what happens when both sides changed: the owner wins, the latest timestamp wins, or it's held for a person. Who resolves held conflicts.
6. **Reaching it and credentials:** from the reference's table. A Key Vault credential or a VPN is a deviation: an ADR.
7. **Failures and reconciliation:** retries, alerts and who receives them, and how often a reconciliation job compares both sides.
8. **Per-tenant connection data** and the human's onboarding steps for a tenant (consent, permission sets, a connector install).
9. **Testing:** which sandbox, who provides it, and the recorded responses the contract tests use.

Anything the human can't answer yet becomes a `Q<n>` for PRD › Open Questions, named in the contract row it gates.

## 3. Plan it in stages
Draft the items for TASKS.md (`.satt/tasks.md`), small and in this order, each stage usable before the next:
1. **Adapter skeleton:** the `integration` project and its function app host; the external client with recorded-response contract tests; the per-tenant connection in the registry.
2. **Inbound read, one entity:** detect changes, map them, publish the integration event, a handler that applies it; the mapping table with its tenant-isolation test.
3. **Outbound, one entity:** the command, the adapter's idempotent call, the outcome event; echo suppression.
4. **Conflicts and reconciliation:** the contract's conflict rule, the reconciliation job, dead-letter alerts.
5. **The next entities,** one item each, following the same pattern.
6. **Human items:** a sandbox, the integration app registration and the customer's consent, permission sets in the system, a connector install where it applies.

## 4. Records and finish
- **Summary and approval.** Show one summary of everything this session will write, each as it will read, and wait: the contract, filled from the rounds' answers; the TASKS.md items in full; the AGENTS.md rows; the PRD link; and the decision lines, the open questions and any ADR with its status. Ask "Approve this summary, or tell me what to change?" A change re-opens the rounds it touches, and a new summary follows.
- Once the human approves it, write everything it lists: copy `.satt/templates/integration-contract.md` to `integrations/<system>/contract.md` if it doesn't exist and fill it in, add the items to TASKS.md, write the decision lines and the open questions (`design.md` › Record each decision) and any ADR (`architect.md` › Record), and the records below.
- AGENTS.md › Architecture: rows for the adapter and its function app, with the messages they publish and consume.
- PRD › Integrations › <System>: a one-line link to the contract, and its purpose.
- Say what was decided, what's open, and the first item. Commit as `docs: <system> integration contract`; the approval of the summary is the approval to commit.
