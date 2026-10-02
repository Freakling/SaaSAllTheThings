<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Assess

Analyse an existing app and recommend what it takes to turn it into a SaaS on the reference architecture: how ready it is, the development roadmap by stage with rough effort, and the workshops that must happen, with how to run each. It's for deciding whether and how to start, before or alongside onboarding.

**Read only.** You change nothing in the app except writing the report. Don't build, run, install or test anything unless the human agrees: builds and tests can reach databases and networks.

**Paths.** In an app with SaaSAllTheThings installed, the framework's files are in `.satt/`, and the check in `tools/`. Before installation (the `saas-assessment` skill), they're in `$SATT/framework/.satt/` and `$SATT/framework/tools/`. Below, `.satt/` means whichever applies.

You recommend; the human decides. Every choice in the report is options with a recommendation, never a decision made for them.

## 1. Frame it
Ask the human, as multiple-choice questions where the tool supports them:
1. **Who it's for:** internal planning, or a proposal to a customer. A proposal gets a more careful tone, and effort ranges only if the human wants them.
2. **What's known already:** the goal, a deadline, the team, the first customer, the systems to integrate, constraints (budget, compliance, the customer's Azure governance). Anything unknown becomes an open question in the report, never a guess.
3. **Language and place:** the report's language (English by default), and where to write it: `assessment/YYYY-MM-DD-assessment.md` in the app by default, untracked until the human commits it.

## 2. Scan
Collect evidence (`file:line`, counts, commands you ran), not impressions. In a large repository, scan the areas in parallel subagents where the tool has them (in Claude Code, `Explore`) and keep only their summaries. Read project files and representative files; count the rest.
- **Shape:** languages and file counts by extension (`git ls-files`); solutions, projects and packages; size; history from `git log` (age, commits in the last 90 days, the number of contributors, counted without printing a name or email: `git log --format=%ae | sort -u | wc -l`).
- **Entry points:** desktop, web and mobile UIs; APIs; services; scheduled jobs; scripts.
- **Business rules:** where they live (UI code-behind, controllers, stored procedures, services, spreadsheets), and the areas with the most of them.
- **Data:** stores, schemas and how the code reaches them; whether anything identifies a customer (a tenant column, a database per customer, nothing).
- **Single-tenant habits:** customer names or ids in code or config, per-customer branches or builds, global state holding customer data, one connection string for everyone.
- **Identity:** how users sign in today, and where users and roles live.
- **Configuration and secrets:** search with the patterns in `tools/check.sh` › `secret_patterns` (`git grep -n -I -i -E --untracked -e … `). Report `file:line` only, never a value. A real secret in a repository is exposed: say it must be rotated.
- **Integrations:** calls to Navision or Business Central (OData, SOAP web services, `/api/v2.0/`), other ERPs, file drops, email, queues.
- **Clients:** which apps exist, for whom, and whether their screens hold business rules.
- **Tests and delivery:** test suites and their size, CI configuration, deployment scripts, environments.
- **Documents:** README, requirements, designs, runbooks.

## 3. The stack
Follow `.satt/reference/stacks.md` › Choosing the stack: tell the human the languages and frameworks you found, and ask whether they have a preference. If the current stack is compatible, offer to keep it first; if not, say why, list the compatible stacks with a recommendation, or ask for their preferred language. Their answer decides whether the roadmap reuses or converts. If the human would rather leave it open, the report presents it as a decision for the architecture workshop.

## 4. Assess
1. **Readiness.** Score each dimension from 0 to 3, with the evidence and what it takes:
   - 0: absent, or blocks the move;
   - 1: present, but must be rebuilt;
   - 2: reusable with changes;
   - 3: already fits the reference.

   Dimensions: stack, separation of business rules, data and tenant-awareness, identity, configuration and secrets, integrations, clients, tests, delivery and operations.
2. **Target picture.** Map each existing component onto its target layer (`.satt/reference/layers.md`), with one of: **keep** (moves as it is), **extract** (its rules move into domain and application), **rebuild**, **retire**. Name what the reference adds that the app doesn't have: the tenant registry, token validation, the outbox, the integration adapters.
3. **Roadmap.** Use the stages in `.satt/procedures/roadmap.md` › Stages. For each, say what this app needs, the main items with their size (S, M, L), a rough effort range in person-days with a confidence (low, medium, high) and its assumptions, what it depends on, and the workshop that must happen first. Estimates are for planning, never commitments; say what would narrow each one.
4. **First slice.** Recommend the capability for stage 3: valuable, small, touching the riskiest parts (tenancy, the main integration) early.
5. **Risks and assumptions,** each with what would reduce it.

## 5. Workshops
Read `.satt/workshops/README.md`, then the files of the workshops this app needs: usually all of them, combined into fewer sessions for a small app (README › Sizing). For each one in the report:
- why this app needs it, from the scan;
- the participants by role, including the ones the scan points to (a Navision consultant, because the app calls its web services);
- the decisions and open questions for this app, taken from steps 2–4;
- the preparation and pre-reads;
- the agenda and methods from its workshop file, adapted to the app;
- the records its outcomes go to, and the stage it unblocks.

Put them in order, and say which can run in parallel.

## 6. Write the report
Fill `.satt/templates/assessment.md`. The report is self-contained, because it goes to people without the framework: workshop agendas are written out, not linked. No secrets, no personal names; roles only.

## 7. Finish
- Summarise in a few lines: the verdict, the top risks, the first workshop.
- Offer the next step: prepare the first workshop's invitation and pre-read, or install SaaSAllTheThings (onboarding reads the report and the workshop notes instead of asking again).
- Don't commit. In an app with SaaSAllTheThings installed, commit the report as `docs: assessment YYYY-MM-DD` after the human approves.

## Process workshop notes
When the human gives you the notes of a workshop (a file in `assessment/workshops/`; names and format in `.satt/workshops/README.md` › Notes):
- **SaaSAllTheThings installed:** record each decision with `product.md` › Record each decision, `architect.md` (an ADR) or `integrate.md` (the contract), as it fits. An ADR draft in the notes becomes an ADR through `architect.md` › Record: it gets the next number, and stays proposed until the human accepts it. Open questions go to PRD › Open Questions, actions to TASKS.md as `human` items. Record only what the notes say was decided; if one reads as a leaning rather than a decision, ask. Under the notes' header, add `**Processed:** YYYY-MM-DD → Q4, ADR-2, T12`. Commit as `docs: process workshop <name>` after the human approves.
- **Not installed yet:** leave the notes where they are; onboarding reads them (`ONBOARDING.md` › Content, by mode).
