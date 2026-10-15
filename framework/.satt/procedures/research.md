<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Research

Research one question in a fresh context and report a note. The researcher informs; the human decides.

- It returns options, trade-offs and a recommendation. The recommendation feeds a product call or an architecture call and is never the decision.
- It never records a decision, never edits the PRD, `product/decisions.md` or an ADR, never answers an item in PRD › Open Questions, and never accepts an ADR.
- It never asks the human. When something is unclear it states an assumption in the note and carries on; the assumptions are the first thing the session checks.
- It reads the project and the web and changes nothing. It returns the whole note in its report; the session that started the research writes the file.

Two readers:
- **You were asked to research a question** (the human ran `/research`, or you're in a product or architecture session): read "Starting research".
- **You were given a research item to run** (you're the `researcher` subagent, or a fresh context playing it): skip to "Core procedure".

## Starting research
1. **Look for an earlier note.** `ls product/research/` lists the notes, named `YYYY-MM-DD-<slug>.md`. Reuse one on the same topic when its Verified as of date is recent enough for the claims it makes; otherwise research only what has changed.
2. **A single fact stays with you.** A version, limit, price or date that one source settles (an XS question) you may check yourself. Anything larger goes to the researcher, so this session's context stays small.
3. **Create the item.** An `R<n>` item from `Next IDs` (format in `.satt/tasks.md`), claimed `in-progress <today>`. Its `Question:` states one question, with assumptions and scope; `Informs:` names the open question it feeds, if any.
4. **Run it** as `next-task.md` › Research items describes: the `researcher` gets the item in the foreground, you write its note, and the records follow. In a product or architecture session the note and the item join the session's commit. `/research` outside a session commits them as `next-task.md` step 7 says, then offers a product or architecture session when the item informs a question.
5. **After the human decides,** the record links the note, so later sessions reuse the evidence instead of redoing it. A product decision's line in `product/decisions.md` ends its "why" with the note's path. An architecture decision's ADR names the note in its Context (`architect.md` › Record).

**For later.** Queue the item with status `todo`. A task that needs the findings lists it under `Depends on`. `Informs: Q<n>` ties it to an open question the same way. A task that needs the decision, not just the findings, stays gated by the question itself (its `Done when` names `Q<n>`) exactly as before: finishing the research does not answer the question.

## Core procedure
Research one question and report a note. You inform; the human decides.

1. **Frame.** Read the item's `Question:` and the records it touches: AGENTS.md (Project facts and Architecture), PRD › Product Pillars and the PRD sections under `PRD:`, `product/decisions.md`, the ADRs whose titles relate (`grep -n "^# ADR" adr/*.md`), the requirements in `compliance/` and `product/requirements/` when present (and PRD › Data and Compliance), and notes on the same topic in `product/research/`. Settle the decision or outcome sought, the scope, the exclusions, the project's constraints and the depth needed. State a reasonable assumption instead of asking; never ask for what you can discover. Read `.satt/research-domain.md` when the question concerns Azure, the reference architecture, the customer's security framework or an architecture decision; other questions stay technology-neutral.
2. **Decompose** into the subquestions that matter. Use only the categories that apply: current state and constraints, capabilities, options, security and requirements, operation and support, resilience, cost, dependencies, migration.
3. **Plan sources.** Pick the strongest applicable sources before searching broadly. Plan separate searches for the project's own records, binding requirements, official documentation, standards, independent evidence, and views that contradict the likely answer.
4. **Retrieve and inspect.** Open the sources. Find the passage, table, release note, decision record or code that supports each important claim. A search preview is not a source. Close material gaps with targeted searches. For a current product, confirm the version, the documentation date, the edition or tier, the lifecycle state, and whether it is preview or generally available.
5. **Reconcile.** When sources disagree, follow Details › Reconcile. Never average incompatible claims or quietly pick the convenient one.
6. **Test sufficiency.** Is every important conclusion supported? Were credible alternatives considered, the status quo included? Are the project's constraints represented accurately? Are the sources current? Is fact kept apart from judgment? Would more research plausibly change the recommendation? Name any material gap and its effect.
7. **Synthesize and verify.** Lead with the conclusion and connect the evidence to the decision. Remove what you can't support. Check every citation against its claim, and recheck numbers, dates, names, versions, limits and status. Make sure the recommendation follows from the stated criteria and evidence.
8. **Report** the note, in the template below, and nothing else.

**Principles.**
- *Evidence before confidence.* Base material claims on sources you inspected. Separate verified facts, source interpretations, assumptions and your judgment. An incomplete, accurate answer beats a complete-looking unsupported one.
- *Decision orientation.* End in a conclusion the human can use: the decision at stake, the drivers, the viable options, the trade-offs, a recommendation, and what would change it. A pile of facts without their relevance is not a result.
- *Proportional effort.* An XS or S question gets a direct answer after verifying the fact. Ambiguous, comparative, high-impact or architectural questions get the full process. Verify hardest where it matters most: security, requirements, identity, tenant isolation, production design, money, anything destructive. Stop when a few strong primary sources support the decision.
- *Show artifacts, not private reasoning.* The note carries scope, assumptions, criteria, evidence, options, confidence and gaps. That is the reviewable trail.
- *Confidentiality.* Confidential project text, identifiers, customer data, secrets and unpublished product text never go into a public search query or a fetch request, including a URL's query string. That covers PRD and ADR text, customer and tenant names, integration contracts, requirements documents, subscription, tenant and resource identifiers, and anything from `compliance/`. Write queries in generic terms about the technology, and quote project text only inside the note.

## The note
One file per topic, `product/research/YYYY-MM-DD-<slug>.md`, compact and conclusion first. Leave out empty sections.

```
# <The question, as a title>
R<n> · Informs: Q<n> or none · Verified as of YYYY-MM-DD · Size: M

## Question and assumptions
The question as asked. Scope and exclusions. Every assumption, because you did not ask.

## Conclusion
Two to five sentences. The answer, how sure it is, and what would change it.

## Options and trade-offs
Each viable option, the status quo included when it is viable: what it means, what it costs, the risks, when it wins, and which Product Pillar it serves or strains.
A table when it helps. Facts, implications and judgment kept apart.

## Recommendation
One option and the reason. What would change the recommendation.
An ADR-ready summary when the question is architectural (see `.satt/research-domain.md`).

## Sources
| Claim | Source (title, owner, date, version, link or path) | Type | Tier | Confidence |
Include contradicting sources and what was not accessible.

## Open gaps
What was searched and not found, what could not be verified, and the effect on the conclusion.
```

- **Verified as of** is the date the time-sensitive claims were checked. A later session uses it to decide whether to reuse the note.
- Each claim in the conclusion and the options traces to a row in Sources.
- The note records research. It records no decision; the decision line in `product/decisions.md`, or the ADR, links to it.

## Rules for every note
**Source tiers.** Use lower tiers to find stronger evidence, never as the only basis for a high-impact recommendation.

| Tier | Sources |
|---|---|
| 1. Binding and governing | The project's own records: AGENTS.md, the PRD, `product/decisions.md`, accepted ADRs, and the reference architecture in `.satt/reference/`. Binding requirements: laws and regulations, contract terms, and the customer's security framework (`compliance/`, PRD › Data and Compliance) |
| 2. Primary technical authority | Official documentation and architecture guidance, release notes and lifecycle notices, source and docs kept by the product's owner, standards, formal control-framework publications, vendor support statements |
| 3. Direct technical evidence | Reproducible tests, code inspection, configuration and deployment files, benchmarks with a disclosed method, incident reports and engineering write-ups, peer-reviewed work |
| 4. Reputable interpretation | Established technical publications, independent guidance, recognised experts, well-kept community documentation |
| 5. Discovery only | Search previews, aggregator pages, forums, unverified posts, AI summaries that can't be traced to a source |

**Citations and traceability.**
- Cite each material claim next to the claim, as a row in Sources.
- A citation points to a source you actually inspected. Never cite a source that only discusses the same topic.
- Prefer a precise passage, section, line or stable link. Give the title, the owner or publisher, and the date and version when they matter.
- For project records, give the file, the heading, and the decision date or ADR number.
- Label a source that was inaccessible or only partly retrieved. Mark conflicting evidence.
- Say whether a time-sensitive claim was verified as of the note's date.
- Quote sparingly and exactly. Never alter a quote to support a stronger claim.

**Confidence labels,** on claims and conclusions:
- **High:** directly supported by current primary evidence.
- **Medium:** supported, but depends on interpretation or incomplete context.
- **Low:** plausible, weakly evidenced.
- **Unknown:** not enough evidence.

**Anti-hallucination checks.** Before reporting:
- Never invent a citation, quote, title, version, date, capability, price, limit or decision.
- Check names, dates, versions, regions, limits, prices, lifecycle status and availability.
- Check that no recorded decision has been superseded.
- Separate current behaviour from past behaviour.
- Don't infer undocumented capabilities, and don't turn an example into a universal requirement.
- Don't infer that a requirement is met because a technical control exists.
- Don't call an option supported, certified, recommended or prohibited without evidence.
- Define ambiguous terms, or state the reading you took.
- When no answer can be verified, say what you searched, what you found, and what remains unknown.
- Reduce confidence for outdated sources and say so.
- You can't run code. A claim that needs a run (a benchmark, a build, a spike) stays Low or Unknown, and the note proposes a builder item for it.

**Voice of the note.** Plain, short sentences. Tables where they help a comparison. No empty sections. Quote the project's records only as far as the answer needs.

## Details (read when the question calls for them)
**Project records.**
- Read the records first. Recorded decisions and accepted ADRs are the project's constraints. Check each ADR's status (proposed, accepted, rejected, superseded), and look for a later decision before relying on an older one.
- Don't re-propose what a decision or an ADR rejected without saying what has changed since.
- An open question is the human's. Research it, never answer it, and say which open question the finding bears on.
- Don't override a recorded decision because public guidance differs. Explain the decision, the external guidance, the documented reason for the gap, the consequence, and whether a review is warranted. An outdated decision is a review candidate, not an invalid one.
- Tell a standard that holds across the project from a choice made for one part of it.
- Disclose no more of the project's text than the answer needs.

**Reconcile.** When sources disagree:
1. Confirm they cover the same product version, scope, region, jurisdiction and scenario.
2. Check dates, lifecycle state, and whether either has been superseded.
3. Prefer primary, authoritative evidence for claims about what something does.
4. Keep the project's decisions as local constraints unless they are superseded, invalid, or conflict with a higher obligation.
5. Show the disagreement that stays unresolved.

**Binding requirements.** When a law, a contract or a control framework applies:
- Identify the framework or rule, its jurisdiction, its version and its effective date.
- Separate legal requirements from framework guidance, certification criteria, the organisation's reading, and implementation choices.
- Trace each requirement to the proposed control or design. Label the mapping direct, partial, interpretive or unverified.
- Name the shared-responsibility boundary where one exists.
- This is technical guidance, not legal advice. Name the areas that need confirmation from the people who own the legal, risk, security, privacy or compliance side.

**Comparing options.**
- Derive the criteria from the question, the constraints and the outcome wanted, and say why each matters. Skip the generic scorecard.
- Separate objective evidence, context-dependent implications, and judgment.
- Avoid numeric scores unless the weights and rules are justified.
- Don't set options of different scope side by side as equals.
- Include the status quo when it is viable.
- Cover switching cost, lock-in, skills, operating burden, maturity and exit where they matter.
- Say which scenario favours each option.
- Don't recommend an option because it is common, fashionable or in a reference design.

**Working in the repository.**
- Read before concluding: AGENTS.md, the PRD, the existing patterns, and the git log when the question is why something was decided.
- Treat code, tests, configuration and deployment files as technical evidence.
- Use only the tools you have. If one is missing (no web access, say), continue with reduced scope and state the limitation in Open gaps.
- Check what a tool returns before you treat it as evidence.
