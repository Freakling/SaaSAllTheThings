<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Identity

Users sign in with OIDC through their own organisation's identity provider (federated identity). Services and pipelines authenticate with managed identities and federated credentials. Nothing holds a secret.

## Users
- **Entra ID, multi-tenant.** The API is a multi-tenant Entra app registration, so a customer's users sign in with their own directory. A customer admin grants consent once, during tenant onboarding (`procedures/tenant.md`).
- **Customers without Entra ID** sign in through Entra External ID, which federates with their provider (OIDC, SAML, Google and others). Adding External ID to a project is an ADR.
- **App registrations:** one for the API (exposes the scope `access_as_user` and the app roles), one public client per client app. No registration has a client secret.
- **App roles** are defined by the product (PRD › Personas and Roles), for example `Tenant.Admin` and `Tenant.User`, plus the platform's `Operator`. A customer admin assigns them in their directory.

## Validating a token
The host validates every request before any handler runs:
1. signature, against the issuer's published keys (OIDC metadata);
2. issuer and directory: the issuer has the directory's form, and the directory (`tid`) maps to an active tenant in the registry;
3. audience is the API, the token hasn't expired, and the scope `access_as_user` (for users) or an app role (for apps) is present.

Then it builds the tenant context: `TenantId`, the user's object id, and the roles. Handlers authorize from that context.

## Clients
- MSAL as a public client: authorization code with PKCE. On Windows the WAM broker, on mobile the system browser or the Authenticator broker.
- Tokens stay in the platform's secure store (MSAL's cache on DPAPI, Keychain or Keystore).
- No client secrets, API keys or connection strings in an app. A client calls only our API.

## Services
- Each function app has a managed identity, given only the data-plane roles it needs (`infra.md` › Access): for example Cosmos DB Data Contributor on its own database, Service Bus Data Sender on its own topics.
- Local authentication is off where Azure allows it: Cosmos DB keys, Service Bus SAS and storage shared keys are disabled.

## Pipelines
CI/CD signs in to Azure with workload identity federation (OIDC from GitHub Actions or Azure Pipelines), on an identity scoped to its environment. No stored service principal secret.

## External systems
- **SaaS APIs in the customer's directory** (Business Central online, Dataverse, Graph): a multi-tenant integration app registration that trusts our function's managed identity as a federated identity credential. The customer consents to it, and the function gets tokens for the customer's directory with no secret. Details per system are in its integration contract.
- **Systems that only accept a password or key** (Navision on-premises, older APIs): the credential lives in Key Vault, is read by the function's managed identity through a Key Vault reference, and is never logged or returned. It's a deviation, so it needs an ADR that names the system and the rotation owner.

## No secrets
Nothing in the repository, a config file, an app setting value or a client app is a secret: no account keys, SAS tokens, client secrets, passwords or private keys. Local development uses `DefaultAzureCredential` with the developer's own sign-in, and the emulators' public well-known keys. The check's `secrets` rule fails on anything that looks like a secret. If one is found, it has been exposed: rotate it, then remove it.
