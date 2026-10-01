<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Validation

Two kinds of session feed the product and its bug list:

| | Asks | You fill in | The assistant turns it into |
|---|---|---|---|
| **Feedback** | Does it help the people using it? | `TEMPLATE.md`, during or after a session with a customer, pilot user or tester | bug items, product proposals for you to decide, score trends |
| **Acceptance check** | Does each built rule work as written, in a running app? | a generated checklist: tick Works or Broken | bug items, and product questions when a rule itself seems wrong |

Rules that can be tested automatically are proven by `bash tools/check.sh` on every change. An acceptance check covers only what needs a person: what the clients show, sign-in, flows across clients, and behaviour in a deployed environment.

## Feedback
1. Say "new feedback report" (in Claude Code also `/feedback new`). This creates `validation/YYYY-MM-DD-feedback.md` from `TEMPLATE.md`, with the build filled in.
2. Fill it in during or after the session. Skip capabilities you didn't reach. Write roles and tenant labels, never names or contact details.
3. Say "process this feedback". Bugs are filed straight away. Product findings come back as options with a recommendation, and nothing in the PRD changes until you choose. Scores are compared with earlier reports that use the same statement.

Each capability in the template has one fixed scored statement, so scores stay comparable across builds. If you reword a statement, it starts a new series.

## Acceptance check
1. Say "prepare an acceptance check" (in Claude Code also `/acceptance`). This writes `validation/YYYY-MM-DD-acceptance.md` with everything built since the last check that needs a human eye. Say "acceptance all" for a full regression round.
2. For each item, tick **Works** or **Broken / missing**, and say what went wrong in Notes. Leave both boxes empty for anything you didn't check; it comes back next time.
3. Say "process the acceptance check". Broken items become bugs. A note saying the rule itself should change becomes a product question for you.

## Files
- `TEMPLATE.md`: the feedback template. It's yours, with one section per capability.
- `YYYY-MM-DD-feedback.md` and `YYYY-MM-DD-acceptance.md`: one file per session. Once processed, a file gets a `Processed:` line listing the bugs, tasks and questions it produced.
