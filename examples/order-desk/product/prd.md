# Order Desk · Product Requirements

<!-- How this document works
- It states the current requirements only. History is in git, the reason for each decision is in
  product/decisions.md, and anything undecided is under Open Questions. Agents write down only what
  the human decided.
- Refer to sections by heading ("PRD › Orders"), never by number.
- How the system is built lives in .satt/reference/ and adr/, not here.
-->

## Pitch
A multi-tenant order desk for wholesalers: sales staff place customer orders on a Windows client, warehouse staff pick them on mobile, and every order syncs with the wholesaler's own Navision (Business Central).

## Product Pillars
- **Faster than Navision for the counter.** Placing an order takes less time than in the ERP.
- **Navision stays the books.** Customers, items and posted orders belong to Navision; we never fight it.
- **One product for every wholesaler.** A customer's need becomes a setting or a plan, never their own version.

## Customers and Tenants
- Wholesalers that run Navision or Business Central. The first is a pilot wholesaler on Business Central online.
- Plans: a pilot plan for now; its limits are Q2.

## Personas and Roles
- **Sales** (`Tenant.User`): places orders at the counter or on the phone.
- **Warehouse** (`Tenant.User`): sees orders to pick.
- **Admin** (`Tenant.Admin`): manages the tenant's settings and Navision connection.

## Capabilities
### Place an order
Sales picks a customer and adds lines (item, quantity, unit price). An order needs a customer and at least one line; every line needs an item, a quantity above zero and a price that isn't negative. The total is the sum of quantity × unit price. Customer numbers are the Navision customer numbers, which Navision stores in capitals. Prices: Q1.

### Pick an order
Warehouse sees placed orders for today and marks lines picked. (Not designed yet.)

## Clients
### Windows
Sales, at the counter, all day. Placing orders is the main job. Online only.
### Mobile
Warehouse staff on handhelds. Offline: Q3.

## Integrations
### Navision
Customers and items come from Navision; orders go to Navision as sales orders. Details: `integrations/navision/contract.md`.

## Data and Compliance
- Data stays in Norway or the EU (Q4 asks which region).
- Personal data: customer contact names come from Navision and are shown, not stored, unless Q5 decides otherwise.

## Service Levels
<!-- Not decided yet. -->

## Glossary
| Term | Meaning |
|---|---|
| Customer number | Navision's customer key, e.g. `C0001` |

## Open Questions
- **Q1** · Where do unit prices come from: typed by sales, our own price list, or Navision's prices for the customer?
- **Q2** · What does the pilot plan include: orders per month, users, Navision companies?
- **Q3** · Must the warehouse app work offline, and for how long?
- **Q4** · Which Azure region: Norway East, or West Europe?
- **Q5** · Do we store customer contact details, or always read them from Navision?
- **Q6** · [navision] An order changed in Navision before it's posted: does Navision's version win, or is it held for sales to resolve?
- **Q7** · [navision] How often do we read back the status of open orders, and when do we stop?

**Next:** Q8
