# Compliance mapping

This table maps each requirement of the customer's security framework (or control list) to what meets it in this project. Review and align read it, so keep it short and true.

- **Who edits what.** The human fills Control and Requirement from the customer's framework, and may put the requirements' own documents beside this file in `compliance/`. Architecture sessions fill Met by, Label and Evidence as ADRs are accepted. A row is a claim: a reviewer checks it against what Met by names.
- **Met by** is a rule id from `tools/archcheck.awk` (the names `reference/README.md` › What the check enforces lists), a job of the installed `.github/workflows/check.yml`, an `ADR-NNNN`, a test path, or `none yet`. A row labelled `direct` always names what meets it.
- **Evidence of operation** (that a control ran, not only that it is designed) comes from the running system: a CI run artifact, a log query, a record. This table says where to find it; it holds none.
- **A framework's name never marks a control met.** Naming ISO 27001, SOC 2 or the customer's framework in the brief or the PRD satisfies nothing. Only a row with Met by and Evidence does, and only as far as its label says.
- **The OWASP rows are the baseline and stay.** OWASP Top 10 (and the OWASP API Security Top 10 for anything that serves an API) is a framework-owned baseline every app meets (`rules.md` › Architecture in code). The ten rows below are always here: unlike the example row, never delete them, and no setting turns them off. Update Met by, Label and Evidence as the project's work changes; a deviation is an accepted ADR that names the OWASP item and why. The labels are what this framework meets today; most rules cover only a slice, so none is `direct`.
- Review flags a row as possibly stale when a change touches what Met by names. Align reports rows whose Met by no longer exists.

Labels, as `research.md` uses them:
- `direct`: what Met by names meets the requirement as the framework words it.
- `partial`: it meets part of the requirement; the rest is open or sits with another party.
- `interpretive`: it meets the requirement under the project's or auditor's reading, not the wording alone.
- `unverified`: the mapping is proposed and nobody has confirmed it.

| Control | Requirement | Met by | Label | Evidence |
|---|---|---|---|---|
| OWASP A01 Broken Access Control (baseline: keep) | The Top 10's access control category: users act only within their permissions | tenant-source, tenant-branching | partial | `tools/check.sh` output (CI run artifact); `reference/tenancy.md` and `reference/identity.md` (authorization per use case, which the check does not see; review reads it) |
| OWASP A02 Cryptographic Failures (baseline: keep) | Sensitive data is protected in transit and at rest; keys are managed | secrets | partial | CI run artifact of `tools/check.sh`; `reference/identity.md` › No secrets (Key Vault, managed identities). Encryption settings and TLS stay with the platform and are not checked |
| OWASP A03 Injection (baseline: keep) | Untrusted input does not reach an interpreter as a command or query | none yet | unverified | `reference/api.md` (400 for invalid input); no rule checks queries or input handling, review reads each change |
| OWASP A04 Insecure Design (baseline: keep) | Threats are considered in the design | layers, domain-purity | interpretive | ADRs in `adr/` (each option states its OWASP effect); `reference/layers.md`. The mechanical rules cover structure, not threat modelling |
| OWASP A05 Security Misconfiguration (baseline: keep) | Systems are hardened and configured securely | network-public | partial | CI run artifact of `tools/check.sh`; `reference/network.md`. Covers Bicep for four resource types, not Function app or host settings |
| OWASP A06 Vulnerable and Outdated Components (baseline: keep) | Components with known vulnerabilities are not used | dependency-review | partial | CI run of `.github/workflows/check.yml`, only where the workflow is installed; `reference/infra.md` › Dependencies and the SBOM. Container images and transitive dependencies the graph can't see are not covered; vulnerability response stays the customer's process |
| OWASP A07 Identification and Authentication Failures (baseline: keep) | Users are identified and authenticated robustly | none yet | unverified | `reference/identity.md` (Entra ID, token validation before handlers); no rule checks it, review reads each change |
| OWASP A08 Software and Data Integrity Failures (baseline: keep) | Code, pipelines and data are protected against untrusted change | none yet | unverified | `sbom` job artifact of the installed workflow lists dependencies, which does not verify integrity; `reference/messaging.md` and `reference/infra.md` advise only |
| OWASP A09 Security Logging and Alerting Failures (baseline: keep) | Security events are logged and raise alerts | none yet | unverified | `reference/observability.md` advises; no rule checks it |
| OWASP A10 Server-Side Request Forgery (baseline: keep) | The server does not fetch attacker-chosen URLs | none yet | unverified | `reference/network.md` (integrations are outbound-only to known systems); no rule checks it, review reads each change |
| EXAMPLE-1 (an example: delete this row) | Storage is not reachable from the public internet | network-public, ADR-0001 | partial | CI run artifact of `tools/check.sh`; ADR-0001 for exceptions. Egress control stays with the customer's platform |
