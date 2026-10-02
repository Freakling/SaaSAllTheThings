!["All the things" meme: an excited cartoon figure raises a fist against a yellow burst, captioned "SaaS ALL THE THINGS"](https://raw.githubusercontent.com/Freakling/SaaSAllTheThings/assets/saas-all-the-things.png)

# SaaSAllTheThings

**Build a B2B SaaS from scratch, or turn a working proof of concept or an existing app into a mature, modern SaaS, with an AI assistant doing the building.**

Two starting points, one destination: a multi-tenant product that business customers sign in to with their own identity provider, on plans you define, connected to the systems they already run, on an event-driven Azure backend that stays cheap while it's small and grows with use.

- **From scratch:** a short product interview, then the platform is built in small, proven steps, starting with tenancy and sign-in rather than bolting them on later.
- **From a proof of concept or an existing app:** an assessment first (readiness, roadmap, the workshops to hold), then the app is moved over area by area, behind tests, while it keeps working.

You own the product: what it does, for whom, and in what order. The framework owns the architecture and enforces it: an event-driven Azure Functions backend, separate Windows and mobile clients, OIDC sign-in with federated identity, pooled multi-tenancy that can move a customer to its own deployment later, and enterprise integrations starting with Navision (Dynamics NAV / Business Central). The AI builds within that architecture, tests and keeps the records. Built for Claude Code, and usable with any AI coding assistant that reads `AGENTS.md`. Everything lives in your app's own git repository.

In your app it's `.satt/` for short (SaaS All The Things), and the setup command is `/saasallthethings:saas-all-the-things`.

## Why

AI writes backend code fast. Without structure, that speed goes wrong in familiar ways:

- **The architecture erodes.** One handler reads the tenant from a header, another calls the database from a client, a third stores a connection string. With SaaSAllTheThings the reference architecture is framework-owned and machine-checked. The only way to deviate is an ADR that you accept, and the check accepts an exception only when an accepted ADR names it.
- **The product drifts.** The AI quietly decides a business rule you never agreed to. Product calls come to you as 2–4 options with a recommendation. Only your choice is written down, and anything undecided goes on an open-questions list instead of being guessed.
- **"Done" means "it compiled".** One check defines "works": the architecture rules hold, the build passes and the tests pass. It runs before every commit that touches code, and in Claude Code also before the AI ends its turn.
- **Single-tenant habits stay.** Tenant-specific `if`s, a tenant id taken from the request, a cloud bill that grows with every customer. The check fails on the first two, and cost defaults (serverless, consumption) cover the third.
- **Context gets lost between sessions.** A few plain files hold everything: the product document, a decision log, ADRs, integration contracts, the task queue and an architecture table. Each fact has one home, so any session picks up where the last one stopped.

## Three tenets
- **Low cost.** In tokens: a small always-loaded core, procedures and reference topics loaded only when used, builds in a fresh context. In Azure: Flex Consumption Functions, serverless Cosmos DB, one Service Bus namespace, log caps and budgets. Anything bigger needs an ADR.
- **Small iterations.** One item, one commit. Items are sized S, M or L, and L items are split. Vertical slices that work end to end beat layers built one at a time. Plans go at most one stage ahead.
- **Many files.** One type per file, one function per file, one handler per use case, one Bicep module per resource, one reference topic per file. The check fails source files over the size limits.

## How to use it

> You've read this far, so SaaSAllTheThings may be what you're looking for. It's free and open source, and if it helps you build your SaaS, a tip on Ko-fi or a sponsorship on GitHub helps me keep building it. I greatly appreciate your support.
>
> <a href='https://ko-fi.com/Q6J027VJG1' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi5.png?v=6' border='0' alt='Support me on Ko-fi' /></a> <a href='https://github.com/sponsors/Freakling' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://img.shields.io/badge/Sponsor_on_GitHub-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white' border='0' alt='Sponsor me on GitHub' /></a>

### Assess first (optional)

Not sure yet what it would take? The `saas-assessment` skill analyses an existing app without changing it, and writes a report: how ready the app is (scored, with evidence), the development roadmap by stage with rough effort, the decisions to make, and the workshops to hold, each with participants, preparation, a timed agenda and methods. It asks your stack preference first. Install the skill as below (it comes with the plugin, or `npx skills add Freakling/SaaSAllTheThings`), then ask "what does it take to make this app a SaaS?". The workshops' notes, and the report, feed onboarding later, so nothing is asked twice.

### Design sessions, anywhere

Architecture and product decisions, integration contracts and workshops don't need a terminal. The `saas-design-session` skill runs them in Claude Code, Cowork or the Claude apps (web, desktop, mobile), with or without your app's repository. It carries the reference architecture and the workshop playbook with it, so it argues from the same rules as everything else: options with a recommendation, complying with the reference first, you deciding.

Ask it things like "which data store should we use?", "what should Navision own?", "prepare the integration workshop" or "scribe this workshop". It prepares agendas and pre-reads, keeps time and records decisions during a workshop, and ends each session with notes, including ADR drafts for architecture decisions. Outside your repository you download the notes. Put them in your app's `assessment/workshops/`, and "process the workshop notes" in Claude Code turns them into records (or onboarding does, if SaaSAllTheThings isn't installed yet). In an app with SaaSAllTheThings installed, the skill writes the records itself, through the app's own procedures.

### Install

Your app needs git (`git init` if it has none) and no uncommitted changes. You also need bash (on Windows it comes with Git for Windows), and the toolchain of your backend stack: the .NET SDK 8+ for the default.

**Option 1: the Claude Code plugin.** In Claude Code:

```
/plugin marketplace add Freakling/SaaSAllTheThings
/plugin install saasallthethings@saasallthethings
```

Then open a new Claude Code session in your app's folder (or run `/reload-plugins`), and run `/saasallthethings:saas-all-the-things`.

**Option 2: manual install.** Put this repository in your app's root folder as a folder named `SaaSAllTheThings`: run `git clone https://github.com/Freakling/SaaSAllTheThings.git SaaSAllTheThings` there, or download the zip and rename the extracted folder. Then ask your assistant:

> Read SaaSAllTheThings/ONBOARDING.md and follow it to install SaaSAllTheThings into this project.

**Option 3: the skills CLI** (any assistant that reads skills):

```
npx skills add Freakling/SaaSAllTheThings
```

Then ask your assistant to "SaaS all the things" in your app's folder. The skill clones this repository's matching release into a temporary folder outside your app, and follows ONBOARDING.md from there.

Either way, onboarding works out whether this is a new app, an existing app or an upgrade. It then:
1. installs the files;
2. settles the backend stack with you: for an existing app it asks your preference, keeps your stack if it's compatible, and otherwise lists the compatible ones;
3. interviews you (new app) or reads the existing app, including its single-tenant habits and secrets;
4. writes the first stages of the roadmap to SaaS into `TASKS.md`;
5. ends with one commit for you to approve.

Afterwards, restart Claude Code so the new commands load. Each new clone of the app later needs one command: `bash tools/setup-clone.sh`.

**With another AI assistant:** tell onboarding, and it installs the tool-neutral core only (`--tools none`). Your assistant reads `AGENTS.md`, which points it to `.satt/rules.md` and the procedures. The check and the git hook work the same for every tool, and for you.

### Upgrade
- **Plugin:** run `/plugin marketplace update saasallthethings` and then `/plugin update saasallthethings@saasallthethings`. Start a new session in the app and run `/saasallthethings:saas-all-the-things` again.
- **Manual:** put the new SaaSAllTheThings folder in the app, and ask for ONBOARDING.md again.
- **Skills CLI:** run `npx skills add Freakling/SaaSAllTheThings` again, then ask for the upgrade.

Only the framework's own files are replaced, and your edits to them are kept. When a new version also changes a file you edited, the new version is written next to it as `<file>.satt-new` for you to merge.

### Day to day

| Say | What happens |
|---|---|
| "Do the next task" (`/next-task`) | Builds the next ready item (high-severity bugs first), proves it with the check, updates the records, and asks you to approve the commit. |
| "Do the next 3 tasks", "Work through the queue" | The same, item after item, until one needs you. |
| "Assess the app", "Which workshops do we need?" (`/assess`) | A read-only assessment report: readiness, the roadmap by stage with rough effort, and the workshops with their agendas. "Process the workshop notes" turns a session's decisions into records. |
| "Plan the next stage" (`/roadmap`) | Writes the next stage of the roadmap to SaaS as small items. |
| "Which open questions block development?" (`/product questions`) | Ranks the open product questions by what they unblock, with options and a recommendation for each. |
| "Let's work out {capability}" (`/product {topic}`) | A product session. Your decisions become PRD text, decision-log lines and task items. |
| "Which UI tech for the Windows client?", "Can we use SQL instead?" (`/architect`) | An architecture session: options with "comply" first, then an ADR that you accept. |
| "Add the Navision integration" (`/integrate navision`) | Works out the integration contract with you (direction, system of record, conflicts), then plans it in stages. |
| "Onboard tenant {customer}" (`/tenant`) | A readiness check and the human steps for a new customer: consent, plan, connections. |
| "Prepare an acceptance check", "Process it" (`/acceptance`) | A checklist of what's been built that needs a human eye in a running app; you tick Works or Broken. |
| "New feedback report", "Process this feedback" (`/feedback`) | Turns a customer or pilot session into bugs, score trends and product proposals. |
| "Release to dev" (`/release dev`) | Check, what-if, deploy and smoke test, each step with your approval. Production is yours to run. |
| "Check the docs are aligned" (`/align`) | A consistency pass. Drift gets fixed; gaps and conflicts come to you. |
| "Prune the task list" (`/prune`) | Moves done items to `TASKS-archive.md`. |

```
you, a customer or a pilot has an idea
        │
        ▼
product session ── options + a recommendation ── you decide ──► PRD + decisions.md + TASKS.md items
        │                                       architecture call? ──► /architect ──► ADR you accept
        ▼
next task ── builds the next ready item ── tests ── bash tools/check.sh ──► commit (you approve)
        │
        ▼
acceptance check (does each built rule work?)  ·  feedback (does it help the customer?)
        │
        ▼
bugs and product proposals ── you decide ── repeat
```

---

## What this is

### Who does what
| | Responsible for |
|---|---|
| **You** | The product: capabilities, UX, plans and pricing, priorities, customers, which system owns which data; accepting ADRs; approving commits and deploys. |
| **The framework** | The architecture: `.satt/reference/`, enforced by the check. It changes upstream in SaaSAllTheThings, or for one project through an ADR you accept. |
| **The AI assistant** | Code, tests, infrastructure as code, contracts, the records; proposing options and ADRs. |

### What gets installed in your app
```
your-app/
│  yours: never overwritten
├── AGENTS.md                   for every assistant: project facts, layout, architecture table, project rules
├── CLAUDE.md                   "@AGENTS.md", for Claude Code
├── TASKS.md                    milestones (the SaaSAllTheThings stages) and the queue (tasks and bugs)
├── product/prd.md              the product's current requirements, and Open Questions
├── product/decisions.md        why: one line per product decision
├── adr/                        architecture decision records: choices and accepted deviations
├── integrations/<system>/      one contract per external system (written by /integrate)
├── assessment/                 assessment reports and workshop notes (written by /assess)
├── validation/TEMPLATE.md      the feedback template, one section per capability
├── tools/check.cfg             the stack, the layers' folders, size limits
│
│  the framework's, tool-neutral: updated on upgrade
├── .satt/rules.md              the workflow rules, loaded through AGENTS.md
├── .satt/reference/            the reference architecture, one topic per file (the authority)
├── .satt/procedures/           next-task · build · assess · roadmap · product · architect · integrate ·
│                               tenant · acceptance · feedback · release · align · prune · review
├── .satt/templates/            ADR, integration contract and assessment templates
├── .satt/workshops/            the workshop playbook: one file per workshop, agendas and methods
├── .satt/tasks.md              the TASKS.md item format
├── tools/check.sh, archcheck.awk, cfg.sh, stacks/   the check, and one profile per backend stack
├── tools/setup-clone.sh        per clone: toolchain, dependencies, the pre-commit hook
├── .githooks/pre-commit        runs the check before commits that touch more than docs
├── validation/README.md        how acceptance checks and feedback reports work
│
│  the framework's, Claude Code adapter: updated on upgrade
├── .claude/skills/             /next-task and the rest: each points to its procedure
├── .claude/agents/             builder (builds each item in a fresh context) · reviewer (read-only)
├── .claude/hooks/              runs the check before a turn ends; blocks risky git and Azure commands;
│                               asks you before framework files change or an ADR is accepted
└── .claude/settings.json       permissions, hooks, timeouts
```
Machine-local and gitignored: `.satt/state/` (check logs and caches) and `.claude/settings.local.json`.

### The architecture, briefly
The full reference is in `.satt/reference/`, one topic per file; the assistant reads the topics an item touches.
- **Layers:** contracts, domain, application, infrastructure, integration, host, platform, client. Each may depend only on the ones `layers.md` lists. The domain is pure; hosts (the Azure Functions) are thin.
- **Event-driven:** commands on queues, events on topics (Service Bus), state and its events saved together through an outbox, idempotent consumers, versioned contracts.
- **Tenancy:** pooled. The tenant comes from the validated token, never from the request; every record and message carries it; tenants differ by registry data, never by code. A tenant can move to its own deployment later.
- **Identity:** OIDC with Entra ID (multi-tenant, so customers sign in with their own directory; External ID for those without one). Clients use auth code with PKCE. Managed identities and federated credentials everywhere: no secrets in code, config or apps.
- **Clients:** a Windows app and a mobile app, separate and thin. They depend on the contracts only; each one's UI tech is an ADR.
- **Integrations:** one anti-corruption layer and function app per external system, a contract you decide (direction, system of record, conflicts), no network calls in tests.
- **Cost:** serverless and consumption SKUs, log caps, a budget per environment.

### The rules, briefly
The full rules are in `.satt/rules.md`, and the assistant reads them every session.
- **You decide the product.** The assistant offers options and a recommendation, never answers an open question itself, and marks undecided values `PLACEHOLDER`.
- **The framework decides the architecture.** A build that can't comply stops and asks; deviations are ADRs you accept.
- **Each fact lives in one place,** and is updated in the same change that makes it untrue.
- **Done means the check passes,** and the work is committed only with your approval.
- **Guarded commands:** in Claude Code, force-push, `reset --hard`, `--no-verify`, deleting Azure resources, reading Key Vault secrets and creating client secrets are blocked by a hook. Deploys and cloud changes ask you first.

### The check
`bash tools/check.sh` runs four steps:
1. the architecture rules (`tools/archcheck.awk`): layers, a pure domain, the tenant from the token only, no tenant-specific code, no secrets, versioned events and commands, file sizes, cost SKUs in Bicep;
2. the backend stack's build and tests (`tools/stacks/<stack>.sh`: dotnet, typescript, python, or none);
3. the Bicep files in `infra/`, when the Bicep CLI is installed;
4. `tools/check.local.sh`, if the app has one (client builds, emulator tests).

`bash tools/check.sh --architecture` runs step 1 alone in seconds, with no toolchain. The check exits 0 on pass, 1 on fail, and 3 when it can't run. It never calls Azure, the network or an external system, and remembers the last passing state so hooks don't rerun it when nothing changed.

### Customising
- **Workflow rules** that differ for one app go in AGENTS.md › Project rules, where they win over the defaults.
- **Architecture** that differs for one app goes in an ADR (`/architect`). Its `Exception:` lines are the only thing that excuses a check failure.
- **The framework itself:** edit `framework/` (installed files) or `project/` (seeds for new apps), add the change to `CHANGELOG.md`, and run `bash selftest.sh`. Then upgrade your apps.

### This repository
| Path | |
|---|---|
| `ONBOARDING.md` | what the assistant follows to install or upgrade |
| `install.sh` | copies the files deterministically, keeps your edits, writes a manifest (`--tools claude\|none`) |
| `framework/` | installed into each app: the tool-neutral core, plus `.claude/` for Claude Code |
| `project/` | seeds for the app's own files, copied only when missing |
| `.claude-plugin/`, `skills/` | the Claude Code plugin, and the same skills for the skills CLI (`npx skills add`): `saas-all-the-things` installs, `saas-assessment` assesses an app before installing, `saas-design-session` runs design sessions and workshops anywhere |
| `examples/order-desk/` | a small app that uses the workflow: a worked example, and the self-test's fixture |
| `examples/scenarios.md` | prompts to try after changing the framework, to check that behaviour still holds |
| `bundle.sh` | copies the reference, playbook and session procedures into `skills/saas-design-session/references/` (`bash bundle.sh`; the self-test fails if the copy drifts) |
| `selftest.sh` | tests the installer, the architecture check and the hooks (`bash selftest.sh`) |
| `CHANGELOG.md` | what changed, and the upgrade steps for apps |
| `.claude/CLAUDE.md` | instructions for an assistant working on SaaSAllTheThings itself |

Privacy: SaaSAllTheThings runs on your machine and sends nothing anywhere; see [PRIVACY.md](PRIVACY.md).

## License
MIT © 2026 Vikingur Saemundsson: see [LICENSE](LICENSE). Installed apps carry a copy in `.satt/LICENSE`.
