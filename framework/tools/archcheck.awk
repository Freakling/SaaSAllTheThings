# SaaSAllTheThings architecture rules · framework-owned: replaced on upgrade.
#
#   awk -v cfg=tools/check.cfg -v files=<list> -v adrs=<list> -v secrets=<git grep -n output> \
#       -v logfile=<full log> -f tools/archcheck.awk
#
# Run by tools/check.sh. Reads the layers from tools/check.cfg and applies the rules listed in
# .satt/reference/README.md › What the check enforces to every source file in a layer, and the
# secrets and cost-sku rules to every file. A violation is excused only by an
#   - Exception: <rule> <path pattern>
# line in an ADR (adr/ADR-<n>-*.md) whose status is accepted.
# Prints the report as "check: …" lines (at most 60 violations; all of them go to the log), and
# exits 1 when anything fails. It reads text: comments are skipped, strings aren't.
# Portable awk only (BSD awk, mawk, gawk): no match() arrays, no {n} intervals, no ENDFILE.

BEGIN {
  rules = "layers domain-purity tenant-source tenant-branching secrets file-size host-size message-version cost-sku"
  split(rules, words, " "); for (i in words) known_rule[words[i]] = 1
  layers = "contracts domain application infrastructure integration host platform client tests"
  nlayers = split(layers, layer_list, " "); for (i in layer_list) known_layer[layer_list[i]] = 1

  # What each layer may depend on: reference/layers.md › Dependencies. Deliberately not configurable.
  may("application", "domain contracts")
  may("infrastructure", "application domain contracts")
  may("integration", "application contracts")
  may("host", "application infrastructure integration contracts")
  may("platform", "application infrastructure contracts")
  may("client", "contracts")

  # domain-purity: the clock, ids, randomness, the environment and I/O, per language.
  pure["cs"] = "DateTime(Offset)?\\.(Now|UtcNow|Today)|Guid\\.NewGuid|new[ \t]+Random[ \t]*\\(|Random\\.Shared|Environment\\.(GetEnvironmentVariable|ExpandEnvironmentVariables|TickCount|MachineName|UserName)|HttpClient|WebRequest|(^|[^A-Za-z0-9_.])(File|Directory)\\.[A-Z]|Console\\.|Thread\\.Sleep|Stopwatch\\.|TimeProvider\\.System"
  pure["vb"] = pure["cs"]; pure["fs"] = pure["cs"]
  pure["js"] = "Date\\.now[ \t]*\\(|new[ \t]+Date[ \t]*\\([ \t]*\\)|Math\\.random|randomUUID|(^|[^A-Za-z0-9_.$])fetch[ \t]*\\(|XMLHttpRequest|process\\.env|(from|require[ \t]*\\()[ \t]*[\"'](node:)?(fs|fs/promises|http|https|net|child_process)[\"']|console\\.|setTimeout[ \t]*\\(|setInterval[ \t]*\\("
  pure["py"] = "(datetime|date)\\.(now|utcnow|today)[ \t]*\\(|time\\.(time|time_ns|monotonic|sleep)[ \t]*\\(|uuid[14][ \t]*\\(|(^|[^A-Za-z0-9_.])random\\.|os\\.environ|os\\.getenv|(^|[^A-Za-z0-9_.])(requests|httpx|aiohttp|socket|subprocess)\\.|urllib\\.request|(^|[^A-Za-z0-9_.])open[ \t]*\\(|(^|[^A-Za-z0-9_.])print[ \t]*\\(|^[ \t]*(from|import)[ \t]+(random|os|time|socket|subprocess|requests|httpx|aiohttp|urllib)([ \t.,]|$)"
  pure["jvm"] = "(LocalDate|LocalDateTime|LocalTime|Instant|ZonedDateTime|OffsetDateTime)\\.now[ \t]*\\(|Clock\\.system|UUID\\.randomUUID|new[ \t]+Random[ \t]*\\(|Math\\.random|System\\.(getenv|getProperty|currentTimeMillis|nanoTime|out|err)|HttpClient|java\\.io\\.File|java\\.nio\\.file"

  # tenant-source: request accessors that name a tenant, and route templates with a tenant segment.
  from_request = "(^|[^a-z0-9])(headers|header|query|querystring|routevalues|params|args|form|bindingdata)[^;]*(\\[|\\(|\\.)[ \t]*[\"']?[a-z_-]*tenant"
  from_route = "route[ \t]*[=:][ \t]*[\"'][^\"']*\\{[a-z_]*tenant"
  # tenant-branching: an expression naming a tenant (tenant, tenantId, tenant.Id.ToString(), …)
  # compared with a literal; comparing a tenant's attribute (its status, plan, region…) is fine.
  chain = "[a-z0-9_.()]*"
  branch[1] = "tenant" chain "[ \t]*(==|!=)=?[ \t]*[\"'][^\"']"
  branch[2] = "[\"'][^\"']+[\"'][ \t]*(==|!=)=?[ \t]*[a-z0-9_.]*tenant" chain
  branch[3] = "tenant" chain "[ \t]*(==|!=)[ \t]*guid\\.parse"
  branch[4] = "tenant" chain "\\.equals[ \t]*\\([ \t]*[\"']"
  attrs = "(status|state|plan|tier|role|type|kind|mode|region|stamp|country|culture|language|locale|currency|timezone)"
  tenant_attr = "tenant[a-z0-9_]*" attrs "|\\." attrs

  # Python modules the domain and contracts may import (domain-purity reports the I/O ones).
  split("__future__ abc collections copy dataclasses datetime decimal enum fractions functools itertools math numbers operator re string textwrap types typing typing_extensions uuid", words, " ")
  for (i in words) py_std[words[i]] = 1
  split("random os time socket subprocess requests httpx aiohttp urllib", words, " ")
  for (i in words) py_io[words[i]] = 1

  # The emulators' public, well-known keys are not secrets.
  public_key[1] = "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
  public_key[2] = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="

  max_lines = 300; host_max_lines = 80
  read_cfg()
  read_adrs()
  if (files != "") {
    while ((getline path < files) > 0) consider(path)
    close(files)
  }
  read_secrets()
  report()
  exit (fails > 0)
}

function may(from, tos,   n, t, i) {
  n = split(tos, t, " ")
  for (i = 1; i <= n; i++) allowed[from, t[i]] = 1
}

function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }

function note(msg) { notes[++note_n] = "ARCH-NOTE: " msg }

function fail(rule, file, line, msg,   i) {
  for (i = 1; i <= exc_n; i++) {
    if (exc_rule[i] == rule && file ~ exc_re[i]) { exc_used[i]++; excused++; return }
  }
  fails++
  failure[fails] = "ARCH-FAIL: [" rule "] " file (line > 0 ? ":" line : "") ": " msg
}

# A path pattern as an anchored regex: * stays within a folder name, ** crosses folders, and a
# pattern matches the path itself or anything below it.
function glob_re(g,   out, i, n, c) {
  out = "^"; n = length(g)
  for (i = 1; i <= n; i++) {
    c = substr(g, i, 1)
    if (c == "*") {
      if (substr(g, i + 1, 1) == "*") {
        if (substr(g, i + 2, 1) == "/") { out = out "(.*/)?"; i += 2 } else { out = out ".*"; i++ }
      } else out = out "[^/]*"
    } else if (c == "?") out = out "[^/]"
    else if (index(".+()^$|{}[]\\", c) > 0) out = out "\\" c
    else out = out c
  }
  return out "(/.*)?$"
}

function dirname(p) { if (sub(/\/[^\/]*$/, "", p)) return p; return "" }

# Resolve . and .. segments, with / as the separator.
function norm(p,   n, parts, i, k, stack, out) {
  gsub(/\\/, "/", p)
  n = split(p, parts, "/"); k = 0
  for (i = 1; i <= n; i++) {
    if (parts[i] == "" || parts[i] == ".") continue
    if (parts[i] == "..") { if (k > 0) k--; continue }
    stack[++k] = parts[i]
  }
  out = ""
  for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") stack[i]
  return out
}

function read_cfg(   line, section, eq, key, value, n, parts, i) {
  if (cfg == "" || (getline line < cfg) <= 0) { note("tools/check.cfg is missing or empty, so no file is in a layer"); return }
  do {
    sub(/\r$/, "", line)
    if (line ~ /^[ \t]*([;#].*)?$/) continue
    if (line ~ /^[ \t]*\[.*\][ \t]*$/) { section = trim(line); gsub(/[][]/, "", section); continue }
    eq = index(line, "=")
    if (eq == 0) continue
    key = trim(substr(line, 1, eq - 1)); value = trim(substr(line, eq + 1))
    if (section == "layers" || section == "imports") {
      if (!(key in known_layer)) { fail("config", "tools/check.cfg", 0, "[" section "] names '" key "', which isn't a layer (" layers ")"); continue }
      n = split(value, parts, "[ \t]+")
      for (i = 1; i <= n; i++) {
        if (parts[i] == "" || parts[i] ~ /\{\{/) continue
        if (section == "layers") { lay_n++; lay_name[lay_n] = key; lay_glob[lay_n] = parts[i]; lay_re[lay_n] = glob_re(parts[i]) }
        else { imp_n++; imp_layer[imp_n] = key; imp_name[imp_n] = parts[i] }
      }
    } else if (section == "limits") {
      if (key == "max_lines" && value ~ /^[0-9]+$/) max_lines = value + 0
      else if (key == "host_max_lines" && value ~ /^[0-9]+$/) host_max_lines = value + 0
    } else if (section == "scan" && key == "skip") {
      n = split(value, parts, "[ \t]+")
      for (i = 1; i <= n; i++) if (parts[i] != "") skip_re[++skip_n] = glob_re(parts[i])
    }
  } while ((getline line < cfg) > 0)
  close(cfg)
}

# ADRs: the status, and the exceptions of accepted ones.
function read_adrs(   file, id, line, status, e, pending, np, k, n, parts) {
  if (adrs == "") return
  while ((getline file < adrs) > 0) {
    sub(/\r$/, "", file)
    id = file; sub(/^.*\//, "", id)
    if (!match(id, /^ADR-[0-9]+/)) { note(file " isn't named ADR-<n>-<slug>.md, so it's ignored"); continue }
    id = substr(id, 1, RLENGTH)
    status = ""; np = 0
    while ((getline line < file) > 0) {
      sub(/\r$/, "", line)
      if (status == "" && line ~ /^[ \t>*_-]*Status[*_ \t]*:/) {
        status = line; sub(/^[^:]*:/, "", status); gsub(/[*_]/, "", status); status = tolower(trim(status))
      }
      if (line ~ /^[ \t]*[-*][ \t]+Exception:/) { e = line; sub(/^[^:]*:[ \t]*/, "", e); pending[++np] = trim(e) }
    }
    close(file)
    adr_n++
    if (status == "accepted") {
      accepted_n++
      for (k = 1; k <= np; k++) {
        n = split(pending[k], parts, "[ \t]+")
        if (n < 2) { fail("config", file, 0, "an exception needs a rule and a path pattern: '" pending[k] "'"); continue }
        if (!(parts[1] in known_rule)) { fail("config", file, 0, "an exception names '" parts[1] "', which isn't a rule (" rules ")"); continue }
        if (parts[2] ~ /^\*\*?$/ || parts[2] ~ /^\*\*\/\*?$/) { fail("config", file, 0, "an exception must name a folder or file, not every path: '" pending[k] "'"); continue }
        exc_n++; exc_rule[exc_n] = parts[1]; exc_glob[exc_n] = parts[2]; exc_re[exc_n] = glob_re(parts[2]); exc_adr[exc_n] = id
      }
    } else if (status == "proposed") {
      note(id " is proposed and waits for the human" (np ? "; its exceptions apply once it's accepted" : ""))
    } else if (status == "") {
      fail("config", file, 0, "no Status line (proposed, accepted, rejected or superseded by ADR-<n>)")
    }
  }
  close(adrs)
}

function layer_index(p,   i) {
  for (i = 1; i <= lay_n; i++) if (p ~ lay_re[i]) return i
  return 0
}

# The layer an import names, by the longest matching [imports] name.
function layer_by_name(t,   i, best, len, n) {
  best = ""; len = 0
  for (i = 1; i <= imp_n; i++) {
    n = imp_name[i]
    if (length(n) <= len) continue
    if (t == n || (index(t, n) == 1 && index("./:", substr(t, length(n) + 1, 1)) > 0)) { best = imp_layer[i]; len = length(n) }
  }
  return best
}

function lang_of(f,   e) {
  e = f; sub(/^.*\//, "", e)
  if (index(e, ".") == 0) return ""
  sub(/^.*\./, "", e); e = tolower(e)
  if (e == "cs" || e == "vb" || e == "fs") return e
  if (e ~ /^(ts|tsx|js|jsx|mjs|cjs|mts|cts)$/) return "js"
  if (e == "py") return "py"
  if (e ~ /^(java|kt|kts)$/) return "jvm"
  if (e == "dart" || e == "swift") return e
  if (e ~ /^(csproj|vbproj|fsproj)$/) return "proj"
  if (e == "bicep") return "bicep"
  return ""
}

function consider(path,   i, lang, k, layer) {
  sub(/\r$/, "", path)
  if (path == "" || (path in seen)) return
  seen[path] = 1
  for (i = 1; i <= skip_n; i++) if (path ~ skip_re[i]) return
  lang = lang_of(path)
  if (lang == "") return
  if (lang == "bicep") { scan_bicep(path); return }
  k = layer_index(path)
  if (k == 0) { if (lang != "proj") outside++; return }
  layer = lay_name[k]; lay_hit[k]++
  if (lang == "proj") { scan_proj(path, layer); return }
  in_layer++; layer_count[layer]++
  scan_source(path, lang, layer)
}

# Comments out; C-family block comments may span lines (in_block).
function strip(line, lang,   at, rest) {
  if (lang == "py") { sub(/#.*$/, "", line); return line }
  if (lang == "vb") { sub(/'.*$/, "", line); return line }
  if (in_block) {
    at = index(line, "*/")
    if (at == 0) return ""
    line = substr(line, at + 2); in_block = 0
  }
  while ((at = index(line, "/*")) > 0) {
    rest = substr(line, at + 2)
    if (index(rest, "*/") > 0) line = substr(line, 1, at - 1) " " substr(rest, index(rest, "*/") + 2)
    else { line = substr(line, 1, at - 1); in_block = 1; break }
  }
  sub(/\/\/.*$/, "", line)
  return line
}

function lead_name(t) {
  if (match(t, /^[A-Za-z_][A-Za-z0-9_.]*/)) return substr(t, RSTART, RLENGTH)
  return ""
}

function quoted_import(line,   t) {
  if (match(line, /from[ \t]+["'][^"']+["']/) || match(line, /^[ \t]*(import|export)[ \t]+["'][^"']+["']/) \
      || match(line, /(require|import)[ \t]*\([ \t]*["'][^"']+["']/)) {
    t = substr(line, RSTART, RLENGTH); sub(/^[^"']*["']/, "", t); sub(/["'].*$/, "", t)
    return t
  }
  return ""
}

# What a line imports (a namespace, package, module or relative path), or "".
function import_of(line, lang,   t) {
  if (lang == "cs") {
    if (line !~ /^[ \t]*(global[ \t]+)?using[ \t]+[A-Za-z_]/ || line ~ /^[ \t]*using[ \t]+(var|await)[ \t]/ || line !~ /;[ \t]*$/) return ""
    t = line; sub(/^[ \t]*(global[ \t]+)?using[ \t]+(static[ \t]+)?/, "", t)
    if (t ~ /=/) sub(/^[^=]*=[ \t]*/, "", t)
    return lead_name(t)
  }
  if (lang == "vb") {
    if (line !~ /^[ \t]*[Ii]mports[ \t]+/) return ""
    t = line; sub(/^[ \t]*[Ii]mports[ \t]+/, "", t)
    if (t ~ /=/) sub(/^[^=]*=[ \t]*/, "", t)
    return lead_name(t)
  }
  if (lang == "fs") {
    if (line !~ /^[ \t]*open[ \t]+/) return ""
    t = line; sub(/^[ \t]*open[ \t]+/, "", t); return lead_name(t)
  }
  if (lang == "js" || lang == "dart") return quoted_import(line)
  if (lang == "py") {
    if (line ~ /^[ \t]*from[ \t]+[.A-Za-z_]/) { t = line; sub(/^[ \t]*from[ \t]+/, "", t); sub(/[ \t].*$/, "", t); return t }
    if (line ~ /^[ \t]*import[ \t]+[A-Za-z_]/) { t = line; sub(/^[ \t]*import[ \t]+/, "", t); return lead_name(t) }
    return ""
  }
  if (lang == "jvm") {
    if (line !~ /^[ \t]*import[ \t]+/) return ""
    t = line; sub(/^[ \t]*import[ \t]+(static[ \t]+)?/, "", t); return lead_name(t)
  }
  if (lang == "swift") {
    if (line !~ /^[ \t]*import[ \t]+/) return ""
    t = line; sub(/^[ \t]*import[ \t]+((typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?/, "", t)
    return lead_name(t)
  }
  return ""
}

function external(lang, t,   top) {
  if (lang == "js") return 1
  if (lang == "py") { top = t; sub(/\..*$/, "", top); return !(top in py_std) && !(top in py_io) }
  return 0
}

function check_import(f, n, layer, lang, t,   target, k) {
  if (t ~ /^\.\.?\//) { k = layer_index(norm(dirname(f) "/" t)); target = (k ? lay_name[k] : "") }
  else if (t ~ /^[.\/]/) return
  else target = layer_by_name(t)
  if (target == "") {
    if ((layer == "domain" || layer == "contracts") && external(lang, t)) fail("layers", f, n, layer " takes no external packages (imports " t ")")
    return
  }
  if (target != layer && !((layer, target) in allowed)) fail("layers", f, n, layer " must not depend on " target " (imports " t ")")
}

function clip(s) { sub(/^[^A-Za-z_]+/, "", s); return s }

function names_tenant(low,   i) {
  if (!index(low, "tenant")) return 0
  for (i = 1; i <= 4; i++)
    if (match(low, branch[i]) && substr(low, RSTART, RLENGTH) !~ tenant_attr) return 1
  return 0
}

function decl_name(line, lang,   s, kw) {
  if (lang == "py") kw = "class"
  else if (lang == "js") kw = "interface|type|class|enum"
  else kw = "record|class|struct|interface|enum|object"
  s = line
  gsub(/record[ \t]+(struct|class)/, "record", s)
  gsub(/data[ \t]+class/, "class", s)
  if (!match(s, "(^|[^A-Za-z0-9_.])(" kw ")[ \t]+[A-Za-z_$][A-Za-z0-9_$]*")) return ""
  s = substr(s, RSTART, RLENGTH)
  sub(/^[^A-Za-z]+/, "", s)
  sub(/^[a-z]+[ \t]+/, "", s)
  return s
}

function scan_source(f, lang, layer,   raw, line, low, n, t, name, msgdir, apidir) {
  in_block = 0; n = 0
  msgdir = (layer == "contracts" && tolower(f) ~ /(^|\/)(events|commands)\//)
  apidir = (layer == "contracts" && tolower(f) ~ /(^|\/)api\//)
  while ((getline raw < f) > 0) {
    n++
    line = strip(raw, lang)
    if (line ~ /^[ \t]*$/) continue
    low = tolower(line)
    if (layer != "tests") {
      t = import_of(line, lang)
      if (t != "") check_import(f, n, layer, lang, t)
    }
    if (layer == "domain" && (lang in pure) && match(line, pure[lang]))
      fail("domain-purity", f, n, "the domain gets time, ids, randomness, settings and I/O as inputs (" clip(substr(line, RSTART, RLENGTH)) ")")
    if (layer == "host" && (low ~ from_request || low ~ from_route))
      fail("tenant-source", f, n, "the tenant comes from the validated token, never from the request")
    if (apidir && low ~ /(^|[^a-z0-9_])tenant_?id([^a-z0-9_]|$)/)
      fail("tenant-source", f, n, "API contracts never carry the tenant: the host takes it from the token")
    if (layer != "tests" && layer != "platform" && names_tenant(low))
      fail("tenant-branching", f, n, "tenants differ by registry data and plans, never by code that names one")
    if (msgdir) {
      name = decl_name(line, lang)
      if (name != "" && name !~ /V[0-9]+$/) fail("message-version", f, n, "events and commands are versioned: name it " name "V1")
    }
  }
  close(f)
  if (layer == "tests") return
  if ((layer == "host" || layer == "platform") && n > host_max_lines)
    fail("host-size", f, 0, n " lines, over " host_max_lines ": a function stays thin, so move the work into a handler")
  else if (n > max_lines)
    fail("file-size", f, 0, n " lines, over " max_lines ": split it by responsibility")
}

# .NET project files: project references between layers, and packages in domain and contracts.
function scan_proj(f, layer,   raw, n, inc, k, target) {
  n = 0
  while ((getline raw < f) > 0) {
    n++
    if (layer == "tests") continue
    if (raw ~ /<ProjectReference[^>]*Include="/) {
      inc = raw; sub(/^.*Include="/, "", inc); sub(/".*$/, "", inc)
      k = layer_index(norm(dirname(f) "/" inc)); target = (k ? lay_name[k] : "")
      if (target != "" && target != layer && !((layer, target) in allowed))
        fail("layers", f, n, layer " must not depend on " target " (references " norm(dirname(f) "/" inc) ")")
    }
    if ((layer == "domain" || layer == "contracts") && raw ~ /<PackageReference[^>]*Include="/) {
      inc = raw; sub(/^.*Include="/, "", inc); sub(/".*$/, "", inc)
      fail("layers", f, n, layer " takes no external packages (" inc ")")
    }
  }
  close(f)
}

function scan_bicep(f,   raw, line, low, n) {
  n = 0
  while ((getline raw < f) > 0) {
    n++
    line = raw; sub(/\/\/.*$/, "", line); low = tolower(line)
    if (low ~ /["'](premium[a-z0-9_]*|isolated[a-z0-9_]*|ep[1-3]|p[0-9]+m?v[0-9])["']/ || low ~ /(^|[^a-z])throughput[ \t]*:/ || low ~ /autoscalesettings/)
      fail("cost-sku", f, n, "above the cost defaults (.satt/reference/cost.md): that's an ADR with the monthly cost")
  }
  close(f)
  bicep_n++
  if (n > max_lines) fail("file-size", f, 0, n " lines, over " max_lines ": one module per resource")
}

# git grep -n output: path:line:text. The text is never printed.
function read_secrets(   line, p, rest, ln, i, skip) {
  if (secrets == "") return
  while ((getline line < secrets) > 0) {
    if (index(line, public_key[1]) || index(line, public_key[2])) continue
    p = substr(line, 1, index(line, ":") - 1); rest = substr(line, index(line, ":") + 1)
    ln = substr(rest, 1, index(rest, ":") - 1)
    skip = 0
    for (i = 1; i <= skip_n; i++) if (p ~ skip_re[i]) skip = 1
    if (!skip) fail("secrets", p, ln + 0, "this looks like a secret. If it's real it's exposed: rotate it, remove it, and use a managed identity or a Key Vault reference (reference/identity.md › No secrets)")
  }
  close(secrets)
}

# Prints the report as check.sh shows it, and writes the full log to the file `logfile` if given.
function emit(line) { print line; if (logfile != "") print line > logfile }
function report(   i, counts, unused, shown) {
  counts = ""
  for (i = 1; i <= nlayers; i++)
    if (layer_count[layer_list[i]]) counts = counts (counts == "" ? "" : " · ") layer_list[i] " " layer_count[layer_list[i]]
  if (in_layer == 0 && lay_n > 0) note("no source files in any layer yet")
  emit("check: architecture: " in_layer " source files in layers" (counts == "" ? "" : " (" counts ")") \
    (outside ? "; " outside " outside every layer, not checked" : "") (bicep_n ? "; " bicep_n " Bicep files" : ""))
  if (adr_n) emit("check: architecture: " adr_n " ADRs, " accepted_n + 0 " accepted; " exc_n + 0 " exceptions, " excused + 0 " violations excused")
  for (i = 1; i <= exc_n; i++)
    if (!exc_used[i]) note(exc_adr[i] "'s exception '" exc_rule[i] " " exc_glob[i] "' excuses nothing now: once the deviation is gone, supersede the ADR or drop the line")
  unused = ""
  if (in_layer > 0) for (i = 1; i <= lay_n; i++) if (!lay_hit[i]) unused = unused (unused == "" ? "" : ", ") lay_name[i] " = " lay_glob[i]
  if (unused != "") note("[layers] patterns that match no file yet: " unused)
  for (i = 1; i <= note_n; i++) { sub(/^ARCH-NOTE: /, "check: note: ", notes[i]); emit(notes[i]) }
  if (fails) {
    emit("check: architecture violations (only an accepted ADR in adr/ excuses one; see .satt/procedures/architect.md):")
    shown = (fails > 60 ? 60 : fails)
    for (i = 1; i <= fails; i++) {
      sub(/^ARCH-FAIL: /, "  ", failure[i])
      if (i <= shown) print failure[i]
      if (logfile != "") print failure[i] > logfile
    }
    if (fails > shown) print "  … and " (fails - shown) " more (all of them in " logfile ")"
  }
  emit(fails ? "check: architecture: FAIL: " fails " violations" : "check: architecture: PASS")
  if (logfile != "") close(logfile)
}
