<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Stacks

The backend stack is the language the `contracts`, `domain`, `application`, `infrastructure`, `integration`, `host` and `platform` layers are written in. It must run on Azure Functions. The framework's default is **.NET (C#, isolated worker)**: Functions, MSAL, the Azure SDKs and the Business Central tooling are all first-class there.

## Compatible stacks
| Stack | Azure Functions | Check profile (`tools/stacks/`) |
|---|---|---|
| **.NET** (C#, also F#, VB.NET) | isolated worker | `dotnet`: `dotnet build` and `dotnet test` on the solution |
| **TypeScript / JavaScript** (Node.js) | programming model v4 | `typescript`: the package's `typecheck`, `lint`, `build` and `test` scripts |
| **Python** | programming model v2 | `python`: compiles every module, then `pytest` (or `unittest`) |
| **Java** | supported | none yet: use `none`, and run Maven or Gradle from `tools/check.local.sh` |

Not compatible: languages Azure Functions has no worker for, such as PHP, Ruby, Delphi, VB6, PowerBuilder or Access. Go and Rust run only as custom handlers, which SaaSAllTheThings doesn't support. PowerShell has a worker, but isn't a stack for a product backend.

With `stack = none`, the architecture rules still run, and builds and tests run only from `tools/check.local.sh`.

## Choosing the stack
Onboarding settles it with the human, and records it as the first ADR.
- **New app:** recommend .NET unless the team's skills point elsewhere.
- **Existing app:**
  1. Find its languages and frameworks, and ask whether the human has a preference.
  2. If the human wants to stay with the current stack and it's compatible, keep it, and reuse what fits (the table below).
  3. If the current stack isn't compatible, say why, list the compatible stacks with a recommendation (.NET unless the team points elsewhere), or ask for the preferred language. If that one isn't compatible either, say so and ask again. Never pick for the human.
  4. Converting means the roadmap's Extract stage rewrites each area into the new stack, behind characterisation tests; the old code waits outside the layers until its area is done.

## Reusing what an existing app has
| Existing part | Fits as | How |
|---|---|---|
| ASP.NET Core Web API | host | the domain and application code moves into layers; controllers become HTTP functions (ASP.NET Core integration) |
| Entity Framework Core with SQL Server | data, by ADR | Azure SQL serverless (`data.md` › Alternatives), a `TenantId` column and row-level security |
| WPF, WinForms or WinUI desktop app | the Windows client | business rules move to the domain; the UI calls the API |
| Xamarin.Forms app | the mobile client, converted | to .NET MAUI (Xamarin is out of support) |
| Express, NestJS or Fastify | host (TypeScript) | route handlers become HTTP functions |
| Django, Flask or FastAPI | host (Python) | views become HTTP functions; the ORM by ADR |
| Spring Boot | host (Java) | `stack = none` and `check.local.sh` |
| Windows services or scheduled jobs | host | timer or message-triggered functions |
| NAV C/AL or Business Central AL extensions | stays in Navision | the product integrates through its APIs (`integrations.md`) |

## Profiles and their layouts
Each profile file is sourced by `tools/check.sh` and `tools/setup-clone.sh`, and defines `stack_toolchain`, `stack_setup` and `stack_check`. `[layers]` patterns for each stack's usual layout:

| Layer | .NET | TypeScript (npm workspaces) | Python |
|---|---|---|---|
| `host` | `src/*.Functions` | `packages/functions packages/integrations-*-functions` | `functions` |
| `platform` | `src/*.Platform` | `packages/platform` | `platform` |
| `integration` | `src/*.Integrations.*` | `packages/integrations-*` | `src/*/integrations` |
| `contracts` | `src/*.Contracts` | `packages/contracts` | `src/*/contracts` |
| `domain` | `src/*.Domain` | `packages/domain` | `src/*/domain` |
| `application` | `src/*.Application` | `packages/application` | `src/*/application` |
| `infrastructure` | `src/*.Infrastructure` | `packages/infrastructure` | `src/*/infrastructure` |
| `client` | `clients/*` | `clients/*` | `clients/*` |
| `tests` | `tests/*` | `**/*.test.ts **/test` | `tests` |

A file belongs to the first layer whose pattern matches, in the order `[layers]` lists them, so the more specific patterns (hosts before integrations) come first. `[imports]` names how code refers to each layer: namespaces for .NET (`OrderDesk.Domain`), package names for TypeScript (`@orderdesk/domain`), modules for Python (`orderdesk.domain`). Relative imports are resolved by path.

### The TypeScript profile in the fast tier
The profile runs the root `typecheck`, `lint`, `build` and `test` scripts. In the fast tier (`bash tools/check.sh --fast`) of an app with npm workspaces, `typecheck`, `lint` and `build` still cover the whole project, and `test` covers only the packages the change reaches: the packages with a changed path, and every package that depends on one of them, directly or through other packages, by the workspace packages named in the `dependencies`, `devDependencies`, `peerDependencies` and `optionalDependencies` of their `package.json` files. Only the changed paths that make the backend run count (not `infra/`, the `client` layer or Markdown). A change outside every package runs the whole root `test`, and the check says which path it was. The full tier, and an app without `workspaces`, run the root `test` whole.

An app opts in one of two ways, tried in this order:
1. **A root `test:fast` script.** It gets the folders of the packages to test in the environment variable `CHECK_PACKAGES`, relative to the repository root and separated by spaces (`packages/domain packages/functions`), and decides for itself how to test them (`vitest run --dir` per folder, a loop of `npm test --workspace`, and so on).
2. **A `test` script in every package.** Without `test:fast`, the check runs `npm run test --workspace <folder>` for each package to test.

With neither (a package to test has no `test` script and there's no `test:fast`), the root `test` runs whole and the check says so. A run prints which packages it tested and which it left to the full tier.

## Clients
A client's toolchain can differ from the backend's (a .NET backend with a Kotlin app). Its build and tests run from `tools/check.local.sh`; the architecture rules cover it either way.
