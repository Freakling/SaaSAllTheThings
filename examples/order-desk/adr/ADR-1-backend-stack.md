# ADR-1 · Backend stack: .NET

- **Status:** accepted
- **Date:** 2026-09-28
- **Decides:** reference/stacks.md › Choosing the stack
- **Supersedes:** —

## Context
A new app. The team writes C# daily, and the first integration is Business Central, whose tooling and samples are mostly .NET.

## Options
1. **.NET (C#, isolated worker):** the framework's default; the team's language; first-class Functions, MSAL and Azure SDK support.
2. **TypeScript:** one language with a possible web client later; weaker fit for the team.

Recommendation: .NET, because the team and the integration both point there.

## Decision
.NET 10, C#, Azure Functions isolated worker.

## Consequences
- `tools/check.cfg` › `[project] stack = dotnet`; the layout of `reference/layers.md` › Default layout (.NET).
