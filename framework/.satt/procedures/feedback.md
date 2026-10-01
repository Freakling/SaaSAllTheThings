<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Feedback

Start a feedback report, or process a filled-in one into bug items, product proposals and tasks, comparing its scores with earlier reports. A report records one session with a customer, a pilot user or an internal tester.

If the human didn't say which, list the reports under `validation/` named `*-feedback*.md` that have no `Processed:` line, and ask whether to process one or start a new one.

Reports hold what people said about the product, not who they are: a role and a tenant label ("pilot tenant A, warehouse lead"), never names or contact details.

## New report
Copy `validation/TEMPLATE.md` to `validation/YYYY-MM-DD-feedback.md` (add `-2`, `-3` for more reports on the same day). Fill in `Date:`, and `Build:` with `git rev-parse --short HEAD`. The human fills in the rest during or after the session.

## Process a report
Only when the human asks.

1. Read the whole report, including Free-Format Comments. They matter as much as the scores.
2. **Scores.** Build a small table: each scored statement, with its score in this report and in earlier reports. Match statements by exact wording; changed wording starts a new series. Add one line on anything notable.
3. **Bugs.** Every entry under Bugs becomes a `B` item in TASKS.md straight away (format: `.satt/tasks.md`), since it needs no decision: steps → expected / actual, severity as reported, `Found in:` the file. Check "might be a bug" entries against the PRD. A clear defect becomes a `B` item; anything else is a product finding.
4. **Product findings.** Group them. For each group, propose what could change as 2–4 options with a recommendation, following `product.md`. Record only what the human chooses: the PRD, `product/decisions.md` (with the file as the source), and TASKS.md items. Anything left unresolved becomes a new Open Question. A request for one customer only becomes a plan or feature-flag question, never tenant-specific code (`reference/tenancy.md`).
5. **Mark it.** Under the report's header, add `**Processed:** YYYY-MM-DD → B4, B5, T20, Q7`, listing what it produced.
6. **Finish.** Summarise, then commit as `docs: process feedback <file>` after the human approves.
