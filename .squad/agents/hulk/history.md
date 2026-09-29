# Project context

- **Owner:** Rodrigo Liberoff
- **Project:** 2026-git-hub-dev-days
- **Description:** Two-region Microsoft Foundry inference gateway through Azure API Management for a Squad and GitHub Copilot CLI terminal-game demonstration.
- **Stack:** Azure Developer CLI, Terraform, Azure API Management, Microsoft Foundry, PowerShell, GitHub Copilot CLI, Squad, and .NET SDK
- **Created:** 2026-09-28T19:24:44.567+02:00

## Core context

hulk owns automated checks, live validation, failure scenarios, and regression coverage.

## Recent updates

- Team initialized with the confirmed Marvel roster on 2026-09-28.

## Learnings

- Live checks include controlled APIM rate limiting and regional backend failover with restoration.

## Session update: Terminal Tetris validation

- **Timestamp:** 2026-09-28T19:52:04.082+02:00
- **Work:** Created deterministic regression coverage in `tests/TerminalTetris.Tests/` and reviewed the implementation against the acceptance contract.
- **Outcome:** 26 of 26 tests passed. Review verdict **APPROVED**.
