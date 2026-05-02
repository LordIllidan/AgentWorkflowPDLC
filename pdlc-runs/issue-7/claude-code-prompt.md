You are the PDLC Coding Agent running locally on the user's Windows workstation through a GitHub self-hosted runner.

Language policy:
- Think and operate internally in English.
- Preserve Polish business wording when it is part of issue content or user-facing artifacts.

Source GitHub issue:
- Repository: LordIllidan/AgentWorkflowPDLC
- Issue: #7
- URL: https://github.com/LordIllidan/AgentWorkflowPDLC/issues/7
- Title: [PDLC] Dodaj poziom ryzyka "critical" w sample app

Issue body:
`markdown
### Business context



Chcemy rozszerzyć przykładową aplikację o obsługę najwyższego poziomu ryzyka `critical`, żeby workflow agentowy przetestował realną zmianę w kodzie backendów i frontendzie.



### Repositories and systems

- repo: AgentWorkflowPDLC
- backend: sample-app/dotnet-api
- backend: sample-app/java-api
- frontend: sample-app/angular-frontend
- docs: sample-app/docs

### Initial risk guess

low

### Initial acceptance criteria

- Given risk score is 90 or higher
- When .NET API, Java API, or Angular frontend classifies the score
- Then risk level is shown as `critical`
- Given risk score is below 90
- When classification runs
- Then existing `low`, `medium`, and `high` behavior remains unchanged
- Tests or sample data should cover the new `critical` level

### PDLC artifacts and links

- Intake:
- Risk card:
- Requirements:
- Architecture / ADR:
- Implementation plan:
- Pull request:
- Review:
- QA:
- Security:
- Documentation:
- Release:


### Manual approval gates

- [x] Intake approved
- [x] Risk classification approved
- [x] Requirements approved
- [x] Architecture approved or not required
- [x] Planning approved
- [x] Coding ready for PR
- [ ] Review approved
- [ ] QA approved
- [ ] Security approved
- [ ] Documentation approved
- [ ] Release readiness approved
`

PDLC analysis comment:
`markdown
<!-- pdlc-agent-analysis -->
## Agent Analysis

Issue: #7 [PDLC] Dodaj poziom ryzyka "critical" w sample app

### Business summary

Chcemy rozszerzyć przykładową aplikację o obsługę najwyższego poziomu ryzyka `critical`, żeby workflow agentowy przetestował realną zmianę w kodzie backendów i frontendzie.

### Initial risk

low

### Repositories and systems

- repo: AgentWorkflowPDLC

### Proposed split

| Part | Goal | Output |
|---|---|---|
| 1. Product scope | Clarify business value and acceptance criteria | refined user story, exclusions, acceptance checklist |
| 2. Architecture impact | Identify services, contracts, data, and operational impact | lightweight ADR or "not required" note |
| 3. Implementation | Prepare branch-level coding work | code change, tests, PR |
| 4. Verification | Check CI, tests, review, security, and docs | PR evidence and unresolved risk list |
| 5. Release monitoring | Watch post-merge signal and create follow-up issues on failure | monitoring comment or incident issue |

### Acceptance criteria seen by the agent

- Given risk score is 90 or higher

### Next human action

Review this analysis. If it is acceptable, add a comment:

```text
/approve analysis
```

The coding agent will then create a branch, generate PDLC artifacts, update the sample app documentation, and open a pull request.
`

Task:
1. Implement the requested code change in this repository.
2. Keep changes scoped to the issue.
3. Add or update focused tests when the code change affects behavior.
4. Add or update documentation only when needed for this feature.
5. Do not merge, do not push, and do not create a pull request. The wrapper script will commit, push, and create the PR.
6. Do not read or print secrets.
7. Avoid destructive git commands.
8. Before finishing, inspect the diff and leave the workspace ready to commit.

Expected output:
- Concise summary of changed files.
- Verification commands you ran or intentionally skipped.
- Any remaining risks or follow-up notes.