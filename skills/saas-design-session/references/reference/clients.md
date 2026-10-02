<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Clients

A SaaSAllTheThings product has separate client apps, typically one for Windows and one for mobile. They serve different people and jobs (PRD › Clients), so they're separate apps that share only the contracts.

## Rules for every client
- **Thin.** A client shows state and sends commands. Business rules live in the backend; a client may repeat a validation for a quick answer, but the backend decides.
- **Contracts only.** A client depends on the contracts layer, or on an API client generated from the OpenAPI document, and nothing else of ours. The check's `layers` rule enforces it.
- **Sign-in** with MSAL as a public client: authorization code with PKCE, the platform broker where there is one (`identity.md` › Clients).
- **No tenant in requests.** The tenant is whoever the signed-in account belongs to.
- **No secrets** and no connection strings in the app: it calls only our API. Endpoints per environment come from build configuration; settings per tenant come from the API.
- **Offline** only where PRD › Clients asks for it: commands are queued with their idempotency keys and replayed when back online; the backend resolves conflicts.
- **Telemetry** passes the trace context (`traceparent`) on every call, so a client action and the backend's work share one trace.

## Each client's UI technology
The reference leaves it open, because it depends on who uses the app and on the team. It's decided per client in an ADR (`architect.md`). Typical options:
- **Windows:** WinUI 3, WPF (often when an existing WPF app becomes the client), .NET MAUI, or a web app in a desktop shell.
- **Mobile:** .NET MAUI, native (Swift / Kotlin), Flutter, or React Native.

## Layout
One folder per client under `clients/`, each with its own build. Its build and tests run from `tools/check.local.sh` (`stacks.md` › Clients), because the client's toolchain may differ from the backend's.
