# PDLC — logi CI i zapis sesji Claude Code

## Cel

Wspólny skrypt **`.github/scripts/pdlc-claude-diagnostics.ps1`** jest wczytywany przez workery Claude Code (`pdlc-local-claude-review-fix-worker.ps1`, `pdlc-local-claude-worker.ps1`, `pdlc-local-claude-stage-worker.ps1`) i zapewnia:

1. **Widoczność w logu GitHub Actions** — przy błędzie CLI (w tym rate limit / quota) do konsoli trafiają linie `::error::…` (adnotacja w UI) oraz pełny blok stdout/stderr między separatorami `PDLC Claude stdout/stderr`.
2. **Zapis w repozytorium** — po każdym wywołaniu `claude` w katalogu runu PDLC (`pdlc-runs/...`) pojawia się:
   - plik **`--debug-file`** (log debug API Claude Code),
   - podkatalog **`claude-sessions/<RunId>/`** z README oraz kopią wybranych plików `*.jsonl` / `*.json` z `%USERPROFILE%\.claude\projects\` powiązanych z bieżącym workspace (heurystyka czasu i ścieżki).

## Zmienna środowiskowa

| Zmienna | Domyślnie | Znaczenie |
|--------|-------------|-----------|
| `PDLC_PUSH_CLAUDE_DIAGNOSTICS_ON_FAILURE` | *(nie ustawiona = włączone)* | Jeśli ustawisz na `false`, worker **nie** zrobi dodatkowego commita z diagnostyką przy niepowodzeniu (tylko pliki lokalnie na runnerze). |

Gdy zmienna **nie** jest `false`, po nieudanym runie worker próbuje **commit + push** tylko plików diagnostycznych (sesje, debug, prompty/output z run id), żeby dało się do nich wrócić z poziomu PR.

## Gdzie szukać po runie

- **Issue / coding:** `pdlc-runs/issue-<nr>/claude-sessions/<RunId>/`, `claude-code-debug-<RunId>.log`
- **Review-fix:** `pdlc-runs/pr-<nr>/claude-sessions/<RunId>/`, `claude-review-fix-debug-<RunId>.log`
- **Stage:** `pdlc-runs/issue-<nr>/claude-sessions/<GitHubRunId>-<stage>-run1|run2>/`, logi `claude-stage-<stage>-run1|2-<RunId>.log`

## Uwagi

- Kopia JSONL zależy od tego, czy Claude Code zapisuje sesję na dysku (domyślnie tak, o ile nie użyto `--no-session-persistence`).
- Pełna „konwersacja” może być rozproszona po wielu plikach w `.claude\projects\`; skrypt kopiuje pliki zmodyfikowane w oknie czasowym wokół startu wywołania (do limitu liczby plików).

