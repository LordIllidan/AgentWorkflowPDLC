# Agentic PDLC Workflow

## Goal

This workflow turns a GitHub Issue into a controlled PDLC execution thread. Agents can draft analysis, requirements, architecture, implementation plans, code, tests, reviews, and documentation, but important transitions remain human-approved.

Business input and final business-facing artifacts may be written in Polish. Agent instructions, technical metadata, field names, commands, and workflow internals should stay in English.

## Stages

| Stage | Human approval means | Typical artifacts |
|---|---|---|
| Research | a generated feature proposal is worth intake | market or internal research note, proposed issue |
| Intake | the task intent and missing information are clear | task brief, assumptions, open questions |
| Risk Classification | risk class and required gates are accepted | risk card, approvers, required checks |
| Requirements | product scope is accepted | user stories, acceptance criteria, out-of-scope |
| Architecture | architecture path is accepted or not required | ADR, impact analysis, diagrams |
| Planning | implementation and validation plan are accepted | implementation plan, test plan, stop conditions |
| Coding | code is ready for PR review | branch, commits, draft PR, local verification |
| Review | first-pass review findings are resolved or accepted | review report, unresolved risks |
| QA | test evidence is accepted | QA report, commands, results |
| Security | security review is accepted | SAST/SCA/secrets/IaC findings, exceptions |
| Docs | documentation is accepted | feature docs, ADR updates, PR summary |
| Release | release readiness is accepted | release notes, SBOM, rollback, monitoring |
| Monitoring | post-merge signal is reviewed | deployment result, follow-up issue if needed |

## Agent Rules

1. An agent must not skip a stage.
2. An agent must not check approval boxes on behalf of a human.
3. A coding agent must not merge to the default branch.
4. A review, QA, or security agent must be independent from the coding agent.
5. Every artifact referenced by a checkbox must be linked in the issue or pull request.
6. If a stage has incomplete input, the agent should ask focused questions in Polish.
7. The issue remains the audit thread for decisions, approvals, and links.
8. If a stage has blocking questions, it writes `Status: BLOCKED_QUESTIONS` and waits for `/pdlc answer`.
9. The local Claude Code coding path is approved with the issue comment `/approve ai-coding`.
10. Review feedback can be handed back to the local Claude Code worker with the PR comment `/fix-review`.

## Issue State Model

The issue body contains a checklist with stable stage names. The GitHub Action parses the checklist and computes:

- completed stages,
- current stage,
- next required stage,
- missing previous approvals,
- final readiness status.

The action posts or updates a single status comment marked with `<!-- pdlc-status -->`.

## Automated AI Loop

The repository uses one AI agent router:

- new issues run autonomy risk assessment,
- `/pdlc ...` commands run local Claude Code stage agents,
- `[PDLC #16] /pdlc analyze` commit messages can run a stage,
- `/approve ai-coding` runs the local Claude Code implementation worker,
- `/fix-review` runs the local Claude Code review-fix worker.

Detailed operating notes are in `docs/automated-agent-loop.md`.

## Minimal Enterprise Controls

| Control | Current implementation | Future extension |
|---|---|---|
| Human gate | issue checklist | GitHub environment approvals or CODEOWNERS |
| Audit | issue history and bot status comment | external audit event store |
| Agent identity | documented only | GitHub Apps or service accounts |
| Tool access | not automated | MCP gateway with role-based tool filtering |
| Model usage | none | model gateway with budgets and tracing |
| Risk policy | manual risk card | OPA/Rego policy checks |

## Recommended Operating Pattern

Use this repository as a workflow harness, not as the product repository. The issue tracks the PDLC execution and points to product repositories, branches, pull requests, generated artifacts, and approvals.

