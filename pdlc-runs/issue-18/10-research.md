# PDLC Research Agent

Issue: #18 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-18-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25262957808
Agent: research-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Artifact written. Summary:

**`pdlc-runs/issue-18/10-research.md`** — Status: READY.

Covers:
- **Algorytm 1 (Punktowy):** Penalty scoring na 4 cechach nieruchomości (wiek, kondygnacja, zabezpieczenia, historia szkód). Skala 0–100 → 4 klasy.
- **Algorytm 2 (Wagowy):** Ważona suma 4 wskaźników lokalizacyjnych (powódź 35%, pożar 25%, kradzieże 25%, gęstość 15%). Znormalizowane 0–100.
- **Algorytm 3 (Regułowy):** 5 reguł IF-THEN z priorytetem (pustostan+zaległy przegląd → critical; drewno+pożar ≥ 3 → min high; brak przeglądu → min high; suma > 5M PLN → min high).
- **API shape:** `POST /housing-risk/analyze` z pełnym request/response JSON i logiką rekomendacji (rule_override → majority → max_all).
- **4 otwarte decyzje** przekazane do etapu Architecture (progi, wagi, metoda rekomendacji domyślna).

Następny krok: `/pdlc analyze`