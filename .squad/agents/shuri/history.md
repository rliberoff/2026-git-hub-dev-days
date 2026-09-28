# Project context

- **Owner:** Rodrigo Liberoff
- **Project:** 2026-git-hub-dev-days
- **Description:** Two-region Microsoft Foundry inference gateway through Azure API Management for a Squad and GitHub Copilot CLI terminal-game demonstration.
- **Stack:** Azure Developer CLI, Terraform, Azure API Management, Microsoft Foundry, PowerShell, GitHub Copilot CLI, Squad, and .NET SDK
- **Created:** 2026-09-28T19:24:44.567+02:00

## Core context

shuri leads architecture, delegation, review, and final integration.

## Recent updates

- Team initialized with the confirmed Marvel roster on 2026-09-28.

## Learnings

- The workload spans infrastructure, gateway behavior, live validation, and a terminal-game demonstration.

## Session update: Terminal Tetris architecture

- **Timestamp:** 2026-09-28T19:41:42.000+02:00
- **Work:** Designed the minimum architecture for a terminal Tetris application.
- **Outcome:** Selected a small .NET console application with a deterministic game engine separated from input, timing, rendering, and replaceable piece generation. The decision was merged into the shared decision log.
