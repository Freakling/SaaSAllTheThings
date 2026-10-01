# Order Desk (a SaaSAllTheThings example)

A small multi-tenant order desk: sales staff place orders on a Windows client, warehouse staff see them on mobile, and orders sync with each customer's Navision (Business Central). It's here to show what an app looks like under SaaSAllTheThings, and the self-test installs the framework into a copy of it.

It stands at the end of stage 1 (Foundation), with stage 2 (Tenancy and identity) planned:
- `src/` holds four layers: contracts, domain, application and one host function. Infrastructure, the platform and the clients don't exist yet; their items are in `TASKS.md`.
- `adr/` has the accepted stack decision (ADR-1) and a proposed one for the Windows client's UI (ADR-2).
- `integrations/navision/contract.md` is a Navision contract with its open questions.

## Try the workflow on it
1. Copy this folder somewhere outside this repository, and `git init` it.
2. Install SaaSAllTheThings into it: `bash <SaaSAllTheThings>/install.sh .`, then commit.
3. Open a session there and try `examples/scenarios.md`.

`bash tools/check.sh --architecture` works without any toolchain. The full check needs the .NET SDK 10.
