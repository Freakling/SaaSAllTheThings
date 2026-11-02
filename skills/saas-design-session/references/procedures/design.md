<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Product session

Work out a capability, rank and answer open product questions, change how part of the product works, validate the user stories (Validate the stories, below), or harvest a prototype (Harvest a prototype, below). Write down only what the human decides. Your job is to make the human's decisions fast and well informed, never to make them.

A question about how the system is built (a data store, a client's UI tech, a deviation from the reference) isn't a product call: hand it to `architect.md`.

## Prepare
- Read PRD › Product Pillars, PRD › Open Questions, the PRD sections the topic touches, and the related lines in `product/decisions.md`. Don't re-propose something decided against there without saying what has changed since.
- Read the stories in `product/user-stories.md` for the roles and areas the topic touches (`grep -n "^## " product/user-stories.md` lists the areas).
- List `product/research/` for notes on the topic. A note whose Verified as of date is recent enough for its claims is evidence you can use; research only what has changed since.
- **Ranking the open questions** (no topic, or "which questions block development?"): order them by what they unblock in TASKS.md:
  1. a question blocking a ready item;
  2. one that would cause rework (a contract, a stored schema, who owns which data in an integration);
  3. one that gates a `PLACEHOLDER` value;
  4. long-term questions.

  Give a one-line reason for each position.

## For each question
1. **Surface the relevant context.** Quote or summarise what's already decided that bears on this question: the applicable Product Pillars, the current PRD rule on this topic (if any), the stories it touches by ID and text, and any related line from `product/decisions.md`. If nothing yet exists, say so in one sentence. Add the research on file for the topic (path, conclusion and Verified as of date), if there is any. This lets the human see the full picture before choosing.
2. **Research first when the options depend on facts you don't have,** or when the human asks for it, such as what a market usually expects, what a service costs, or what a customer's requirements ask for.
   - A single fact one source settles (a version, a limit, a price) you may check yourself. Anything larger goes to the `researcher`, as `research.md` › Starting research describes, so this session's context stays small.
   - The result is a note in `product/research/` and a done `R<n>` item. Tell the human where the researcher's assumptions are, since those are the first thing to check.
   - The researcher's recommendation is one option, shown with its reason like any other. It informs; the human decides.
3. Offer 2-4 concrete options. For each: what the user or customer experiences, what it would take to build (which systems in AGENTS.md › Architecture, which clients), what it costs to run, and which pillar it serves or strains. Name the stories it serves, and draft the new or changed stories it needs (User stories, below), so the human confirms them with the option.
4. Recommend one, with a one-line reason.
5. Wait for the human. If they answer only part, record only that part. If you had to interpret the answer, write down your reading and ask them to confirm it.

## Record each decision in one change
1. **PRD:** write the rule into its section as the current requirement, replacing any text it supersedes. A new capability gets a new `###` under Capabilities.
2. **`product/decisions.md`:** append one line in the format given at the top of that file. When the decision followed research, end the `why` with the note's path, as in `why: <reason> (research: product/research/<note>.md)`, so later sessions reuse the evidence instead of redoing it.
3. **PRD › Open Questions:** delete the answered question. Follow-up questions become new `Q<n>` (bump `Next`).
4. **Integration contracts:** a decision about an external system's data (who owns a field, a conflict rule) also goes into its `integrations/<system>/contract.md`.
5. **`product/user-stories.md`:** the chosen option's stories. Each one the human confirmed is dated today: a new one gets the next ID from the header (then bump it), a changed one is rewritten in place, and a dropped one is deleted. A drafted story they didn't answer goes in as `unconfirmed`. The capability's subsection in the PRD names the stories it serves (`Stories: US-1, US-3`).
6. **TASKS.md:** add or change the items the decision creates, in the format in `.satt/tasks.md`, as small slices.
   - Give each new item a Size, `Depends on`, `Touches`, `Done when` with tags, a `PRD:` heading and its `Stories:`.
   - A `done` item the decision changes gets a new item; don't reopen it.
   - Leave `in-progress` items alone and tell the human about them, since another session may be working on them.
   - Suggest reorders; don't make them.
7. **Numbers** (limits, quotas, prices, timeouts) stay `PLACEHOLDER` values until the human gives them. Say what a value is for and how it should feel.
8. **Layout:** where things sit on a screen goes to `ui-design.md`. A product session settles what a screen is for, not where its elements are.
9. **Pillars:** if an idea contradicts a Product Pillar, stop and ask which gives way, the pillar or the idea.

## Finish
- Summarise what was decided, what's still open, and the next most useful question.
- Commit the product files as `docs: <summary>`, with a body listing the decisions, after the human approves (see `rules.md` › Git and Azure). The session's research notes and `R<n>` items go in the same commit. A product session doesn't edit code.
- Once the commit lands, tell the human to start the next topic in a fresh session, in Claude Code: `/clear`. The PRD, `decisions.md`, the stories and TASKS.md hold everything; the conversation history has no remaining value and only grows the context window.

## User stories
`product/user-stories.md` says which roles the product serves, and why each feature is built: the value for each role in one paragraph, the roles, and one table of stories per area, each with its ID, the story and the date the human confirmed it. You draft stories; only the human confirms them.
- **A story** is one thing a role does and why, in the role's words: "As a <role> I <do something>, so <why>". It names no screen, technology or implementation. Its role is a persona in PRD › Personas and Roles, by the same name, and is listed under the file's Roles; a new role is added to the PRD first (a product decision), then to Roles, with its value paragraph.
- **New and changed stories** come from a product session (For each question), a workshop (its notes' User stories, recorded by `assess.md` › Process workshop notes), onboarding (from the interview, the code or an assessment report's User stories), or a feature item that has none. A new one gets the next ID from the file's header, which you then bump; IDs are never reused. Until the human confirms it, its Confirmed column says `unconfirmed`.
- **A feature item with no story** (no `Stories:` line, or `none` while it changes what a user can do): draft the story it serves, add it `unconfirmed`, and set the item's `Stories:`. Name it in your report so the human can confirm it; a run of several items doesn't stop for it.
- **Confirmed** is the date the human last confirmed the story as it reads now: in a product session, a workshop, a validation or an acceptance check (`acceptance.md`).

### Validate the stories
`next-task.md` proposes this when `bash tools/stories.sh --due` says it's due: never validated, or `tools/check.cfg` › `[stories] every` built items (10 by default) since the commit on the file's Last validated line. It also runs on request.
1. **Collect.** The stories the items built since that commit serve: `git log --format=%s <commit>..HEAD` lists the items (subjects ending in `(T<n>)` or `(B<n>)`, or that and a squash merge's ` (#<pr>)`), and their `Stories:` lines name the stories. When the commit isn't in this history, or the line names none, use `git log --format=%s --since=<date>` instead. Add every story still `unconfirmed`. With Last validated `never`, take every story.
2. **Ask.** Show each story with the items and capabilities that serve it, grouped by area, and ask the human to confirm, correct or drop it:
   - **confirm:** its Confirmed becomes today's date;
   - **correct:** write the new wording and date it. If you had to interpret the answer, show your reading and keep it `unconfirmed` until they confirm it. A correction that means the built behaviour is wrong is a product question: offer options as For each question says, or add an Open Question;
   - **drop:** delete its row, and its ID from the capabilities that name it. A `todo` item that names it goes to the human, who decides whether it's still needed.

   A story the human doesn't answer stays as it is; an unconfirmed one comes back next time.
3. **Record.** Set the header's Last validated to today and `git rev-parse --short HEAD`, as in ``**Last validated:** 2026-11-14 at `4e1f0c2` ``. Commit `product/user-stories.md` (and the PRD, items or Open Questions it changed) as `docs: validate the user stories`, after the human approves.

## Harvest a prototype
`prototype.md` › Harvest brings a prototype here: its notes (`PROTOTYPE.md`: what was tried, how it felt, what to keep) and its diff against main. It shows how a change feels; it decides nothing, and its code is never merged or cherry-picked.
1. **Context.** Show the notes in the human's words, then what the prototype changes as a user or customer would see it, area by area from the diff rather than the code, with the PRD sections, stories and decisions it touches, as Prepare says. Name what it skipped that a real build needs: tests, tenant isolation, the layers in `reference/layers.md` and the rest of the reference architecture (the check wasn't run on it), and anything the OWASP baseline asks.
2. **Architecture.** List each place the diff goes against the reference architecture: a layer crossed, the tenant taken from the request, a data store or a client's UI tech the reference doesn't name, a secret. None of these is a product call. Each goes to `architect.md`, with "comply" first, and ends in an ADR that only the human accepts; until then the real build complies with the reference, whatever the prototype did.
3. **Options,** as For each question says. They are usually to build it as tried, a variant the notes point to, or to leave it, and each says what it would take to build from main, within the reference.
4. **Record** what the human chooses, as Record each decision in one change says (the capability in the PRD, `decisions.md`, Open Questions, `product/user-stories.md` and TASKS.md), naming the prototype in each: the decision's `why` ends with `(prototype: proto/<name>)`; a story it adds or changes gets the line `US-<n> came from the prototype proto/<name> on <date>.` under its area's table; and each item gets `- Prototype: proto/<name>` (`.satt/tasks.md`). The items are built from main like any other, with the check and reviews. Nothing is filed without the human's answer: a part they don't answer stays out, and leaving the prototype files nothing. Unlike Record step 5, a drafted story the human doesn't answer stays out too. Commit as Finish says, as `docs: harvest the <name> prototype`.
