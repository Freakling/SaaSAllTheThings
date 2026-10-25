<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Compliance questions

The one set of questions that finds out which security framework and which regulations the app is anchored in. Onboarding, the assessment and the vision and tenancy-identity workshops use it and don't restate it, so the wording lives here.

## When to ask
- The brief's section 10 (`product/director-brief.md`) is blank or vague (a placeholder, "TBD", a framework name with no scope or evidence): ask the questions below instead of moving on.
- It is filled: confirm it in one line ("the brief names X, Y and Z, and that stays") and ask only about what it leaves out.
- Ask a few at a time, and only what the brief and the human's documents don't answer. Offer multiple choice where the tool supports it. "I don't know" is an answer.

## The questions
1. **Security framework.** Which security framework does the organisation or its customer work to? For example ISO/IEC 27001, NIST CSF, the ISF Standard of Good Practice, or its own. Which edition, and the whole or which parts?
2. **Markets and data.** In which countries or regions will the app be sold, and whose data does it hold (employees, customers' customers, patients, cardholders, children)? These are the facts the regulations follow from.
3. **Regulations.** For each regulation below that the answer to question 2 could touch, ask whether it applies; never assume that one applies or doesn't. The list is prompts, not a checklist to fill in.
   - GDPR: personal data of people in the EU or EEA.
   - NIS2 and DORA: EU essential, important and financial entities, and their ICT suppliers.
   - SOC 2: customers who ask for it.
   - PCI DSS: card data.
   - HIPAA: US health data.
   - Sector or national rules the customer names.
4. **Audit and evidence.** Who audits (the customer, an external auditor, a certification body), how often, and what evidence do they expect (a report, a questionnaire, logs, a test result, a walkthrough)?
5. **The documents.** Can the customer's own control list, or a framework document, be placed in `compliance/`?

## Where the answers go
- PRD › Data and Compliance, and the rows of the brief's section 10 table (the brief is the human's: propose the rows, and edit it only when the human agrees).
- For each framework named, `compliance/mapping.md` gets its controls only from the human or from a document the human provides, never from the agent's memory, even for a well-known framework. Until then the PRD lists the framework with `controls: to add`.
- An answer that is unknown stays an open question in the PRD (a `Q<n>`), with who can answer it.
- Naming a framework marks nothing met. A control is met only as `compliance/mapping.md` says, with what meets it and the evidence. The OWASP baseline rows there stay as they are.
