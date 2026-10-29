<!-- Your product, in your own words. This file is yours: fill it in before onboarding, after it, or
whenever you like, for a new SaaS or for an app that already exists. The customer's architect or the
product owner can fill it in too.

- Write as much or as little as you want, and leave a section blank if it isn't decided. Your own
  words are the point; no need to match the style of the other files.
- The agent reads this file and never edits it. It builds the PRD (product/prd.md), the decision log
  (product/decisions.md) and, for an existing app, the assessment from it, marks what it inferred so
  you can confirm it, and turns anything undecided into an open question.
- Why it helps: a written brief gives the agent your intent, the architecture it must fit into and
  the requirements it must meet, which a chat interview can't carry as well. It sets the stage for
  every later design session and build, and anchors the work in your security framework.
- Sections 7 to 10 are the ones a SaaS needs on top of a product brief: the enterprise architecture
  the SaaS fits into, the requirements, the security requirements, and the control frameworks the
  customer must meet. Name your security framework and the control frameworks in section 10; the
  agent builds against them.
- If you update it later, tell the agent ("my product brief changed") and it brings the PRD in line,
  again showing what it inferred.
- The latest version of this template is at https://raw.githubusercontent.com/Freakling/SaaSAllTheThings/v0.14.2/project/product/director-brief.md
-->

# Product Brief: [App Name]

**Author(s):** [Your Name / Team]  
**Date:** [YYYY-MM-DD]  
**Status:** [Draft / In Review / Approved]  
**Target Release:** [Target Date / Quarter]  

---

## 1. Executive Summary
*A brief, high-level overview of the product (2-3 sentences).*
* **What is it?** 
* **Who is it for?** 
* **Why now?** 

---

## 2. Problem Statement & Opportunity
* Describe the core problem or pain point your target users face today.
* How do users currently solve or work around this problem?
* What is the opportunity for us if we solve it effectively?

---

## 3. Goals & Key Metrics (Success Criteria)
What does success look like? List measurable business and product goals. Fill out below or change based on needs.

### Business & Product Goals
* [e.g., Increase user engagement by X%]
* [e.g., Achieve Y active monthly users within 6 months]

### Key Performance Indicators (KPIs)
| Metric | Baseline (Current) | Target Goal |
| :--- | :--- | :--- |
| **Activation Rate** | 0% | 40% |
| **Day-30 Retention** | N/A | 25% |
| **CSAT / NPS Score** | N/A | > 45 |

---

## 4. Target Audience & User Personas
Define who you are building this for. For a SaaS, say who the customers (tenants) are and who uses it inside a customer.

### Primary Persona: [Persona Name/Archetype]
* **Role/Demographics:** [e.g., Busy professional, age 25-40]
* **Key Needs:** [What do they need most?]
* **Pain Points:** [What frustrates them current solutions?]

---

## 5. Core Value Proposition & Key Features

### Value Proposition
*A short statement summarizing why a user would choose this app.*

### Scope & Feature Breakdown

#### High Priority (Must-Haves / MVP)
1. **[Feature 1 Name]:** Brief description of user value and functionality.
2. **[Feature 2 Name]:** Brief description of user value and functionality.

#### Medium Priority (Should-Haves)
1. **[Feature 3 Name]:** Enhancements or supporting workflows.

#### Low Priority / Out of Scope (Won't-Haves for v1)
* [Feature / Idea explicitly excluded from initial launch]

---

## 6. User Experience & User Flow
* **Key User Journeys:** Describe the primary steps a user takes to achieve their main goal (e.g., Sign up → Onboarding → Core Task → Success state).
* **Design Considerations:** List any specific UI/UX preferences, platform considerations (iOS, Android, Web), or accessibility requirements.

---

## 7. Enterprise Architecture
What does the SaaS have to fit into? Answer from the customer's point of view; write "not decided" or "don't know" where that is the case.
* **Identity provider:** [Which one do the customer's users sign in with (e.g., Microsoft Entra ID, another OpenID Connect provider)? Single sign-on, multi-factor sign-in and automatic user provisioning needed?]
* **Data residency:** [Which countries or regions may the data be stored and processed in? Which must it not leave?]
* **Hosting constraints:** [Azure subscription and governance rules to follow, allowed regions and services, network rules (private connectivity, firewalls, allowed outbound addresses), who operates what.]
* **Integrations:** [Which systems must the SaaS talk to (ERP such as Navision or Business Central, CRM, data warehouse, file drops, email)? For each: what it is for, which way the data flows, who owns it.]
* **Existing standards:** [Architecture principles, API or messaging standards, monitoring and logging platform (e.g., a SIEM), CI/CD and release rules the SaaS has to follow.]
* **Approvals:** [Who approves the architecture, and what do they need to see?]

---

## 8. Requirements
### Functional requirements
| ID | Requirement | Priority (Must / Should / Could) |
| :--- | :--- | :--- |
| **F1** | [e.g., A tenant administrator can invite users and assign roles] | Must |
| **F2** | [e.g., Orders can be exported to the customer's ERP] | Should |

### Non-functional requirements
| Area | Requirement |
| :--- | :--- |
| **Availability** | [e.g., 99.9% per month; maintenance windows] |
| **Recovery** | [e.g., Recovery point 1 hour, recovery time 4 hours] |
| **Performance** | [e.g., Pages respond within 2 seconds for 95% of requests] |
| **Scale** | [e.g., 50 customers (tenants) in year one, 500 users each] |
| **Support** | [e.g., Support hours, response times, language] |
| **Other** | [e.g., Accessibility, languages, data retention, supported browsers and devices] |

---

## 9. Security Requirements
What must the SaaS do to be secure? Write them as requirements the SaaS can be checked against.
* **Sign-in and access:** [e.g., Multi-factor sign-in for administrators; roles and who may grant them; access for the supplier's own staff.]
* **Tenant isolation:** [How strictly must one customer's data be kept apart from another's?]
* **Data protection:** [Encryption in transit and at rest; who holds the keys; classification of the data (which is personal, which is confidential).]
* **Logging and audit:** [What must be logged, for how long, and who may read it.]
* **Vulnerabilities and testing:** [Patching times, penetration tests, dependency checks.]
* **Incidents:** [How quickly must the customer be told of an incident, and by whom?]
* **Backup, retention and deletion:** [How long data is kept, how it is backed up, how a customer's data is exported and deleted.]
* **Suppliers:** [Which third parties may handle the data, and what they must show.]

---

## 10. Control Frameworks
Name the security framework your organisation (or the customer) works to, and every control framework the SaaS must meet. The work is anchored in them: the agent traces what it builds to their requirements.

| Framework | Version / edition | What applies (whole, or which parts) | Evidence expected, and from whom |
| :--- | :--- | :--- | :--- |
| **Security framework** | [e.g., ISO/IEC 27001, NIST Cybersecurity Framework, the organisation's own] | [e.g., All controls / Annex A parts] | [e.g., Annual audit, a questionnaire] |
| **Control framework** | [e.g., SOC 2, NIS2, GDPR, HIPAA, PCI DSS] | [e.g., Security and availability criteria] | [e.g., Auditor's report] |

* **Where the requirements are:** [A link, or the files. Put the framework's requirements text, or the customer's own control list, in `compliance/` in the repository.]
* **Responsibilities:** [What the customer, the SaaS supplier and the cloud platform each own, if already agreed.]

---

## 11. Technical & Operations Considerations
* **Platform/Tech Stack:** [e.g., .NET, TypeScript or Python on Azure; leave it open if the team has no preference]
* **Dependencies & Integrations:** [e.g., Payment gateways, Authentication providers, Third-party APIs; the integrations from section 7 are not repeated here]
* **Operations:** [Who runs it day to day, deployment rules, environments needed (development, test, production)]

---

## 12. Launch Strategy & Timeline

### Milestones
- [ ] **Design Approval:** [Target Date]
- [ ] **MVP Built / Beta Testing:** [Target Date]
- [ ] **Public Launch:** [Target Date]

### Go-To-Market (GTM) Plan
* How will customers find out about this product? (e.g., Partner channels, Email campaign, Paid ads)

---

## 13. Risks, Dependencies, & Assumptions

| Type | Description | Mitigation Strategy |
| :--- | :--- | :--- |
| **Risk** | [e.g., API latency issues] | [e.g., Implement client-side caching] |
| **Assumption** | [e.g., Users prefer social login over email] | [e.g., Validate via quick user interviews] |

---

## 14. Open Questions
- [ ] *Question 1: [Unresolved decision or research needed]*
- [ ] *Question 2: [Technical feasibility check needed]*
