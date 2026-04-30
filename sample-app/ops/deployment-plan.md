# Deployment Plan

## Goal

Deploy the dummy sample app in a way that is simple enough for workflow tests and still realistic enough to exercise PDLC release gates.

## Components

| Component | Runtime | Default Port | Artifact |
|---|---|---|---|
| `dotnet-api` | .NET 8 | `5080` | container image or build output |
| `java-api` | Java 17 | `8081` | JAR or container image |
| `angular-frontend` | static web app | `4200` local / `80` container | Angular build output |

## Manual Deployment Steps

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\dotnet-api
dotnet publish -c Release -o .\publish
```

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\java-api
mvn package
```

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\angular-frontend
npm install
npm run build
```

## Docker Compose Deployment

The `docker-compose.yml` file is intentionally illustrative. It documents how the three components should be wired when containerized.

```powershell
cd C:\Repositories\design\AgentWorkflowPDLC\sample-app\ops
docker compose up --build
```

## Release Gate Checklist

- [ ] Build output exists for all changed components.
- [ ] Tests passed for all changed components.
- [ ] Risk card is linked in the issue.
- [ ] Rollback plan is documented.
- [ ] Monitoring checks are documented.
- [ ] ZIP package is generated when requested.

