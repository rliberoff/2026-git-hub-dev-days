# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Leadership and architecture | shuri | Scope, cross-cutting design, delegation, reviews, and final integration |
| Game development | arcade | Terminal-game mechanics, interaction flow, and gameplay demonstration |
| Backend and infrastructure | ironman | APIM, Foundry integration, Terraform, PowerShell, and service behavior |
| Testing and quality | hulk | Automated checks, live test plans, failure scenarios, and regression coverage |
| Documentation | vision | README, ADRs, operational guidance, and contributor-facing documentation |
| Session memory | Scribe | Session logs, decision merging, and cross-agent context |
| Work monitoring | Ralph | Issue queue monitoring, triage follow-up, and continuous work checks |
| Responsible AI review | Rai | Safety, privacy, fairness, and responsible AI review |
| Verification | Fact Checker | Claim verification, source checks, and devil's-advocate review |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage and assign the appropriate member label | shuri |
| `squad:shuri` | Lead and architecture work | shuri |
| `squad:arcade` | Game-development work | arcade |
| `squad:ironman` | Backend and infrastructure work | ironman |
| `squad:hulk` | Testing and quality work | hulk |
| `squad:vision` | Documentation work | vision |
| `squad:scribe` | Session memory and decision-log work | Scribe |
| `squad:ralph` | Work-monitoring tasks | Ralph |
| `squad:rai` | Responsible AI review | Rai |
| `squad:fact-checker` | Verification and devil's-advocate review | Fact Checker |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, **shuri** triages it, applies the matching member label, and comments with triage notes.
2. When a member-specific `squad:` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — route each member-specific `squad:` label to the member named in the table. shuri handles all base `squad` triage.
