# Command-Driven PDLC Stage Agents

## Cel

Workflow PDLC obsługuje osobne komendy dla etapów poprzedzających kodowanie. Każdy etap uruchamia lokalne Claude Code na self-hosted Windows runnerze, zapisuje własny artefakt jako komentarz na GitHub Issue, a późniejszy coding worker dostaje te artefakty w promptcie przed implementacją.

## Komendy

```text
/pdlc research
/pdlc analyze
/pdlc risk
/pdlc architecture
/pdlc plan
/approve ai-coding
```

## Przepływ

```text
GitHub Issue
  -> /pdlc research -> local Claude Code stage worker
  -> /pdlc analyze -> local Claude Code stage worker
  -> /pdlc risk -> local Claude Code stage worker
  -> /pdlc architecture -> local Claude Code stage worker
  -> /pdlc plan -> local Claude Code stage worker
  -> /approve ai-coding
  -> PR with code, tests, docs, and PDLC artifacts
  -> human review
  -> /fix-review when needed
  -> merge
  -> release monitor
```

## Runtime

Workflow `.github/workflows/pdlc-agent-router.yml` najpierw rozpoznaje komendę, a potem uruchamia stage job na runnerze:

```text
self-hosted, Windows, X64, pdlc-worker
```

Skrypt `.github/scripts/pdlc-local-claude-stage-worker.ps1`:

- wykrywa komendę `/pdlc ...`,
- pobiera prompt agenta z `AgentWorkflowPDLC-AgentConfig`,
- znajduje albo tworzy długowieczny PR dla issue,
- zbiera wcześniejsze artefakty PDLC z plików w branchu PR,
- uruchamia lokalne `claude --print`,
- zapisuje artefakt etapu jako commit w tym samym PR.

## Agenci

- Research Agent tworzy kontekst researchowy na bazie issue i wcześniejszych założeń PDLC.
- Analyst Agent tworzy historyjki, acceptance criteria, zakres i pytania.
- Autonomy Risk Agent ocenia, czy feature może być robiony przez agenta, czy powinien przejąć go developer.
- Architect Agent definiuje obszary zmian, kontrakty, wpływ na architekturę i potrzebę ADR.
- Planner Agent tworzy plan implementacji dla workerów.

## Artefakty

Komentarze użytkownika są kanałem sterowania procesem. Artefakty agentów nie są już transportowane komentarzami. Każdy stage worker znajduje albo tworzy długowieczny PR powiązany z issue i zapisuje wynik jako plik w `pdlc-runs/issue-<number>/`.

W `pdlc-mode:semi-auto` człowiek wpisuje kolejne komendy. W `pdlc-mode:full-auto` agent po udanym etapie komentuje status i wysyła `repository_dispatch` z następną komendą, żeby kolejny etap uruchomił się automatycznie.

## Integracja Z Repo Konfiguracji

Stage worker pobiera repo `AgentWorkflowPDLC-AgentConfig` i czyta prompty agentów z manifestu. Repo można przełączyć zmiennymi:

```text
PDLC_AGENT_CONFIG_REPO
PDLC_AGENT_CONFIG_REF
```

Budżet dla stage workerów:

```text
PDLC_CLAUDE_STAGE_MAX_BUDGET_USD
```

## Decyzja O Autonomii

Risk Agent zwraca jedną z rekomendacji:

- `agent-autonomous` - agent może wykonać implementację po normalnej akceptacji.
- `agent-with-human-review` - agent może wykonać implementację, ale PR review musi być ścisłe.
- `human-dev-required` - developer powinien przejąć implementację, a agenci mogą pomóc analizą, testami lub dokumentacją.

## Test End-To-End

1. Załóż issue z szablonu `PDLC Agent Task`.
2. Dodaj komentarz `/pdlc research`.
3. Po komentarzu research dodaj `/pdlc analyze`.
4. Po analizie dodaj `/pdlc risk`.
5. Po risk card dodaj `/pdlc architecture`.
6. Po architekturze dodaj `/pdlc plan`.
7. Jeżeli plan i risk pozwalają na pracę agenta, dodaj `/approve ai-coding`.
8. Zreviewuj PR i użyj `/fix-review`, jeżeli trzeba.
