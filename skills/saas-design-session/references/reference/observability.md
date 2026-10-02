<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Observability

- **Structured logs** through the platform's logger (`ILogger`, or the stack's equivalent), with named properties, never string building. Every log line in a request or message carries `TenantId` and the correlation id.
- **No secrets, tokens or personal data** in logs, traces or metrics. Log ids, not names, email addresses or document contents.
- **Traces** with OpenTelemetry into Application Insights. HTTP calls carry `traceparent`; messages carry the correlation and causation ids in their envelope (`messaging.md`), so one user action is one trace across functions.
- **Health:** each function app has an anonymous `GET /api/health` that checks only itself, without touching dependencies or revealing versions.
- **Alerts** (in Bicep, to the owner's action group): failed requests above a rate, any dead-lettered message, an integration's reconciliation finding drift, and the budget thresholds (`cost.md`).
- **Per tenant:** usage metrics (requests, messages, storage) by `TenantId`, so plans can be priced and a noisy tenant found.
