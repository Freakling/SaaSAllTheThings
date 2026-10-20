// The screen catalog · project-owned: edit freely.
//
// Every screen of the product's web clients, and how to put it on screen in a representative state,
// for `bash tools/ui_capture.sh` (.satt/procedures/ui-design.md). Add or update an entry whenever you
// add or change a screen. Capture opens the app on this machine (tools/ui_capture.cfg › [web]
// base_url, or `baseUrl` here) or, with --dev, the dev environment ([web] dev_url); never prod.
//
// An entry: { id, title, route, states, tenant, auth, source, animate }
//   id      names the files (letters, digits, _ and -); title is for people
//   route   the path capture opens, such as "/orders"
//   states  optional: { default: <state>, empty: <state> }; without it the screen has one state, default
//   tenant  a seeded test tenant, listed in tools/ui_capture.cfg › [web] tenants; never a real tenant
//   auth    the saved sign-in of that tenant's test user, tools/ui/.auth/<auth>.json (gitignored);
//           tenant and auth go together, and a signed-out screen (sign-in, a public page) has neither
//   source  optional: the client file that renders the screen, so --missing and align know it's covered
//   animate optional: true for a screen whose animations can't be stopped for the shot
//
// A state is an async function (page, api, screen), null, or { setup, tenant, auth } for a state that
// opens as another seeded test tenant's user, such as the second test tenant for tenant isolation;
// such a state names both its tenant and its sign-in.
// It seeds data through the product's public API with `api` (api.post("/api/v1/orders", {...}), get,
// put, patch, delete: requests to this machine, in the screen's browser session), never real user
// data; screen.tenant names the tenant it opens as. It may open the screen itself with
// `await screen.open()` and then prepare it (open a dialog, fill a field); if it doesn't, capture
// opens the route after it returns. The tenant always comes from the test user's sign-in, never
// from the route or the request.
//
// Example:
//   { id: "orders", title: "Orders", route: "/orders", source: "clients/web/src/pages/OrdersPage.tsx",
//     tenant: "test-tenant-a", auth: "tenant-a-user",
//     states: {
//       default: async (page, api) => { await api.post("/api/v1/orders", { data: { customerNumber: "C1", lines: [] } }); },
//       empty: null,
//       other_tenant: { tenant: "test-tenant-b", auth: "tenant-b-user" },
//     } },

export default {
  screens: [
    // Until the product lists its screens: the web client's root route, as it opens signed out.
    { id: "home", title: "Home", route: "/" },
  ],
};
