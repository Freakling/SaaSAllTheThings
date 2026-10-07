# ADR-2 · The Windows client's UI technology

- **Status:** proposed
- **Date:** 2026-09-30
- **Decides:** reference/clients.md › Each client's UI technology
- **Supersedes:** none

## Context
Sales use the Windows client all day at the counter, with a keyboard and a barcode scanner. Fast data entry matters more than looks. The mobile app for the warehouse comes later and may be built differently.

## Options
1. **WinUI 3:** the current native Windows UI; WAM broker sign-in built in; Windows only.
2. **WPF:** mature, fast for dense data-entry forms, WAM through MSAL; Windows only.
3. **.NET MAUI:** one UI stack with a possible MAUI mobile app; desktop data-entry ergonomics are weaker.

Recommendation: WinUI 3, because it's the current native stack with first-class broker sign-in, and the mobile app doesn't need to share UI code.

## Decision
(Waiting for the human.)

## Consequences
- `clients/windows/` with its build in `tools/check.local.sh`.
