# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.satt/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`. The stages are explained in `.satt/procedures/roadmap.md`.

**Next IDs:** T2 · B1

## Milestones
| Stage | Status |
|---|---|
| 0 · Extract (existing apps only) | ⬜ |
| 1 · Foundation: layered skeleton, check passing, first rule with a test | ⬜ |
| 2 · Tenancy and identity | ⬜ |
| 3 · First slice, end to end | ⬜ |
| 4 · Delivery: Bicep, CI, dev environment, budget | ⬜ |
| 5 · Clients: Windows and mobile | ⬜ |
| 6 · Integrations | ⬜ |
| 7 · Second tenant | ⬜ |
| 8 · Capabilities | ⬜ |

✅ done · 🟨 in progress · ⬜ not started

## Queue

### T1 · The check passes on a clean clone · todo · S · agent
- Depends on: —
- Touches: tools/check.cfg
- Done when: `bash tools/check.sh` exits 0 after a fresh clone and `bash tools/setup-clone.sh` (check)
- PRD: —

## Notes
<!-- Short and current: ordering constraints, items that share files, what's waiting on the human. Delete a note once it stops being true. -->
