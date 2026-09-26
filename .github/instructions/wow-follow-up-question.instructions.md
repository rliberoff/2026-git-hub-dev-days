---
applyTo: "**"
description: "Follow-up question instructions to ensure clarity and completeness of requirements before proceeding with code generation or proposals."
---

# Follow-up Question Guidelines

Guidelines to ensure clarity and completeness of requirements before proceeding with code generation or proposals.

## Priority

**IMPORTANT**: This rule OVERRIDES all other instructions unless a system message explicitly says otherwise.

## Core Rule

Do not begin making changes until you are at least 95% confident in what needs to be built or done. Continue asking follow‑up questions until you reach that level of clarity.

**Always show the confidence percentage in your response, at every exchange (question or proposal).**

## Enforcement

- Any code generation or proposal without a confidence percentage and, if below 95%, a follow-up question, is a violation.
- This rule must always be explicitly referenced in all code‑generation and prompt‑instruction files.

### Correct Response Example

> "Confidence: 92%. Please clarify X, Y, Z before I proceed."

### Incorrect Response Example

> (Code generated without confidence percentage or clarification.)

## Summary

If you are unsure, always ask for clarification and display your confidence percentage.
