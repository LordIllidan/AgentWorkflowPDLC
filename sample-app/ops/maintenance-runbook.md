# Maintenance Runbook

## Purpose

This runbook gives the SRE Agent and human reviewers a simple operations target for workflow tests.

## Health Checks

| Component | Check | Expected Result |
|---|---|---|
| .NET API | `GET /` | JSON with `sample-risk-dotnet-api` |
| Java API | run `App` main method | console output with risk class |
| Angular frontend | load root page | risk scoring card is visible |

## Common Incidents

### Risk score class mismatch

Symptoms:

- .NET and Java classify the same score differently.
- Frontend displays a different class than backend response.

Triage:

1. Compare thresholds in `.NET`, Java, and TypeScript.
2. Run unit tests.
3. Add a regression test for the score boundary.
4. Update documentation if the business rule changed.

### Frontend build fails

Triage:

1. Check Angular and TypeScript versions.
2. Run `npm install`.
3. Run `npm run build`.
4. Check strict template errors.

### Java test fails

Triage:

1. Run `mvn test`.
2. Inspect boundary conditions.
3. Compare Java scoring with `docs/analysis-scope.md`.

## Follow-Up Issue Template

```text
Incident summary:
Suspected root cause:
Evidence:
Immediate mitigation:
Long-term fix:
Owner:
Priority:
```

