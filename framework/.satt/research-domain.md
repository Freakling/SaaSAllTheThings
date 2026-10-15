<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Research domain: a B2B SaaS on Azure

Read this when the question concerns Azure, the reference architecture, the customer's security framework or an architecture decision. It adds to `procedures/research.md` and never repeats it. A question outside this domain stays technology-neutral, and every option gets the same evidence standard.

## Azure first, when Azure is central
Treat a question as Azure platform research when Azure is central to it. Consider the concerns that apply:
- tenant and subscription layout, management groups and resource organisation;
- identity, privileged access and workload identities;
- governance, RBAC and guardrails;
- networking, DNS, routing, segmentation and private access;
- monitoring, logging, key management and data protection;
- landing zones and workload onboarding;
- infrastructure as code, pipelines and drift;
- operations, ownership and support;
- availability, resilience, backup and recovery;
- cost, quotas and service limits;
- data residency and sovereignty.

**Primary guidance** is current Microsoft documentation: the Cloud Adoption Framework, the Well-Architected Framework, the Azure Architecture Center, landing zone guidance, product documentation and release information. These are inputs, not answers: adapt them to the project's requirements and recorded constraints.

**Switch to technology-neutral** when Azure is not material, when the question is about a language, framework, protocol or practice, when a cross-cloud or on-premises option is viable, or when an Azure-only framing would distort the decision. Apply the same evidence standard to every option.

## The reference architecture has authority
`.satt/reference/` holds unless an accepted ADR says otherwise. Classify the question as `architect.md` › Prepare does: an open choice, a deviation, a framework gap, or a requirements conflict.
- For a deviation, option 1 is to comply, with what that takes.
- Start cost figures from `reference/cost.md`.
- A source that contradicts the reference is a reason to name a framework gap, never to treat the reference as changed.

## The customer's security framework
Requirements in `compliance/` (and PRD › Data and Compliance) are Tier 1.
- Trace each requirement to the proposed control, and label the mapping direct, partial, interpretive or unverified.
- Name the shared-responsibility boundary: what Microsoft, the product and the customer each own.
- Do not infer that a requirement is met from the presence of a control.

## ADR-ready summary
For a significant decision, the Recommendation section ends with a summary the architect session can turn into an ADR:
- title, and status `proposed`;
- context, decision and rationale;
- alternatives considered;
- positive and negative consequences;
- assumptions;
- references;
- review or supersession triggers.

The researcher never writes the ADR and never marks it accepted. The architect session writes it from the summary (`architect.md` › Record), and sets `accepted` only when the human says so.

## Architecture recommendation checklist
For an architecture question, the note covers:
- decision context, requirements and constraints;
- assumptions and unknowns;
- viable options, and the criteria taken from the scenario;
- evidence-backed trade-offs, the recommended option and its rationale;
- security and requirements implications;
- operations and ownership;
- dependencies and prerequisites;
- cost, where evidence exists;
- migration or implementation considerations;
- risks and mitigations;
- revisit triggers;
- confidence.
