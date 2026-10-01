# Product decisions

Why the product is the way it is: one line per decision, newest last, never edited. The PRD states the current requirements; this file says how they got there. A decision that replaces an earlier one says so. Architecture decisions are ADRs in `adr/`, not lines here.

Format: `- YYYY-MM-DD · <decision> · why: <reason> · from: <Q<n> | conversation | validation file>`

- 2026-09-28 · Navision owns customers and items; Order Desk owns orders until Navision posts them · why: pillar "Navision stays the books" · from: conversation
- 2026-09-28 · The first client is Windows for sales; mobile for the warehouse comes after · why: the pilot's counter is the bottleneck · from: conversation
- 2026-09-29 · An order needs a customer and at least one line; prices can't be negative · why: Navision rejects such sales orders anyway · from: conversation
- 2026-09-30 · Customer numbers are stored in capitals, as Navision does · why: c0001 and C0001 are one customer in Navision · from: validation/2026-09-30-acceptance.md
