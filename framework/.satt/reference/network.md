<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Network

The default posture is that data services are not reachable from the public internet and accept no shared keys. The code reaches them with its managed identity, through a private endpoint where the tier has one.

## Default posture
- **Public network access off** on every data and secret store: Cosmos DB, Key Vault and Storage (and Service Bus where its tier allows, below).
- **Local authentication off**: Cosmos DB keys, Service Bus SAS and storage shared keys are disabled, so only Entra ID identities get in (`identity.md` › No secrets).
- **Private endpoints** are the way in when public access is off: the function apps reach each store through a virtual network and a private endpoint, and the customer's platform team owns the network around them.
- **Integrations are outbound-only**: the app calls the external system, or a connector the customer runs calls out to it; nothing opens an inbound path to the customer's network (`integrations.md`).
- **The API is the public surface.** The function apps that serve the clients stay reachable from the internet and protect every route with the validated token (`api.md`, `identity.md`). A web client's Static Web App is public too.

## Where it applies
| Resource | Public network access | Local authentication |
|---|---|---|
| Service Bus namespace, Standard (the default) | not available: Standard has no private endpoints, so the namespace stays reachable | `disableLocalAuth: true` |
| Service Bus namespace, Premium | `publicNetworkAccess: 'Disabled'` | `disableLocalAuth: true` |
| Cosmos DB account (serverless is the default) | `publicNetworkAccess: 'Disabled'` | `disableLocalAuth: true` |
| Key Vault | `publicNetworkAccess: 'Disabled'` | none to switch off (access is by role: `identity.md`) |
| Storage account | `publicNetworkAccess: 'Disabled'` | `allowSharedKeyAccess: false` |

Function apps, Static Web Apps, Application Insights and Log Analytics are not covered: the first two are the public surface above, and the monitoring resources have no setting the reference asks for.

## What the check enforces
The `network-public` rule reads each Bicep resource of the types in the table and fails when the property is missing or set to anything but the value shown: the literal `'Disabled'`, `true` or `false`, not a parameter that might hold either. Service Bus is held to the Premium row only when its block names the literal `'Premium'`; a SKU that comes from a parameter is read as Standard. A resource's block is read to its closing brace, and `existing` references to resources declared elsewhere are skipped.

The rule runs when `tools/check.cfg` has `network-public = on` under `[rules]`. New apps get it on; an upgraded app keeps its own file, where an absent key means off, until the app adds the line.

The check reads text. It does not prove that a private endpoint, a private DNS zone or a virtual network exists, and it does not look at egress control (network security groups, user-defined routes, NAT or a firewall), nor at Azure Policy assignments. Those belong to the customer's platform and control framework; `review.md` covers what the text can't show.

## Exceptions
A resource that can't meet the rule says why in an ADR (`procedures/architect.md`) with `Exception: network-public <path to the Bicep file>`, for example a store that must stay reachable until the platform team's network is ready. Private-only Service Bus needs Premium, which is a second exception, `cost-sku <path>`, with the monthly cost (`cost.md`).
