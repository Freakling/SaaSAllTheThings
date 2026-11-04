<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. Workflow rules that differ for this project go
in AGENTS.md › Project rules, and win over these defaults. Architecture rules don't: they change
only through an accepted ADR (see Who decides). -->
# SaaSAllTheThings workflow rules

These rules apply to any AI assistant working in this project. For each of these requests, follow the procedure in `.satt/procedures/`:
- **next-task.md:** do the next task(s), or a named item (T12, B3, R2). The build itself is `build.md`.
- **assess.md:** assess the app for the move to SaaS (readiness, the user stories it serves today, roadmap, the workshops and how to run them), or process workshop notes.
- **roadmap.md:** plan the next stage of the roadmap to SaaS, or replan.
- **design.md:** a product session: capabilities, plans, clients, open questions, validating the user stories.
- **architect.md:** an architecture choice the reference leaves open, or a deviation from it.
- **research.md:** research a question in a fresh context and save a dated note in `product/research/`, for a product or architecture call. It informs; the human decides. Domain reference: `.satt/research-domain.md`.
- **integrate.md:** add or change an enterprise integration (Navision / Business Central first).
- **tenant.md:** prepare onboarding a new tenant (customer).
- **acceptance.md:** prepare or process an acceptance check.
- **feedback.md:** new feedback report, process a feedback report.
- **ui-design.md:** capture the screens (`/ui-design`): a PNG per screen, state and size of the web client on this machine or in dev (never prod), as test users of seeded test tenants, with an element map, a numbered map image, layout lint and a starter drawing; process the director's Excalidraw drawing of a screen into a screen spec and items; verify a built screen against its spec and write compare images; list the screens in the catalog.
- **prototype.md:** try a change fast in a prototype (`/prototype <name>`), in its own session and git worktree on a `proto/<name>` branch, outside the loop and never deployed; list the prototypes; harvest one into decisions, user stories, ADRs and items (`/prototype harvest <name>`), and remove it.
- **release.md:** deploy to an environment.
- **security.md:** a security assessment (`/security`): validate what is built against the OWASP baseline with the checklist in `reference/owasp.md`, file findings as bug items, list the people and process work for the director, and write a dated report in `assessment/security/`. `release.md` runs it before a release; `next-task.md` proposes it every `tools/check.cfg` › `[security] every` items.
- **align.md:** check the docs and tasks are aligned.
- **drift-reset.md:** a design drift reset, only when the director asks for one: align often, reset when you have to. `drift-reset postmortem` runs after its rebuild.
- **prune.md:** prune the task list.
- **review.md:** review a finished change.

In Claude Code these are also slash commands, and builds, reviews and research run as the `builder`, `reviewer` and `researcher` subagents.

## Who decides
- **The director owns the product:** capabilities, UX, plans and pricing, priorities, which tenants and integrations come first, and business rules such as which system owns which data. You build, keep the records, and propose.
- **The framework owns the architecture:** `.satt/reference/`. It holds unless an accepted ADR in `adr/` says otherwise for this project. Project rules can't change it, and neither can you.
- **A product call** is anything a user or customer would notice that the PRD doesn't settle. Give 2-4 options with one recommendation and a one-line reason, then wait. Write down only what was chosen, following `design.md` › Record each decision. If you had to interpret the answer, say how you read it.
- **Nothing is written without the human's explicit approval.** While a session runs, the answers stay in the conversation. A chat message or an "Other" answer during a session is a scope change or a modification, not an answer to record: it re-opens the options it touches, and the session reassesses, then restarts or continues. Once everything is chosen, show a summary of every file, line, item, story and ADR status to be written (`design.md` › Summary and approval), and write and commit all of it in one change only after the human approves the summary.
- **An architecture call** is a choice the reference leaves open (a client's UI tech, a data store alternative) or anything that would break a reference rule. Never settle one inside a build, and never work around a rule to make the check pass: stop and follow `architect.md`. Its first option is always to comply.
- **Only the director accepts an ADR.** An ADR is accepted only by the director's approval of the summary that lists it. The summary names each ADR with its status, and `architect.md` writes the ADR, its exceptions, the TASKS.md items, the AGENTS.md lines and the compliance mapping rows only after that approval. In Claude Code the hook still asks the director to confirm an edit that sets `Status: accepted`.
- Never answer an item in PRD › Open Questions yourself. Work that depends on one gets a placeholder that names the question.
- Research informs a product or architecture call and never makes it. The `researcher` records no decision, never edits the PRD, `product/decisions.md` or an ADR, never answers an open question, never accepts an ADR, and never asks the human; its recommendation is shown as one option with its reason.
- Something that seems to contradict a Product Pillar is flagged, never reinterpreted.

## Protected space
`director/` is the director's personal workspace: screen drawings (`director/ui/`), mockups, brand assets, reference images, notes, third-party API specs. Read files there for context when an item needs them, but never create, modify or delete anything inside it. If work depends on an asset the director owns that isn't there yet, ask for it, and meanwhile use a minimal stand-in marked `PLACEHOLDER`, never a generated version of the real thing. In Claude Code a hook blocks edits there.

## Each fact lives in one place
| Fact | Only in |
|---|---|
| What the product should do | `product/prd.md`. List its sections with `grep -n "^#" product/prd.md` and read only the ones you need. |
| Why each feature is built, for which persona | `product/user-stories.md`: the value for each persona in PRD › Personas and Roles, and their stories (`US-<n>`), each confirmed by the human or `unconfirmed` (`procedures/design.md` › User stories) |
| What's undecided | PRD › Open Questions (`Q<n>`) |
| Why a product decision was made | `product/decisions.md` (append-only) |
| The reference architecture | `.satt/reference/`, one topic per file (framework-owned) |
| This project's architecture choices and deviations | `adr/ADR-<n>-<slug>.md` |
| The evidence behind a product or architecture call | `product/research/`, one dated note per topic; the decision line, or the ADR, links to it |
| Which systems, functions and messages exist, and who owns what | `AGENTS.md` › Architecture |
| How each screen is laid out | `product/ui/<screen>.md`, one spec per screen (`procedures/ui-design.md`) |
| The director's screen drawings | `director/ui/` (Excalidraw files; read-only for you) |
| How an external system is integrated | `integrations/<system>/contract.md` |
| Work, bugs, research, milestones | `TASKS.md` (format: `.satt/tasks.md`; done items: `TASKS-archive.md`) |
| Assessments and workshop notes | `assessment/`: snapshots, security assessments in `assessment/security/`. What they decide is recorded in the PRD, the user stories, ADRs, contracts and TASKS.md (`assess.md` › Process workshop notes). |
| Design drift resets | `resets/YYYY-MM-DD/`: snapshots (as built, interpretations, the design before, postmortem). What they decide is recorded in the PRD, `decisions.md`, ADRs and TASKS.md (`drift-reset.md`). |
| Settings per environment | `infra/env/<env>.bicepparam` (never secrets) |
| Settings per tenant | the tenant registry: data, never code or repository files |
| Secrets | Key Vault, and ideally none (`reference/identity.md` › No secrets) |
| Whether it works | `bash tools/check.sh` |

Update the owning place in the same change that makes it untrue. Replace superseded text; never strike it through or keep two versions. Refer to sections by heading ("PRD › Orders", "reference/tenancy.md › Isolation"), never by number.

## The three tenets
- **Low cost.** In tokens: read by heading or line range, let builds run in a fresh context, keep reports short. In Azure: the defaults in `reference/cost.md`; anything above them needs an ADR, and the check fails Bicep that asks for more.
- **Small iterations.** One item, one commit. Prefer `S` items and split `L` items. A vertical slice that works end to end beats a layer built on its own. Write items for the current stage and the next one only.
- **Many files.** One type per file, one function per file, one handler per use case, one Bicep module per resource. Split a file when it grows a second responsibility; the check fails source files over the limits in `tools/check.cfg`.

## Architecture in code
Read the reference topics an item touches (`reference/README.md` lists them). Every item follows these:
- **Layers.** Code lives in the layers of `reference/layers.md`, which says what each may depend on. AGENTS.md › Layout maps layers to folders; `tools/check.cfg` › `[layers]` to path patterns.
- **The domain is pure.** Business rules receive time, ids, randomness and configuration as inputs and do no I/O, so tests build them directly.
- **Hosts are thin.** A function validates input, takes the tenant, calls one handler and maps the result.
- **Screens.** Every screen of a web client has an entry in the screen catalog, `tools/ui/screens.mjs`; add or update it whenever you add or change a screen. Elements a screen spec names get a `data-testid` (`order-list`) that the spec, element maps and tests share. Build layouts with flex or grid, never pixel positions. The catalog opens a tenant's screen as a test user of a seeded test tenant and seeds data through the public API, as a client does: never a real tenant, account, token or customer's data.
- **The tenant comes from the validated token** (for messages: the envelope), never from a header, route, query or request body. Tenants differ only by registry data and plans; no code names a tenant.
- **Contracts are versioned.** Events and commands are named `…V<n>`; a version only ever changes additively.
- **OWASP is the baseline.** The OWASP Top 10 (2025), and the OWASP API Security Top 10 (2023) for anything that serves an API, is the security baseline every app meets. It is framework-owned: no project setting or `tools/check.cfg` key switches it off, and no ADR removes it as a whole. An accepted ADR may deviate from a single item, naming the item and why; review reports any other deviation as a finding. `security.md` validates what is built against it, category by category (`reference/owasp.md`).
- **No secrets** in the repository, config files or client apps: managed identities and federated credentials instead.
- **Undecided values** (limits, quotas, retry counts, prices) get a default marked `PLACEHOLDER` next to it, naming its `Q<n>` if one exists. They're never hand-picked as final.

The check enforces what can be checked mechanically; `reference/README.md` › What the check enforces lists the rules. A violation is excused only by an `Exception:` line in an accepted ADR.

## Doing the work
- **Where work comes from.** `TASKS.md`, or straight from the human. A direct request that won't be finished this session, or that turns up follow-up work, gets a TASKS.md item. Work you discover always becomes a new item; never do it silently as part of another.
- **Why it's built.** A feature item names the user stories it serves (`Stories:` in `.satt/tasks.md`). One with no story gets one drafted first, as `design.md` › User stories says, for the human to confirm.
- **Read what the work needs:** the item's `Touches`, the AGENTS.md › Architecture rows involved, the PRD sections and stories it names and the reference topics it touches. Read by heading or line range, not whole files. Quote only the relevant lines of logs; the full check logs are in `.satt/state/`.
- **Stay inside the item.** Prefer the smallest change, and delete dead code. Match existing patterns; a new pattern needs a reason in the commit message.
- **Tests.** Domain and application rules get unit tests, with in-memory fakes for the ports. Integrations get contract tests against recorded fixtures. Every store gets a tenant-isolation test (one tenant can't read another's data). A fixed bug gets a regression test when it can have one. Tests never call the network, Azure or an external system.
- **Outcome tags.** Each outcome in `Done when` is tagged:
  - `(test)`: a test proves it;
  - `(check)`: a command you run and quote proves it, such as the check or a `grep`;
  - `(demo)`: a human verifies it in a running app, in the next acceptance check.
- **Done** means every `(test)` and `(check)` outcome holds, every `(demo)` outcome is implemented, and `bash tools/check.sh` exits 0. Never report done otherwise, and show the output of a failing check. Exit 3 means the check couldn't run, so say the work is unverified.
- **Running the check.** Run it in the foreground with a long timeout (10 minutes or more); other runs and hooks wait for it. While working, `bash tools/check.sh --architecture` gives the architecture rules in seconds.
- **Commands that may run long.** Give every command that may run long a time limit under five minutes (`timeout 240 …`): past five minutes the prompt cache expires and the next turn rewrites the whole context. Start a long check with `run_in_background` and keep working until its completion notice, instead of polling with a `sleep` loop (the command guard blocks a loop without a limit of 280 seconds or less, and a lone `sleep` past it). Never feed Python its script from a heredoc (`python3 - <<'EOF'`, with a body or not): it can wait for input and never return. Put the script in a file and run that, and use `python3 --version` to probe for it. The guard blocks this.
- **Shell commands.** Write files with the file tools (Write or Edit in Claude Code), never with a shell heredoc or an `echo` or `printf` redirect of multi-line content, because a heredoc can hang the shell; a multi-line script is written to a file the same way and run from there. Every shell call is one short command that finishes well inside the tool's timeout; the only long runs are the check, a build and a host start, each with an explicit long timeout or in the background (Running the check). A command the tool moved to the background after its timeout keeps a finished agent running for as long as it lives: stop it before you report or end the turn, with the tool's stop if it has one (TaskStop in Claude Code), or else `kill` or `taskkill` with its pid.
- **Two failed attempts.** After two failed attempts at the same problem, stop and report instead of guessing further.

## Git and Azure
- **One item, one commit.** The message is `<type>: <summary> (T12)`, with a body saying why; types are `feat fix refactor test docs infra chore`. The item's paths are its code, tests, infrastructure, and the records the item changed (TASKS.md, AGENTS.md, `product/user-stories.md` when a story was drafted for it, and the PRD, decisions and ADRs for a decision made during the item). `git add` the new ones, then commit only those paths, `git commit -m "…" -- <paths>`, so another session's staged work stays out.
- **Approval.** Commit only with the human's approval. An approval prompt from your tool counts; otherwise ask in the conversation, unless Project rules say otherwise. A run the human asked for (`next-task.md` › Several items) approves its commits in advance, not pushes, deploys or changes to cloud resources. Push only when asked. Never get around the hooks (`--no-verify`, `core.hooksPath`).
- **Destructive commands.** Anything that discards uncommitted work or rewrites history needs the human. For a history cleanup they ask for, note the current tip first, and use non-interactive forms only.
- **Azure and other shared systems.** Deploying, and changing cloud resources, app registrations, role assignments or a tenant's data, need the human's approval each time, following `release.md`; deleting them is the human's to do. Production is the human's to deploy. Never read a secret's value into the session, and never create a client secret: use a federated credential.

## Sessions, clones and context
- **New clone or machine.** Run `bash tools/setup-clone.sh`. It checks the stack's toolchain, restores dependencies and installs the pre-commit and pre-push hooks.
- **Two sessions that build at once** (say product and coding, or two coding sessions): give one its own worktree (`git worktree add ../app-product`) and run `bash tools/setup-clone.sh` there. Two sessions in one working tree break each other: one session's half-written files fail the other's check, and both queue on the same build artefacts. The Stop hook runs the check only for a session that wrote a source file itself, so a session that edits only documentation isn't held up by the other's code. A claim in TASKS.md protects only its own working tree. So only one session per project picks items; the others name the item they work on.
- **Prototypes.** A prototype (`procedures/prototype.md`) tries a change in its own session, in a git worktree on a `proto/<name>` branch. A session in a checkout that `bash tools/prototype.sh here` calls a prototype (a linked worktree on a `proto/` branch with `PROTOTYPE.md` at its root) is a prototype session: read `prototype.md` › In a prototype session before any work. That session is outside the loop: there the rules on items, records, the builder, reviews and commit approval give way to that section, while the guard, the secrets scan and Protected space still apply, nothing on a `proto/` branch is pushed or merged, and nothing is deployed, to dev either. Its work reaches main only through the harvest, which turns it into decisions, user stories, ADRs and items built from main like any other, to the reference architecture.
- **The records are the hand-off.** TASKS.md (what's done and what's next), commit messages (why), AGENTS.md, the PRD and the ADRs carry everything between sessions. Once an item is committed, a fresh session, or `/clear` in Claude Code, loses nothing.

## Reviews and model size
- An `L` or `XL` item, or an `M` item that changes a contract (an API route, event or command), tenant isolation, identity or a stored schema, gets an independent review (`review.md`) before its commit. Fix the findings that are in scope.
- A research item (`R<n>`) gets no check run and no review: it changes no code. Its size picks the `researcher`'s model the same way.
- **Model sizing** (recommended on): when enabled, each task size builds on a different model: trivial tasks cheap and fast, large tasks on the most capable. AGENTS.md › Project rules stores one model ID per size:
  ```
  Model sizing: on
  - XS: <model-id>
  - S:  <model-id>
  - M:  <model-id>
  - L:  <model-id>
  - XL: <model-id>
  ```
  Map sizes to your tool's models by capability: XS and S → smallest capable model, M → balanced model, L and XL → most capable model. Every subagent launch sets its model explicitly: `next-task.md` passes the entry for the item's size to the builder, the reviewer, the researcher and an escalated retry. A size with no entry, or model sizing off, passes the session model, also explicitly, so no subagent inherits the session's model. Run `/refresh-model-sizing` to write the entries for your tool, or to check whether your tool supports the feature. A failed build retries once on the next size's model (XS→S, S→M, M→L, L→XL); an XL failure stops and comes to the director.
