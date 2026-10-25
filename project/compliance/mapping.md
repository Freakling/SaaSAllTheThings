# Compliance mapping

This table maps each requirement of the customer's security framework (or control list) to what meets it in this project. Review and align read it, so keep it short and true.

- **Who edits what.** The human fills Control and Requirement from the customer's framework, and may put the requirements' own documents beside this file in `compliance/`. Architecture sessions fill Met by, Label and Evidence as ADRs are accepted. A row is a claim: a reviewer checks it against what Met by names.
- **Met by** is a rule id from `tools/archcheck.awk` (the names `reference/README.md` › What the check enforces lists), an `ADR-NNNN`, a test path, or `none yet`. A row labelled `direct` always names what meets it.
- **Evidence of operation** (that a control ran, not only that it is designed) comes from the running system: a CI run artifact, a log query, a record. This table says where to find it; it holds none.
- **A framework's name never marks a control met.** Naming ISO 27001, SOC 2 or the customer's framework in the brief or the PRD satisfies nothing. Only a row with Met by and Evidence does, and only as far as its label says.
- Review flags a row as possibly stale when a change touches what Met by names. Align reports rows whose Met by no longer exists.

Labels, as `research.md` uses them:
- `direct`: what Met by names meets the requirement as the framework words it.
- `partial`: it meets part of the requirement; the rest is open or sits with another party.
- `interpretive`: it meets the requirement under the project's or auditor's reading, not the wording alone.
- `unverified`: the mapping is proposed and nobody has confirmed it.

| Control | Requirement | Met by | Label | Evidence |
|---|---|---|---|---|
| EXAMPLE-1 (an example: delete this row) | Storage is not reachable from the public internet | network-public, ADR-0001 | partial | CI run artifact of `tools/check.sh`; ADR-0001 for exceptions. Egress control stays with the customer's platform |
