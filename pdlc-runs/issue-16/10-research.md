# PDLC Research Agent

Issue: #16 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-16-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25262463654
Agent: research-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Artifact written to `pdlc-runs/issue-16/10-research.md`.

---

Key findings:

- Existing `/risk-score` = PDLC autonomy risk only — housing algorithms are 100% greenfield
- Existing `RiskClass` + `classifyRisk()` reusable as-is
- Existing .NET minimal API = ready scaffold to extend
- All three algorithms → pure functions → full unit test coverage without mocks

Research covers: scoring table pattern (Alg 1), weighted exposure model (Alg 2), rule engine override pattern (Alg 3), recommended API contract (single `POST /housing-risk` returning all three results + recommendation), and 6 open questions for the analyst.

```text
/pdlc analyze
```