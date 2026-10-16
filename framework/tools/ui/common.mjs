// Screen capture: settings, the catalog and paths · framework-owned: replaced on upgrade.
//
// Shared by tools/ui/capture.mjs, verify.mjs and overlay.mjs. Paths are relative to the project
// root, which is the working directory (bash tools/ui_capture.sh changes to it).

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { posix, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { URL } from "node:url";

export const CONFIG_PATH = "tools/ui_capture.cfg";
export const CHECK_CONFIG_PATH = "tools/check.cfg";
export const CATALOG_PATH = "tools/ui/screens.mjs";
export const SPECS = "product/ui";
export const CAPTURES = "product/ui/captures";
export const DRAWINGS = "director/ui";
export const AUTH_DIR = "tools/ui/.auth";
export const INSTALL_HINT = "cd tools/ui && npm install && npx playwright install chromium";
// The hosts capture opens without being told: this machine only.
export const LOCAL_HOSTS = ["localhost", "127.0.0.1", "[::1]", "::1"];
// Where Azure hosts deployed apps: refused even in [web] allow_hosts, so capture never opens prod or
// any hosted address but the one dev environment named in [web] dev_url.
export const AZURE_HOSTED = [".azurewebsites.net", ".azurestaticapps.net", ".azurefd.net", ".azureedge.net",
  ".azure-api.net", ".azurecontainerapps.io", ".cloudapp.azure.com", ".cloudapp.net", ".windows.net", ".trafficmanager.net"];
export const CATALOG_KEYS = ["id", "title", "route", "states", "tenant", "auth", "source", "animate"];
export const STATE_KEYS = ["setup", "tenant", "auth"];

// An ini file as check.cfg reads it: `[section]`, `key = value`, `;` starts a comment.
export function readIni(path) {
  const result = {};
  if (!existsSync(path)) return null;
  let section = "";
  for (const raw of readFileSync(path, "utf8").split("\n")) {
    const line = raw.replace(/\r$/, "").replace(/\s*;.*$/, "");
    const header = /^\[(.+)\]\s*$/.exec(line);
    if (header) {
      section = header[1];
      result[section] = result[section] || {};
      continue;
    }
    const eq = line.indexOf("=");
    if (eq < 0 || section === "") continue;
    result[section][line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return result;
}

function get(ini, section, key, fallback) {
  const value = ini && ini[section] ? ini[section][key] : undefined;
  return value === undefined || value === "" ? fallback : value;
}

function list(value) {
  return String(value || "").split(/\s+/).filter((item) => item !== "");
}

export function parseSize(text) {
  const match = /^(\d+)x(\d+)$/.exec(String(text).trim().toLowerCase());
  if (!match) return null;
  const size = { x: Number(match[1]), y: Number(match[2]) };
  return size.x > 0 && size.y > 0 ? size : null;
}

// tools/ui_capture.cfg, with the defaults of a missing key. problems lists what isn't valid.
export function readConfig() {
  const ini = readIni(CONFIG_PATH);
  const problems = [];
  const sizes = [];
  for (const item of list(get(ini, "sizes", "list", "1920x1080 2560x1080 1280x720"))) {
    const size = parseSize(item);
    if (size) sizes.push(size);
    else problems.push(`tools/ui_capture.cfg › [sizes] list: '${item}' isn't WxH`);
  }
  const number = (section, key, fallback) => {
    const value = Number(get(ini, section, key, fallback));
    return Number.isFinite(value) ? value : fallback;
  };
  const allowHosts = list(get(ini, "web", "allow_hosts", ""));
  const devUrl = get(ini, "web", "dev_url", "");
  let devHost = "";
  if (devUrl !== "") {
    try {
      const parsed = new URL(devUrl);
      if (parsed.protocol !== "https:" && parsed.protocol !== "http:") throw new Error("not http");
      devHost = parsed.hostname.toLowerCase();
    } catch { problems.push(`tools/ui_capture.cfg › [web] dev_url: '${devUrl}' isn't an http or https URL`); }
  }
  return {
    // The hosts capture may load besides this machine: [web] allow_hosts (this machine's own names)
    // and the dev environment's host ([web] dev_url), the only hosted address it opens.
    hosts: { allow: allowHosts.map((item) => item.toLowerCase()), dev: devHost },
    missing: ini === null,
    problems,
    sizes: sizes.length > 0 ? sizes : [{ x: 1920, y: 1080 }],
    seed: Math.trunc(number("capture", "seed", 12345)),
    settleFrames: Math.max(1, Math.trunc(number("capture", "settle_frames", 6))),
    maxElements: Math.max(1, Math.trunc(number("capture", "max_elements", 200))),
    setupTimeout: Math.max(1, number("capture", "setup_timeout", 60)),
    skip: list(get(ini, "capture", "skip", "")),
    baseUrl: get(ini, "web", "base_url", ""),
    apiUrl: get(ini, "web", "api_url", ""),
    devUrl,
    tenants: list(get(ini, "web", "tenants", "")),
    startCommand: get(ini, "web", "start_command", ""),
    readyUrl: get(ini, "web", "ready_url", ""),
    startTimeout: Math.max(1, number("web", "start_timeout", 120)),
    minLabelChars: number("lint", "min_label_chars", 6),
    maxButtonHeightRatio: number("lint", "max_button_height_ratio", 2.0),
    tolerance: number("verify", "tolerance_pct", 4.0),
  };
}

// A path pattern as check.cfg writes it: * stays within one folder name, ** crosses folders. The
// regex matches the path itself or any folder above it, so `clients/*` covers every file in a client.
export function globRegex(pattern) {
  let text = "";
  const source = pattern.replace(/\/+$/, "");
  for (let index = 0; index < source.length; index++) {
    const char = source[index];
    if (char === "*" && source[index + 1] === "*") {
      index++;
      if (source[index + 1] === "/") { index++; text += "(?:.*/)?"; } else text += ".*";
    } else if (char === "*") text += "[^/]*";
    else if (char === "?") text += "[^/]";
    else text += char.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${text}(?:/.*)?$`);
}

// tools/check.cfg: the stack, the client layer's path patterns (the screen folders) and the paths
// the check never reads.
export function readCheckConfig() {
  const ini = readIni(CHECK_CONFIG_PATH);
  const stack = get(ini, "project", "stack", "");
  return {
    stack: stack.startsWith("{{") ? "" : stack,
    uiDirs: list(get(ini, "layers", "client", "")).filter((dir) => !dir.includes("{{")),
    skip: list(get(ini, "scan", "skip", "**/bin **/obj **/node_modules **/dist **/.venv **/__pycache__")),
  };
}

// The source files of the client layer (tools/check.cfg › [layers] client), outside [scan] skip,
// sorted, with / separators. Without client patterns: every source file outside product/, director/,
// tools/ and tests/ when `everywhere` is set, else none.
export function clientFiles(sourceFile, everywhere = false) {
  const check = readCheckConfig();
  const skips = check.skip.map(globRegex);
  const patterns = check.uiDirs.map(globRegex);
  const roots = new Set();
  for (const dir of check.uiDirs) {
    const literal = [];
    for (const part of dir.replace(/\/+$/, "").split("/")) { if (/[*?]/.test(part)) break; literal.push(part); }
    roots.add(literal.length > 0 ? literal.join("/") : ".");
  }
  if (check.uiDirs.length === 0 && everywhere) roots.add(".");
  const found = new Set();
  const visit = (dir) => {
    let names;
    try { names = readdirSync(dir).sort(); } catch { return; }
    for (const name of names) {
      if (name.startsWith(".") || name === "node_modules") continue;
      const path = dir === "." ? name : posix.join(dir, name);
      if (skips.some((skip) => skip.test(path))) continue;
      if (dir === "." && check.uiDirs.length === 0 && ["product", "director", "tools", "tests", "test", "infra", "adr"].includes(name)) continue;
      let stats;
      try { stats = statSync(path); } catch { continue; }
      if (stats.isDirectory()) visit(path);
      else if (sourceFile.test(name) && stats.size < 2000000 && (patterns.length === 0 || patterns.some((pattern) => pattern.test(path)))) found.add(path);
    }
  };
  for (const root of roots) visit(root);
  return { dirs: check.uiDirs, files: [...found].sort() };
}

// The host of a URL when capture may open it, else ok false with the reason. hosts is config.hosts:
// this machine, a name for it in [web] allow_hosts that Azure doesn't host, or exactly the dev
// environment's host ([web] dev_url), which is the one hosted address capture opens (env "dev").
export function localHost(url, hosts) {
  let parsed;
  try { parsed = new URL(url); } catch { return { ok: false, reason: `'${url}' isn't a URL` }; }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return { ok: false, reason: `'${url}' isn't http or https` };
  const host = parsed.hostname.toLowerCase();
  if (hosts.dev !== "" && host === hosts.dev) return { ok: true, host, env: "dev" };
  if (LOCAL_HOSTS.includes(host)) return { ok: true, host, env: "local" };
  if (AZURE_HOSTED.some((suffix) => host.endsWith(suffix))) {
    return { ok: false, reason: `${host} is a hosted environment on Azure and isn't [web] dev_url; capture opens only this machine and the dev environment, never prod` };
  }
  if (hosts.allow.includes(host)) return { ok: true, host, env: "local" };
  return { ok: false, reason: `${host} isn't this machine (localhost, 127.0.0.1), a name for it in tools/ui_capture.cfg › [web] allow_hosts, or the dev environment ([web] dev_url); capture never opens prod or another hosted site` };
}

// An [web] allow_hosts entry is a name for this machine or the local network: every address it
// resolves to (looked up once) is loopback or private. Returns the problems.
export async function checkAllowHosts(hosts) {
  const { lookup } = await import("node:dns/promises");
  const privateAddress = (address) => /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|::1$|f[cd][0-9a-f]{2}:|fe80:|::ffff:127\.)/i.test(address);
  const problems = [];
  for (const host of hosts.allow) {
    if (host === hosts.dev || LOCAL_HOSTS.includes(host)) continue;
    let addresses;
    try { addresses = (await lookup(host, { all: true })).map((entry) => entry.address); } catch { addresses = []; }
    if (addresses.length === 0) problems.push(`[web] allow_hosts: ${host} doesn't resolve; it lists names for this machine only`);
    else if (!addresses.every(privateAddress)) problems.push(`[web] allow_hosts: ${host} resolves to ${addresses.join(", ")}, which isn't this machine or a private address; it lists names for this machine only (the dev environment goes in [web] dev_url)`);
  }
  return problems;
}

// What a state opens as: a seeded test tenant's test user ({tenant, auth}), or signed out (both "").
function access(where, tenant, auth, tenants, problems) {
  if (tenant !== undefined && (typeof tenant !== "string" || !/^[A-Za-z0-9_.-]+$/.test(tenant))) problems.push(`${where}tenant names a seeded test tenant (letters, digits, _, . or -)`);
  if (auth !== undefined && (typeof auth !== "string" || !/^[A-Za-z0-9_-]+$/.test(auth))) problems.push(`${where}auth names a test user's saved sign-in in tools/ui/.auth/ (letters, digits, _ or -)`);
  const result = { tenant: typeof tenant === "string" ? tenant : "", auth: typeof auth === "string" ? auth : "" };
  if ((result.tenant === "") !== (result.auth === "")) {
    problems.push(`${where}a tenant's screen opens signed in as a test user of that tenant: give both tenant and auth, or neither for a signed-out screen`);
  } else if (result.tenant !== "" && !tenants.includes(result.tenant)) {
    problems.push(tenants.length === 0
      ? `${where}tenant '${result.tenant}' isn't a seeded test tenant: list the test tenants seeded on this machine in tools/ui_capture.cfg › [web] tenants`
      : `${where}tenant '${result.tenant}' isn't in tools/ui_capture.cfg › [web] tenants (${tenants.join(", ")}): capture opens seeded test tenants only`);
  }
  return result;
}

// The catalog: {baseUrl, entries, errors}. Each entry is {id, title, route, states: {name: fn|null},
// access: {name: {tenant, auth}}, source, animate}. An entry with a problem is left out and named in
// errors. tenants: the seeded test tenants ([web] tenants).
export async function loadCatalog(tenants = []) {
  if (!existsSync(CATALOG_PATH)) return { baseUrl: "", entries: [], errors: [`no ${CATALOG_PATH}; the installer creates it (rerun install.sh)`] };
  let module;
  try {
    module = await import(pathToFileURL(resolve(CATALOG_PATH)).href);
  } catch (error) {
    return { baseUrl: "", entries: [], errors: [`${CATALOG_PATH} doesn't load: ${error && error.message ? error.message : error}`] };
  }
  const catalog = module.default;
  if (!catalog || typeof catalog !== "object" || !Array.isArray(catalog.screens)) {
    return { baseUrl: "", entries: [], errors: [`${CATALOG_PATH} must export default { screens: [...] }`] };
  }
  const errors = [];
  const entries = [];
  const seen = new Set();
  catalog.screens.forEach((screen, index) => {
    const where = `${CATALOG_PATH} entry ${index + 1}`;
    if (!screen || typeof screen !== "object") { errors.push(`${where} isn't an object`); return; }
    const id = typeof screen.id === "string" ? screen.id : "";
    const problems = [];
    for (const key of Object.keys(screen)) if (!CATALOG_KEYS.includes(key)) problems.push(`unknown key '${key}' (keys: ${CATALOG_KEYS.join(", ")})`);
    if (!/^[A-Za-z0-9_-]+$/.test(id)) problems.push("its id must be letters, digits, _ or - (it names the files)");
    else if (seen.has(id)) problems.push(`the id '${id}' is used twice`);
    if (typeof screen.title !== "string" || screen.title.trim() === "") problems.push("it has no title");
    if (typeof screen.route !== "string" || !screen.route.startsWith("/")) problems.push("its route must be a path such as \"/orders\"");
    if (screen.source !== undefined && typeof screen.source !== "string") problems.push("source is the file that renders the screen");
    const entryProblems = [];
    const entryAccess = access("", screen.tenant, screen.auth, tenants, entryProblems);
    let states = { default: null };
    const accessOf = { default: entryAccess };
    if (screen.states === undefined) problems.push(...entryProblems);
    else if (!screen.states || typeof screen.states !== "object" || Object.keys(screen.states).length === 0) problems.push("states must name at least one state");
    else {
      states = {};
      let entryUsed = false;
      for (const [name, value] of Object.entries(screen.states)) {
        if (!/^[A-Za-z0-9_-]+$/.test(name)) { problems.push(`the state '${name}' must be letters, digits, _ or -`); continue; }
        // A state is a function (page, api, screen), null, or { setup, tenant, auth } for a state
        // that opens as another seeded test tenant's user than the entry's.
        if (value !== null && typeof value === "object" && !Array.isArray(value)) {
          for (const key of Object.keys(value)) if (!STATE_KEYS.includes(key)) problems.push(`the state '${name}' has an unknown key '${key}' (keys: ${STATE_KEYS.join(", ")})`);
          if (value.setup !== undefined && value.setup !== null && typeof value.setup !== "function") problems.push(`the state '${name}': setup must be a function (page, api, screen) or null`);
          const own = value.tenant !== undefined || value.auth !== undefined;
          // A state that names either its tenant or its sign-in names both: one tenant's user never
          // opens as another tenant.
          if (own) accessOf[name] = access(`the state '${name}': `, value.tenant, value.auth, tenants, problems);
          else { accessOf[name] = entryAccess; entryUsed = true; }
          states[name] = typeof value.setup === "function" ? value.setup : null;
        } else if (value !== null && typeof value !== "function") problems.push(`the state '${name}' must be a function (page, api, screen), null, or { setup, tenant, auth }`);
        else { states[name] = value; accessOf[name] = entryAccess; entryUsed = true; }
      }
      if (entryUsed) problems.push(...entryProblems);
    }
    if (id !== "") seen.add(id);
    if (problems.length > 0) {
      errors.push(`${id || where}: ${problems.join("; ")}`);
      return;
    }
    entries.push({ id, title: screen.title, route: screen.route, states, access: accessOf, source: screen.source || "", animate: Boolean(screen.animate) });
  });
  return { baseUrl: typeof catalog.baseUrl === "string" ? catalog.baseUrl : "", entries, errors };
}

// `<id>[.<state>]@<W>x<H>`: the name of a capture's files.
export function captureName(id, state, size) {
  return `${id}${state === "default" ? "" : "." + state}@${size.x}x${size.y}`;
}

// True for `<screen>@<W>x<H>` and `<screen>.<state>@<W>x<H>`, not for another screen whose id starts the same.
export function isCaptureOf(stem, screen) {
  if (!stem.startsWith(screen) || !stem.includes("@")) return false;
  const rest = stem.substring(screen.length);
  return rest.startsWith("@") || (rest.startsWith(".") && !rest.split("@")[0].substring(1).includes("."));
}

// A number as the reports write it: one decimal, without a trailing ".0".
export function n1(value) {
  const text = (Math.round(value * 10) / 10).toFixed(1);
  return text.endsWith(".0") ? text.slice(0, -2) : text;
}
