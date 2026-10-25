<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# The OWASP checklist

The OWASP Top 10 (2021), and the OWASP API Security Top 10 (2023) for anything that serves an API, is the baseline every app meets (`rules.md` › Architecture in code). This file breaks each category into checks a reader can verify in this reference architecture, and says where to look. `procedures/security.md` goes through it category by category; `review.md` uses it for a single change.

- **Sources.** The categories are the OWASP Top 10 (2021; the ids and names of the baseline rows in `compliance/mapping.md`) and the OWASP API Security Top 10 (2023). The checks paraphrase the OWASP Application Security Verification Standard (ASVS) 5.0 at level 1 where it has a matching requirement, named by chapter, and add what this architecture makes specific. Read the OWASP documents themselves for the wording; nothing here is copied from them.
- **Kinds.** Each check is marked:
  - `code`: verified by reading the app's code and tests;
  - `config`: verified by reading the Bicep in `infra/`, `tools/check.cfg`, the workflow or app settings;
  - `people`: people and process. It can't be verified in the repository; it goes to the director as something to do or confirm.
- **Where to look** names the place in the reference architecture: the host's token validation (`src/*.Functions`, `src/*.Platform`), tenant scoping in data access (`src/*.Infrastructure`, the ports in `src/*.Application`), Key Vault and managed identities, Service Bus message handling, the web client (`clients/`), and `infra/`. `tools/check.cfg` › `[layers]` gives the real folders.
- **A tool passing never verifies a check on its own.** A check rule or audit that finds nothing shows only that its pattern isn't there; the reviewer still reads the code the check concerns.

## What the tools cover
The tool step of `procedures/security.md` reports each result under this OWASP item. A clean result here is evidence for that slice only.

| Tool or rule | OWASP item | What a clean run doesn't prove |
|---|---|---|
| `secrets` (the check) | A02 | that no secret is in an app setting, a pipeline variable, a log or the git history, or in a form the pattern doesn't know |
| `tenant-source` (the check) | A01, API1 | that every query filters by the tenant: the rule sees where the tenant comes from, not how a store uses it |
| `tenant-branching` (the check) | A01 | that tenants can't reach each other's data by other means |
| `network-public` (the check) | A05, API8 | anything about resource types it doesn't cover, network security groups, egress, or Function app settings; it doesn't run when off in `tools/check.cfg` |
| `dotnet list package --vulnerable --include-transitive`, `npm audit --omit=dev`, `pip-audit` | A06 | that the code uses its dependencies safely, or that an advisory without a published fix doesn't apply |
| `dependency-review` and `sbom` jobs (the shipped workflow) | A06, A08 | that the dependencies are trustworthy; the SBOM lists components and verifies nothing |
| Semgrep with `p/owasp-top-ten` | the item each rule names | anything its rules don't match: authorization logic, tenant scoping, business flows |

## OWASP Top 10 (2021)

### A01 Broken Access Control
ASVS: V8 Authorization. Rules: `tenant-source`, `tenant-branching`.
- `code` Every HTTP function runs behind the host's token validation, and none skips it (no route outside it except `GET /api/health`). Where: the host's middleware or filter, `identity.md` › Validating a token.
- `code` Each handler authorizes the use case from the tenant context's roles, and denies by default; a role check isn't left to the client. Where: `src/*.Application` handlers.
- `code` Every query, write, blob path, cache key and message is scoped by the tenant from the tenant context, and another tenant's record answers 404. Where: the stores in `src/*.Infrastructure`, `tenancy.md` › Isolation.
- `code` The tenant context comes only from the validated token: its directory (`tid`) mapped through the tenant registry, never from a header, query, route or body. Where: the host's token validation, `tenancy.md` › Where the tenant comes from.
- `code` Every store's partition key starts with the `TenantId`, and every point read and write passes it. Where: stores in `src/*.Infrastructure`, `tenancy.md` › Isolation, `data.md`.
- `code` Timers work through the registry's active tenants one at a time, and integrations take the tenant from the connection that received the data. Where: timer functions and `src/*.Integrations.*`, `tenancy.md` › Where the tenant comes from.
- `code` No cache, static field or singleton holds one tenant's data where another tenant's request can reach it; cache keys start with the `TenantId`. Where: `src/*.Infrastructure`, hosts, `tenancy.md` › Isolation.
- `code` Adapters resolve endpoints through the tenant's stamp, never a single global setting. Where: `src/*.Infrastructure`, `src/*.Integrations.*`, `tenancy.md` › Silo-ready.
- `code` Every store has a tenant-isolation test (tenant B can't read, change or list tenant A's data). Where: `tests/`.
- `code` Operator routes in `platform` require the operator role. Where: `src/*.Platform`.
- `people` Access reviews: who holds `Tenant.Admin`, `Operator` and the Azure roles, reviewed on a schedule, with leavers removed.

### A02 Cryptographic Failures
ASVS: V11 Cryptography, V12 Secure Communication, V14 Data Protection. Rule: `secrets`.
- `code` No key, password, connection secret, token or private key in the repository, config or a client. Where: the whole repository, `identity.md` › No secrets.
- `config` Services reach Cosmos DB, Service Bus and Storage with managed identities, and the one credential an ADR allows lives in Key Vault behind a Key Vault reference. Where: `infra/`, app settings in Bicep.
- `config` HTTPS only, and the minimum TLS version set on every resource that has the setting. Where: `infra/`.
- `code` Sensitive data the PRD names is not logged or returned beyond what the use case needs. Where: handlers, response contracts in `src/*.Contracts`, `observability.md`.
- `people` Key and certificate rotation: an owner and a schedule for every credential an ADR allows, and for signing certificates the app trusts.

### A03 Injection
ASVS: V1 Encoding and Sanitization, V2 Validation and Business Logic.
- `code` Queries are parameterized (Cosmos DB `QueryDefinition` with parameters, or the stack's equivalent); no query, filter or command is built by joining strings with input. Where: stores in `src/*.Infrastructure`.
- `code` Input is validated against the request contract before the handler runs, and invalid input answers 400. Where: hosts, `api.md`.
- `code` No input reaches a shell, a process start, a file path or a template engine unescaped. Where: integrations and file handling.
- `code` The web client renders data as text, never as HTML built from input. Where: `clients/` (web).

### A04 Insecure Design
ASVS: V2 Validation and Business Logic, V15 Secure Coding and Architecture. Rules: `layers`, `domain-purity` (structure only).
- `code` Business rules live in the domain and application layers, not in a host or client, so one place enforces them. Where: `layers.md`.
- `code` Plan limits are enforced in the application layer (a handler refuses work beyond the plan). Where: `tenancy.md` › Plans and limits.
- `code` Accepted ADRs state their effect on the baseline by OWASP item (`architect.md`), and each deviation from an item has one. Where: `adr/`.
- `people` Threat modelling: the risky flows (sign-in, tenant onboarding, payments, integrations) were discussed with the security officer when they were designed.

### A05 Security Misconfiguration
ASVS: V13 Configuration. Rule: `network-public`.
- `config` `network-public` is on in `tools/check.cfg`, or an ADR says why not. Where: `tools/check.cfg` › `[rules]`.
- `config` Public network access and local authentication are off on Cosmos DB, Service Bus, Key Vault and Storage, with exceptions only in accepted ADRs. Where: `infra/modules/`, `network.md`.
- `config` Function apps use `Anonymous` authorization level with the host's own token validation, never function keys as the protection, and CORS lists only the app's own origins. Where: `infra/`, `api.md`.
- `code` Errors are problem details without stack traces, internal names or versions; `GET /api/health` reveals no versions. Where: hosts, `observability.md`.
- `config` Each managed identity has only the data-plane roles it needs. Where: `infra/`, `infra.md` › Access.

### A06 Vulnerable and Outdated Components
ASVS: V15 Secure Coding and Architecture. Tools: the dependency audits, `dependency-review`.
- `config` The dependency audit for each stack in the app reports no high or critical advisory without an accepted ADR. Where: the manifests (`*.csproj`, `package-lock.json`, `requirements.txt` or `pyproject.toml`).
- `config` The shipped workflow's `dependency-review` job runs on pull requests, where the app has the workflow. Where: `.github/workflows/check.yml`.
- `config` Runtimes and frameworks are versions still supported by their vendor. Where: `*.csproj` target frameworks, `infra/` runtime settings.
- `people` Vulnerability response: who reads advisories, and how fast a high one is patched, is the customer's process (`infra.md` › Dependencies and the SBOM).

### A07 Identification and Authentication Failures
ASVS: V6 Authentication, V7 Session Management, V9 Self-contained Tokens, V10 OAuth and OIDC.
- `code` The host validates the token's signature against the issuer's published keys, the issuer and directory, the audience, expiry and the scope or app role, before any handler runs. Where: the host's token validation, `identity.md` › Validating a token.
- `code` A token whose directory isn't an active tenant is refused with 403. Where: the token validation and the tenant registry.
- `code` Clients sign in with MSAL as public clients (authorization code with PKCE) and keep tokens in the platform's secure store. Where: `clients/`, `clients.md`.
- `config` No app registration has a client secret; pipelines use workload identity federation. Where: `infra/`, the pipeline definitions.
- `people` The customer admin's consent, and the customer's own sign-in policy (multi-factor authentication, conditional access), are confirmed during tenant onboarding (`procedures/tenant.md`).

### A08 Software and Data Integrity Failures
ASVS: V15 Secure Coding and Architecture, V2 Validation and Business Logic.
- `code` Message consumers take the tenant from the envelope only our code writes, are idempotent, and reject a message whose envelope is missing or invalid. Where: Service Bus functions, `messaging.md`.
- `code` No untrusted data is deserialized into arbitrary types (no type names taken from the payload). Where: message and request handling.
- `config` Actions in the workflow are pinned, and CI signs in to Azure with workload identity federation scoped to its environment. Where: `.github/workflows/`, `identity.md` › Pipelines.
- `people` Who may merge to main and deploy to prod, with branch protection on main.

### A09 Security Logging and Monitoring Failures
ASVS: V16 Security Logging and Error Handling.
- `code` Authentication failures, authorization denials and operator actions are logged as structured events with `TenantId` and the correlation id. Where: hosts and handlers, `observability.md`.
- `code` No secret, token or personal data in logs, traces or metrics. Where: log calls.
- `config` Alerts in Bicep for failed requests above a rate and for dead-lettered messages, to the owner's action group. Where: `infra/`.
- `people` Alert routing and on-call: who receives each alert, who is on call, and the incident response steps when one fires.

### A10 Server-Side Request Forgery
ASVS: V1 Encoding and Sanitization, V15 Secure Coding and Architecture.
- `code` The backend calls only known systems whose addresses come from configuration or the integration contract, never a URL taken from a request or a tenant's data without an allow list. Where: `src/*.Integrations.*`, `integrations.md`.
- `config` Outbound calls go only to the systems the integration contracts name. Where: `infra/`, `network.md`.

## OWASP API Security Top 10 (2023)
Each API item names the Top 10 row it belongs under in `compliance/mapping.md`, which has no API rows of its own.

### API1 Broken Object Level Authorization (row A01)
- `code` Every route that takes an object id loads it through a store scoped by the tenant context, and checks the user may act on that object; an id from another tenant answers 404. Where: handlers and stores.

### API2 Broken Authentication (row A07)
- `code` The checks of A07 hold for every route, including new ones; no route accepts a key or a token from a query string. Where: hosts.

### API3 Broken Object Property Level Authorization (row A01)
- `code` Request contracts carry only the properties a caller may set (no tenant, owner, role or status a caller mustn't change), and responses only the properties the caller may see. Where: `src/*.Contracts/Api/`.

### API4 Unrestricted Resource Consumption (row A04)
- `code` Lists are paged with a maximum page size, uploads have a size limit, and a plan limit answers 429. Where: handlers, `api.md`, `tenancy.md` › Plans and limits.
- `config` Function apps have a scale limit, and the budget alerts exist. Where: `infra/`, `cost.md`.

### API5 Broken Function Level Authorization (row A01)
- `code` Admin and operator functions check the role in the handler, separate from user functions. Where: handlers, `src/*.Platform`.

### API6 Unrestricted Access to Sensitive Business Flows (row A04)
- `code` Flows the PRD marks sensitive (sign-up, purchases, invitations) have a limit per tenant or user. Where: handlers.
- `people` Which business flows are sensitive is the director's call in the PRD.

### API7 Server Side Request Forgery (row A10)
- `code` The checks of A10. Where: integrations.

### API8 Security Misconfiguration (row A05)
- `config` The checks of A05, plus: HTTP methods a route doesn't use are refused, and responses set no cache headers on tenant data. Where: hosts, `infra/`.

### API9 Improper Inventory Management (row A05)
- `code` The OpenAPI document generated from the contracts lists every route, old versions are retired on a date, and no test or debug route ships. Where: `src/*.Contracts`, `api.md`.
- `people` An owner keeps the list of environments and published API versions.

### API10 Unsafe Consumption of APIs (row A08)
- `code` Responses from integrated systems are validated against the contract before use, with timeouts, and their errors don't leak to our callers. Where: `src/*.Integrations.*`, `integrations.md`.

## Severity
- **high:** exploitable from outside, or across tenants, without unusual conditions: a tenant isolation break (always high), a route without authentication or authorization, injection reachable from input, a secret in the repository, a high or critical advisory in a dependency the app ships.
- **medium** (`med` in a bug heading): weakens a defence, or needs a second flaw or an insider to exploit: public network access on a data resource, a missing limit, an error that leaks internals, a moderate advisory.
- **low:** hardening with no direct path to exploitation: a missing log property, an alert that isn't routed, a low advisory.
