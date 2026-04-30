# Analysis Scope

## Purpose

This document defines what agents should analyze in the dummy app before planning or coding.

## Backend .NET

Analyze:

- Minimal API endpoints.
- Request and response contracts.
- Risk scoring logic.
- Build and runtime configuration.
- Deployment container readiness.

Expected artifact:

```yaml
dotnetAnalysis:
  endpoints:
  risks:
  tests:
  deploymentNotes:
```

## Backend Java

Analyze:

- Domain scoring logic.
- Maven configuration.
- Unit test coverage.
- Runtime entry point.
- Deployment container readiness.

Expected artifact:

```yaml
javaAnalysis:
  domainRules:
  tests:
  risks:
  deploymentNotes:
```

## Frontend Angular / TypeScript

Analyze:

- Standalone Angular component structure.
- Signal-based state.
- Risk classification display.
- Build configuration.
- Accessibility and UI test opportunities.

Expected artifact:

```yaml
frontendAnalysis:
  components:
  state:
  risks:
  tests:
  deploymentNotes:
```

## Operations

Analyze:

- Deployment path.
- Rollback.
- Monitoring.
- Maintenance tasks.
- ZIP artifact contents.

Expected artifact:

```yaml
operationsAnalysis:
  deployment:
  rollback:
  monitoring:
  maintenance:
  package:
```

