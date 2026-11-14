# SaaSAllTheThings stack profile: .NET · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh. A profile defines:
#   stack_toolchain   finds the toolchain and prints one line; returns 0, or 3 when it's missing
#   stack_setup       restores dependencies once per clone (setup-clone.sh)
#   stack_check       builds and tests; prints check: lines; returns 0 pass, 1 fail, 3 couldn't run
# It may use $state (the log folder) and $cfg_target (tools/check.cfg › [project] target).
# The build covers the whole target in both tiers. In the fast tier the test step covers only the test projects the
# change reaches: the changed projects and the projects that reference them, within the target (dn_test).

stack_target() {
  local f
  if [ -n "$cfg_target" ]; then printf '%s' "$cfg_target"; return; fi
  for f in *.slnx *.sln; do [ -f "$f" ] && { printf '%s' "$f"; return; }; done
}

stack_toolchain() {
  if ! command -v dotnet >/dev/null 2>&1; then
    echo "check: can't find dotnet. Install the .NET SDK 8 or newer, then run: bash tools/setup-clone.sh"
    return 3
  fi
  stack_version="$(dotnet --version 2>/dev/null </dev/null | tr -d '\r' | tail -n 1)"
  local major="${stack_version%%.*}"
  case "$major" in ''|*[!0-9]*) echo "check: couldn't read the .NET SDK version ('$stack_version')"; return 3 ;; esac
  if [ "$major" -lt 8 ]; then echo "check: needs the .NET SDK 8 or newer; found $stack_version"; return 3; fi
  echo "check: .NET SDK $stack_version"
}

stack_setup() {
  local target; target="$(stack_target)"
  [ -n "$target" ] || return 0
  echo "setup: dotnet restore $target"
  dotnet restore "$target" -nologo -v:q </dev/null >"$state/restore.log" 2>&1
}

# The fast tier's test selection: one awk call reads the project files tracked in git (*.csproj, *.fsproj and *.vbproj,
# not under bin, obj, node_modules or .git) with the projects their ProjectReference entries name, the projects of the
# target (-v target: a solution's quoted project paths, or a project file and what it references), and the changed
# backend paths on stdin (the lines of CHECK_BACKEND_CHANGED). A test project is one whose file has the Microsoft.NET.Test.Sdk
# package, <IsTestProject>true, Sdk="MSTest.Sdk", or a package reference to xunit, xunit.v3, NUnit, MSTest,
# MSTest.TestFramework, TUnit or a Microsoft.Testing.Platform or Microsoft.Testing.Extensions package. Whenever the
# selection can't be sure, the whole test runs. It prints, one per line:
#   W <reason>     the whole test has to run
#   T <project>    a test project of the target to test: changed, or referencing a changed project, directly or through others
#   S <project>    a test project of the target the change doesn't reach
# A change that reaches no test project prints only S lines (or nothing, when there is no test project to leave).
dn_select_program() {
  cat <<'AWK'
function norm(p,   n, parts, i, k, st, r) {
  gsub(/\\+/, "/", p)
  n = split(p, parts, "/"); k = 0
  for (i = 1; i <= n; i++) {
    if (parts[i] == "" || parts[i] == ".") continue
    if (parts[i] == ".." && k > 0 && st[k] != "..") { k--; continue }
    st[++k] = parts[i]
  }
  r = ""
  for (i = 1; i <= k; i++) r = r (i > 1 ? "/" : "") st[i]
  return r
}
function dirof(p) { if (sub(/\/[^\/]*$/, "", p)) return p; return "" }
function skipped(p,   n, parts, i) {
  n = split(p, parts, "/")
  for (i = 1; i < n; i++) if (tolower(parts[i]) in skipname) return 1
  return 0
}
function isproj(l) { return (l ~ /\.(csproj|fsproj|vbproj)$/) }
function testpkg(n) {
  n = tolower(n)
  if (n == "xunit" || n == "xunit.v3" || n == "nunit" || n == "mstest" || n == "mstest.testframework" || n == "tunit" || n == "microsoft.net.test.sdk") return 1
  if (n ~ /^microsoft\.testing\.(platform|extensions)/) return 1
  return 0
}
# The values of the Include attributes in s (already lowercase) go to vals[1..n]; lastrest is what follows the last one.
function incvals(s,   n, v) {
  n = 0
  while (match(s, /include[ \t]*=[ \t]*("[^"]*"|'[^']*')/)) {
    v = substr(s, RSTART, RLENGTH); sub(/^include[ \t]*=[ \t]*./, "", v); sub(/.$/, "", v)
    vals[++n] = v
    s = substr(s, RSTART + RLENGTH)
  }
  lastrest = s
  return n
}
function addref(i, v,   t) {
  if (v ~ /\$\(|[;*?]|^[\/\\]|^[a-z]:/) { unresolved = unresolved " " proj[i]; return }
  t = norm(dirof(proj[i]) "/" v)
  refs[i] = refs[i] " " tolower(t)
}
# Does a line of a props or targets file bring in a test SDK or test package?
function propmark(low,   n, k, t) {
  if (low ~ /microsoft\.net\.test\.sdk|<istestproject>|mstest\.sdk/) return 1
  if (low ~ /packagereference/) {
    t = substr(low, index(low, "packagereference"))
    n = incvals(t)
    for (k = 1; k <= n; k++) if (testpkg(vals[k])) return 1
  }
  return 0
}
BEGIN {
  skipname["bin"] = 1; skipname["obj"] = 1; skipname["node_modules"] = 1; skipname[".git"] = 1
  while ((getline line < list) > 0) {
    sub(/\r$/, "", line)
    if (line == "" || skipped(line)) continue
    l = tolower(line); b = l; sub(/^.*\//, "", b)
    if (b == "directory.build.props" || b == "directory.build.targets") { bprops[++nb] = line; continue }
    if (b == "directory.packages.props") { pprops[++npp] = line; continue }
    if (b == "global.json") { gjson[++ng] = line; continue }
    if (!isproj(l)) continue
    if (line ~ / /) spaced = 1
    proj[++np] = line; key[l] = np
    d = dirof(line); dirprojs[d] = dirprojs[d] " " np
  }
  close(list)
  for (i = 1; i <= nb; i++) {
    while ((getline line < bprops[i]) > 0) {
      low = tolower(line)
      if (propmark(low)) propstest = bprops[i]
      if (low ~ /<projectreference/) propsref = bprops[i]
    }
    close(bprops[i])
  }
  for (i = 1; i <= npp; i++) {
    while ((getline line < pprops[i]) > 0) {
      low = tolower(line)
      if (low ~ /globalpackagereference/ && propmark(low)) propstest = pprops[i]
    }
    close(pprops[i])
  }
  for (i = 1; i <= ng; i++) {
    while ((getline line < gjson[i]) > 0) if (tolower(line) ~ /microsoft\.testing\.platform/) platform = gjson[i]
    close(gjson[i])
  }
  for (i = 1; i <= np; i++) {
    f = proj[i]; inref = 0; inpkg = 0
    while ((getline line < f) > 0) {
      low = tolower(line)
      if (low ~ /microsoft\.net\.test\.sdk|<istestproject>[ \t]*true/) istest[i] = 1
      if (low ~ /<project[^>]*[ \t]sdk[ \t]*=[ \t]*["']mstest\.sdk/) istest[i] = 1
      if (low ~ /<istestproject>[ \t]*false/) notest[i] = 1
      if (low ~ /<istestproject[ \t]+[^>]/ && cond == "") cond = f
      if (low ~ /<import[ \t]/) imp[i] = 1
      if (low ~ /<compile[^>]*include[ \t]*=[ \t]*["']\.\.[\/\\]/ && linked == "") linked = f
      t = low
      if (index(t, "<packagereference") > 0) { inpkg = 1; t = substr(t, index(t, "<packagereference")) }
      if (inpkg) {
        n = incvals(t)
        for (k = 1; k <= n; k++) if (testpkg(vals[k])) istest[i] = 1
        if (lastrest ~ />/) inpkg = 0
      }
      t = low
      if (index(t, "<projectreference") > 0) { inref = 1; t = substr(t, index(t, "<projectreference")) }
      if (inref) {
        n = incvals(t)
        for (k = 1; k <= n; k++) addref(i, vals[k])
        if (lastrest ~ />/) inref = 0
      }
    }
    close(f)
  }
  # The target's projects: those a project file target references (itself included), or the quoted project paths of a solution.
  tn = norm(target)
  if (isproj(tolower(tn))) {
    if ((tolower(tn) in key)) inset[key[tolower(tn)]] = 1
    for (grew = 1; grew;) {
      grew = 0
      for (i = 1; i <= np; i++) {
        if (!(i in inset)) continue
        n = split(refs[i], r, " ")
        for (j = 1; j <= n; j++) if ((r[j] in key) && !(key[r[j]] in inset)) { inset[key[r[j]]] = 1; grew = 1 }
      }
    }
  } else {
    td = dirof(tn)
    while ((getline line < target) > 0) {
      low = tolower(line)
      if (low ~ /"path"[ \t]*:[ \t]*"[^"]*\.\.[^"]*"/) slnfup = 1
      while (match(low, /"[^"]*\.(csproj|fsproj|vbproj)"/)) {
        v = substr(low, RSTART + 1, RLENGTH - 2); low = substr(low, RSTART + RLENGTH)
        k = tolower(norm(td "/" v))
        if (k in key) inset[key[k]] = 1
      }
    }
    close(target)
  }
}
{ sub(/\r$/, ""); if ($0 != "") chg[++nch] = $0 }
END {
  if (np == 0) { print "W no project file is tracked in git"; exit }
  if (spaced) { print "W a project path has a space in its name"; exit }
  if (propstest != "") { print "W " propstest " supplies a test SDK or test package, so the test projects can't be told"; exit }
  if (propsref != "") { print "W " propsref " holds a ProjectReference, so the project graph can't be read from the project files"; exit }
  if (platform != "") { print "W " platform " names Microsoft.Testing.Platform, which takes the project another way than dotnet test <project>"; exit }
  if (unresolved != "") { print "W a ProjectReference in" unresolved " can't be resolved (an MSBuild property, a list, a wildcard or an absolute path)"; exit }
  if (linked != "") { print "W " linked " links a source file from outside its folder, which no project folder covers"; exit }
  if (cond != "") { print "W " cond " has an IsTestProject with a Condition, so it can't be told whether it is a test project"; exit }
  if (slnfup) { print "W " target " names its solution with .., which the selection doesn't follow"; exit }
  nset = 0
  for (i = 1; i <= np; i++) if (i in inset) nset++
  if (!nset) { print "W the projects of " target " can't be read from it, or none of them is a tracked project file"; exit }
  for (i = 1; i <= np; i++) {
    if (notest[i]) istest[i] = 0
  }
  for (i = 1; i <= np; i++) {
    if (!(i in inset)) continue
    if (istest[i]) { ntest++; continue }
    if (notest[i]) continue
    if (imp[i]) { print "W " proj[i] " imports a file that may bring in its test SDK (set IsTestProject false in it if it is no test project)"; exit }
    p = tolower(proj[i]); sub(/\.(csproj|fsproj|vbproj)$/, "", p)
    n = split(p, segs, "/")
    for (k = 1; k <= n; k++) if (segs[k] ~ /tests?$/) { print "W " proj[i] " looks like a test project but its file shows no test SDK, so the test projects can't be told (set IsTestProject false in it if it is none)"; exit }
  }
  if (!ntest) { print "W no project of the target shows a test SDK, so the test projects can't be told"; exit }
  if (!nch) { print "W no changed backend path was listed"; exit }
  for (i = 1; i <= np; i++) {
    n = split(refs[i], r, " ")
    for (j = 1; j <= n; j++) if (r[j] in key) edge[i, key[r[j]]] = 1
  }
  for (c = 1; c <= nch; c++) {
    d = dirof(chg[c])
    while (!(d in dirprojs) && d != "") d = dirof(d)
    if (!(d in dirprojs)) { print "W " chg[c] " is outside every project"; exit }
    n = split(dirprojs[d], o, " ")
    for (j = 1; j <= n; j++) hit[o[j]] = 1
  }
  for (grew = 1; grew;) {
    grew = 0
    for (i = 1; i <= np; i++) {
      if (hit[i]) continue
      for (j = 1; j <= np; j++) if (hit[j] && ((i, j) in edge)) { hit[i] = 1; grew = 1; break }
    }
  }
  for (i = 1; i <= np; i++) {
    if (!(i in inset) || !istest[i]) continue
    if (hit[i]) print "T " proj[i]
    else print "S " proj[i]
  }
}
AWK
}

# dn_select <target>: dn_mode is "all" (the test runs as it always does), "whole" (the whole test runs, dn_reason says why),
# "projects" (dn_tested and dn_left are lists of test projects) or "none" (the change reaches no test project).
dn_select() {
  local lines kind rest
  dn_mode=all; dn_reason=""; dn_tested=""; dn_left=""
  [ "${CHECK_TIER:-full}" = fast ] && [ -f "${CHECK_BACKEND_CHANGED:-}" ] || return 0
  git -c core.quotepath=off ls-files -- '*.csproj' '*.fsproj' '*.vbproj' 'Directory.Build.props' '*/Directory.Build.props' \
    'Directory.Build.targets' '*/Directory.Build.targets' 'Directory.Packages.props' '*/Directory.Packages.props' \
    'global.json' '*/global.json' </dev/null >"$state/dotnet-projects" 2>/dev/null
  if ! lines="$(awk -v list="$state/dotnet-projects" -v target="${1//\\//}" "$(dn_select_program)" < "$CHECK_BACKEND_CHANGED" 2>"$state/select-projects.err")"; then
    dn_mode=whole; dn_reason="awk couldn't work out the projects (see $state/select-projects.err)"
    return 0
  fi
  while read -r kind rest; do
    case "$kind" in
      T) dn_tested="$dn_tested $rest" ;;
      S) dn_left="$dn_left $rest" ;;
      W) dn_mode=whole; dn_reason="$rest"; return 0 ;;
    esac
  done <<< "$lines"
  dn_tested="${dn_tested# }"; dn_left="${dn_left# }"
  if [ -n "$dn_tested" ]; then dn_mode=projects; else dn_mode=none; fi
}

# dn_test <target>: the test step. The full tier tests the whole target. The fast tier tests the test projects of the
# target that the change reaches (dotnet test <project> --no-build, all under one time limit: each gets what is left of
# it) and says which it tested and which it left to the full tier; a change outside every project, or one the projects
# can't be read for, runs the whole test, and says why. Every selected project runs, and each failing one is named.
dn_test() {
  local target="$1" p n=0 status log total="$cfg_timeout" start="$SECONDS" left failed=0
  dn_select "$target"
  case "$dn_mode" in
    whole) echo "check: fast tier: the whole test runs: $dn_reason" ;;
    none)
      echo "check: fast tier: no test project is changed or references a changed project, so no test runs"
      echo "check: fast tier: left to the full tier: ${dn_left:-none}"
      return 0 ;;
    projects)
      echo "check: fast tier: tested the test projects $dn_tested (changed, or referencing a changed project)"
      echo "check: fast tier: left to the full tier: ${dn_left:-none}" ;;
  esac
  if [ "$dn_mode" = projects ]; then
    for p in $dn_tested; do
      n=$((n + 1)); log="$state/test-$n.log"
      # The budget applies only where GNU timeout enforces a limit; without it every project runs, as the whole test did.
      if [ -n "${timeout_cmd:-}" ]; then
        left=$((total - (SECONDS - start)))
        if [ "$left" -le 0 ]; then timed_out "dotnet test"; [ "$failed" -eq 0 ] || return 1; return 3; fi
        cfg_timeout="$left"
      fi
      run_limited "$log" dotnet test "$p" --no-build -nologo -v:q
      status=$?
      cfg_timeout="$total"
      if [ "$status" -eq 124 ]; then timed_out "dotnet test"; [ "$failed" -eq 0 ] || return 1; return 3; fi
      grep -E '(Passed!|Failed!)|^[[:space:]]*Failed [A-Za-z_]|error' "$log" | head -n 40 | sed 's/^[[:space:]]*/  /'
      if [ "$status" -ne 0 ]; then echo "check: dotnet test failed in $p"; failed=1; fi
    done
    [ "$failed" -eq 0 ] || return 1
    echo "check: dotnet test passed"
    return 0
  fi
  run_limited "$state/test.log" dotnet test "$target" --no-build -nologo -v:q
  status=$?
  if [ "$status" -eq 124 ]; then timed_out "dotnet test"; return 3; fi
  grep -E '(Passed!|Failed!)|^[[:space:]]*Failed [A-Za-z_]|error' "$state/test.log" | head -n 40 | sed 's/^[[:space:]]*/  /'
  if [ "$status" -ne 0 ]; then echo "check: dotnet test failed"; return 1; fi
  echo "check: dotnet test passed"
}

stack_check() {
  local target status
  target="$(stack_target)"
  if [ -z "$target" ]; then
    echo "check: FAIL: no .sln or .slnx at the repository root (or set tools/check.cfg › [project] target)"
    return 1
  fi
  dotnet build "$target" -nologo -v:q -clp:NoSummary </dev/null >"$state/build.log" 2>&1
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "check: dotnet build failed:"
    grep -E ': (error|warning) [A-Z]+[0-9]+' "$state/build.log" | sed 's/^[[:space:]]*//' | awk '!seen[$0]++' | head -n 40 | sed 's/^/  /'
    return 1
  fi
  echo "check: dotnet build passed"
  dn_test "$target"
}
