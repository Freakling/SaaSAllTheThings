<!-- SaaSAllTheThings · framework-owned: replaced on upgrade. -->
# Refresh model sizing

Check whether this tool supports model sizing, then write or update the five per-size model-ID entries in AGENTS.md › Project rules.

## 0. Capability check
Model sizing requires two capabilities: spawning a builder subagent, and specifying a different model for each subagent call.
- **Claude Code:** both are available — proceed.
- **Any other tool:** if you cannot spawn a subagent, or cannot choose its model per call, tell the human that model sizing is not supported for this tool and stop. Do not write any entries.

## 1. Read existing entries
Read AGENTS.md › Project rules. If a `Model sizing: on` block with five entries already exists, show the human the current values and ask whether to update them or leave them.

## 2. Propose defaults
Suggest entries based on the tool in use:

**Claude Code defaults:**
```
Model sizing: on
- XS: claude-haiku-4-5-20251001
- S:  claude-haiku-4-5-20251001
- M:  claude-sonnet-5-5
- L:  claude-opus-5-5
- XL: claude-opus-5-5
```
(`claude-fable-5-1` is an alternative for L and XL when the human has Claude platform usage credits.)

For other tools: use a fast/cheap model for XS and S, a balanced model for M, and the most capable model for L and XL. If the tool's model IDs are not known, ask the human.

## 3. Write the entries
After the human confirms, write or replace the block in AGENTS.md › Project rules:
```
Model sizing: on
- XS: <model-id>
- S:  <model-id>
- M:  <model-id>
- L:  <model-id>
- XL: <model-id>
```
To turn sizing off, write `Model sizing: off` and remove any existing size entries.
