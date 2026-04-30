# Sample App For AgentWorkflowPDLC

This dummy monorepo exists to test the GitHub Issue based agentic PDLC workflow.

It contains:

- `dotnet-api` - sample .NET backend.
- `java-api` - sample Java backend.
- `angular-frontend` - sample Angular/TypeScript frontend.
- `ops` - deployment and maintenance documentation.
- `scripts` - local helper scripts, including ZIP packaging.
- `docs` - analysis notes used by the PDLC workflow.

## PDLC Test Scenario

Business input should be written in Polish in a GitHub Issue. Agents may reason in English and produce technical metadata in English, but business-facing summaries should remain in Polish.

Recommended exercise:

1. Create a `PDLC Agent Task` issue.
2. Ask the Intake Agent to analyze a requested change in the sample app.
3. Manually approve `Intake approved`.
4. Continue through risk, requirements, architecture, planning, coding, QA, security, docs, and release.
5. Open a PR against this sample app.
6. Use `sample-app-ci.yml` as the deterministic gate.

This README line intentionally lives under `sample-app/**` so documentation-only PRs can trigger the sample application CI during workflow tests.

## Local Commands

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\dotnet-api
dotnet build
```

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\java-api
mvn test
```

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\angular-frontend
npm install
npm run build
```

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC
.\sample-app\scripts\package-sample-app.ps1
```

