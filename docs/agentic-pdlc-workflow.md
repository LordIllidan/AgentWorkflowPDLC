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
8. The analysis-to-coding transition is approved with the issue comment `/approve analysis`.
9. The local Claude Code coding path is approved with the issue comment `/approve ai-coding`.
10. Review feedback can be handed back to the local Claude Code worker with the PR comment `/fix-review`.
11. Release monitoring may create a new PDLC issue when a post-merge failure is detected.

## Issue State Model

The issue body contains a checklist with stable stage names. The GitHub Action parses the checklist and computes:

- completed stages,
- current stage,
- next required stage,
- missing previous approvals,
- final readiness status.

The action posts or updates a single status comment marked with `<!-- pdlc-status -->`.

## Automated MVP Loop

The repository also contains a deterministic automation loop:

- `PDLC Research Agent` creates proposal issues on schedule or manual dispatch.
- `PDLC Agent Analysis` analyzes and splits new PDLC issues.
- `PDLC Agent Coding` reacts to `/approve analysis`, creates a branch, writes artifacts, and opens a PR.
- `PDLC Claude Code Worker` reacts to `/approve ai-coding` and runs Claude Code on a self-hosted Windows runner.
- `PDLC Claude Review Fix Worker` reacts to `/fix-review` and pushes review fixes to the existing PR branch.
- `PDLC Release Monitor` runs after a merged PR and creates follow-up issues when failure is signaled.

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

