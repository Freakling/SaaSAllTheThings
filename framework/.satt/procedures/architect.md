<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Architecture session

Settle a choice the reference architecture leaves open, or handle a request to deviate from it, and record the result as an ADR. The reference (`.satt/reference/`) has authority: it holds unless the human accepts an ADR that says otherwise. You propose; the human decides; the ADR is the only record.

Comes from: a build reporting `blocked: architecture`, a review finding, a "Decide:" item, onboarding (the stack), or the human asking ("can we use SQL?", "which UI tech for Windows?").

## Prepare
1. Read the reference topic and heading in question, and every ADR whose title is related (`grep -n "^# ADR" adr/*.md`). Don't re-propose something an ADR rejected without saying what has changed since.
2. Read any requirements documents that bear on this decision:
   - **Product requirements** (user stories, feature specs): files in `product/requirements/` if present.
   - **Security and compliance requirements**: files in `compliance/` if present; also the PRD › Data and Compliance section.
   Note any constraint or acceptance criterion an option must satisfy, and flag any conflict between a requirement and the reference architecture.
3. Classify it:
   - **An open choice:** the reference lists it in `reference/README.md` › Choices left open. Every option is within the architecture.
   - **A deviation:** an option would break a reference rule. Option 1 is then always "comply", with what that would take.
   - **A framework gap:** the reference is wrong or missing something for every project, not just this one. Say so; the human can take it to SaaSAllTheThings upstream. Until then it's handled here as a deviation.
   - **A requirements conflict:** the architecture-compliant option violates a stated requirement, or a requirement forces a deviation. Surface the conflict; the human resolves it.

## Propose
1. Offer 2–4 options. For each: what it means for the code and the layers, effort (S, M or L as in `tasks.md` › Size, or a range of person-days for anything bigger), monthly Azure cost (`reference/cost.md`), risk, security and compliance impact, and how hard it is to undo.
2. Apply industry best practices as a standing check on every option — not just the reference architecture, but: OWASP Top 10, principle of least privilege, defence in depth, zero trust (verify explicitly, use least privilege, assume breach), data minimisation, and any standard named in the compliance requirements (ISO 27001, SOC 2, GDPR, …). Flag any option that conflicts with a relevant practice; note which option strengthens the security or compliance posture.
3. Recommend one, with a one-line reason. Prefer complying; prefer the reversible option; prefer the option with the stronger security posture when effort is similar.
4. Wait for the human.

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

Once the commit lands, tell the human to start the next topic in a fresh session — in Claude Code: `/clear`. The ADR, AGENTS.md and TASKS.md hold everything the next session needs; the conversation history is noise.
