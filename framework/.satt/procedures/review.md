<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Review

Review a finished, uncommitted change against its TASKS.md item, the rules and the reference architecture, with fresh eyes. You didn't write this change. **Read only**: never edit files or run commands that change anything.

You're given:
- the item ID;
- the builder's report;
- the check result;
- the diff, including new files, in `.satt/state/review.diff`.

The records (TASKS.md, AGENTS.md) are already updated in it. Read the item, the diff, the code the diff calls into, and the reference topics it touches. That's enough to judge it; don't read the whole project.

Check, most important first:
1. **Correctness.** Does each `(test)` and `(check)` outcome hold, and is each `(demo)` outcome implemented? Look at edge cases, empty and null input, concurrency (ETags, repeated messages), and failures half-way through.
2. **Tenant isolation** (`reference/tenancy.md`). Every query, write, blob path, cache key and message takes the tenant from the tenant context. A new store has a tenant-isolation test. Another tenant's data answers 404. Nothing reads all tenants outside `platform`.
3. **Identity and secrets** (`reference/identity.md`). Tokens are validated before handlers run; authorization is in the handler, per use case; no secret, key or credential in code, config or logs.
4. **Messaging** (`reference/messaging.md`). Events are saved with their state through the outbox, not published from a handler. Consumers are idempotent. Contract changes within a version are additive only.
5. **Architecture** (`.satt/reference/`, `rules.md` › Architecture in code). What the check can't see: business rules in a host or client, a port that leaks an SDK type, a handler doing two use cases, an integration's model leaking past its layer, a value hand-picked where it should be a `PLACEHOLDER`.
6. **Cost** (`reference/cost.md`). New resources use the default SKUs; nothing always-on; logs and metrics don't explode with tenants.
7. **Scope.** Changed files missing from `Touches`, unless the report's `Touches:` line explains them. Listed files left untouched (is the work incomplete?), and unrelated changes mixed in.
8. **Records.** AGENTS.md › Architecture matches the report's `Systems:` line, and every `(test)` outcome has a test.
9. **Simpler.** Code that could be deleted beats adding a safeguard.

Report findings most severe first. Give each one `file:line`, what's wrong, a concrete way it fails, and whether it's in the code or the records. A finding that needs an architecture call says so, for `architect.md`. Skip style remarks while correctness problems remain. If there's nothing to report, say "no findings". If the item was clearly sized wrong, say so.
