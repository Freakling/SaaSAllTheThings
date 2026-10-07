<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Tenant onboarding

Prepare a new tenant (customer): check that the product is ready for them, and hand the human the steps only they can take. A tenant is data in the registry, never code, so onboarding changes no code; what's missing becomes items.

Customer details (names, directory ids, contacts) aren't written into the repository. The registry holds them.

## 1. Readiness
Check, and report each as ready or missing:
1. **Isolation:** every store has a tenant-isolation test (`grep` the tests for the stores in AGENTS.md › Architecture). Missing ones are `high` bugs.
2. **No tenant-specific code:** `bash tools/check.sh --architecture` passes the `tenant-branching` rule with no ADR exceptions for it.
3. **Plan:** the tenant's plan exists in PRD › Customers and Tenants, and its limits are decided (no `PLACEHOLDER` left on it), or the human accepts placeholders for a pilot.
4. **Identity:** the customer signs in with Entra ID (multi-tenant consent) or needs External ID federation (an ADR, if the project doesn't have it yet).
5. **Integrations:** for each system the customer uses, the contract covers their version (`integrations/<system>/contract.md` › The system), and the per-tenant steps are known.
6. **Stamp:** pooled (the default), or a silo the human has decided on and priced (`reference/tenancy.md` › Silo-ready). A first silo needs the stamp-move work from roadmap stage 7.

Missing pieces become TASKS.md items (`.satt/tasks.md`), or product questions through `design.md`.

## 2. The human's steps
Write them out for the human, in order, with exactly what to send or click. They're not stored in the repository. Typically:
1. Create the tenant in the registry through the platform API or tool (status `onboarding`), with its plan and stamp.
2. Send the customer's admin the consent link for the API app (and the integration app), and confirm consent arrived.
3. The customer's admin assigns app roles to their users or groups.
4. Per integration: the customer's permission sets, connector install or sandbox, as the contract says; then the connection in the registry.
5. Smoke test as a user of the new tenant, then set the tenant `active`.

## 3. Finish
Report what's ready, what's missing (with the items created), and the steps. Commit any new items as `docs: prepare tenant onboarding` after the human approves; don't name the customer in the commit.
