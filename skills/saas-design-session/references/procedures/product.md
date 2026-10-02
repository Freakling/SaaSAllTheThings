<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Product session

Work out a capability, rank and answer open product questions, or change how part of the product works. Write down only what the human decides. Your job is to make the human's decisions fast and well informed, never to make them.

A question about how the system is built (a data store, a client's UI tech, a deviation from the reference) isn't a product call: hand it to `architect.md`.

## Prepare
- Read PRD › Product Pillars, PRD › Open Questions, the PRD sections the topic touches, and the related lines in `product/decisions.md`. Don't re-propose something decided against there without saying what has changed since.
- **Ranking the open questions** (no topic, or "which questions block development?"): order them by what they unblock in TASKS.md:
  1. a question blocking a ready item;
  2. one that would cause rework (a contract, a stored schema, who owns which data in an integration);
  3. one that gates a `PLACEHOLDER` value;
  4. long-term questions.

  Give a one-line reason for each position.

## For each question
1. Offer 2–4 concrete options. For each: what the user or customer experiences, what it would take to build (which systems in AGENTS.md › Architecture, which clients), what it costs to run, and which pillar it serves or strains.
2. Recommend one, with a one-line reason.
3. Wait for the human. If they answer only part, record only that part. If you had to interpret the answer, write down your reading and ask them to confirm it.

## Record each decision in one change
1. **PRD:** write the rule into its section as the current requirement, replacing any text it supersedes. A new capability gets a new `###` under Capabilities.
2. **`product/decisions.md`:** append one line in the format given at the top of that file.
3. **PRD › Open Questions:** delete the answered question. Follow-up questions become new `Q<n>` (bump `Next`).
4. **Integration contracts:** a decision about an external system's data (who owns a field, a conflict rule) also goes into its `integrations/<system>/contract.md`.
5. **TASKS.md:** add or change the items the decision creates, in the format in `.satt/tasks.md`, as small slices.
   - Give each new item a Size, `Depends on`, `Touches`, `Done when` with tags, and a `PRD:` heading.
   - A `done` item the decision changes gets a new item; don't reopen it.
   - Leave `in-progress` items alone and tell the human about them, since another session may be working on them.
   - Suggest reorders; don't make them.
6. **Numbers** (limits, quotas, prices, timeouts) stay `PLACEHOLDER` values until the human gives them. Say what a value is for and how it should feel.
7. **Pillars:** if an idea contradicts a Product Pillar, stop and ask which gives way, the pillar or the idea.

## Finish
- Summarise what was decided, what's still open, and the next most useful question.
- Commit the product files as `docs: <summary>`, with a body listing the decisions, after the human approves (see `rules.md` › Git and Azure). A product session doesn't edit code.
