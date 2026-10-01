<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Architecture session

Settle a choice the reference architecture leaves open, or handle a request to deviate from it, and record the result as an ADR. The reference (`.satt/reference/`) has authority: it holds unless the human accepts an ADR that says otherwise. You propose; the human decides; the ADR is the only record.

Comes from: a build reporting `blocked: architecture`, a review finding, a "Decide:" item, onboarding (the stack), or the human asking ("can we use SQL?", "which UI tech for Windows?").

## Prepare
1. Read the reference topic and heading in question, and every ADR whose title is related (`grep -n "^# ADR" adr/*.md`). Don't re-propose something an ADR rejected without saying what has changed since.
2. Classify it:
   - **An open choice:** the reference lists it in `reference/README.md` › Choices left open. Every option is within the architecture.
   - **A deviation:** an option would break a reference rule. Option 1 is then always "comply", with what that would take.
   - **A framework gap:** the reference is wrong or missing something for every project, not just this one. Say so; the human can take it to SaaSAllTheThings upstream. Until then it's handled here as a deviation.

## Propose
1. Offer 2–4 options. For each: what it means for the code and the layers, effort, monthly Azure cost (`reference/cost.md`), risk, and how hard it is to undo.
2. Recommend one, with a one-line reason. Prefer complying; prefer the reversible option.
3. Wait for the human.

## Record
1. **Write the ADR** from `.satt/templates/adr.md` as `adr/ADR-<n>-<slug>.md`, where `n` is one more than the highest existing number. `Status: proposed` until the human has said in this conversation that they accept it; then set `Status: accepted` (in Claude Code a hook asks them to confirm).
2. **A deviation the check would fail** gets one `- Exception: <rule> <path pattern>` line per rule, as narrow as possible: the folder or file that deviates, never `**`. Exceptions apply only while the ADR is accepted.
3. **A temporary deviation** gets a TASKS.md item that removes it, named in the ADR's Consequences.
4. **Superseding:** a new ADR that replaces an old one says `Supersedes: ADR-<n>`, and the old one's status becomes `superseded by ADR-<m>`. Never edit an accepted ADR's decision.
5. **TASKS.md:** the items the decision creates, with `ADR: ADR-<n>`. A "Decide:" item it answers becomes `done`.
6. **AGENTS.md:** a decision that changes Layout or Project facts (the stack, a client's UI tech) is reflected there in the same change.
7. **Rejected:** if the human chooses to comply, either write no ADR (for a deviation that was only asked about) or record it with `Status: rejected` when the question is likely to come back.

## Finish
Run `bash tools/check.sh --architecture` to confirm the exceptions match what they should. Commit the ADR and the records as `docs: ADR-<n> <title>` after the human approves.
