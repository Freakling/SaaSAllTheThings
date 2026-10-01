# Acceptance check 2026-09-30
**Build:** 4f2a9c1 · **Environment:** local · **Covers:** T3
**Processed:** 2026-09-30 → B1
Tick one box per item; leave both empty if you didn't check it. Say what went wrong in Notes.

## Capabilities › Place an order
- **T3** Posting an order to `POST /api/v1/orders` answers 201 with the order and its total. *How:* run the Functions host locally, post two lines.
  - [x] Works   - [ ] Broken / missing
  - Notes: works. But posting customer `c0001` stored it in lower case, and Navision says that's C0001.
