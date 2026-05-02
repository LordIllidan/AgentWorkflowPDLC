# PDLC Agent Router

## Cel

`PDLC Agent Router` jest centralnym workflowem GitHub Actions dla procesu PDLC. Zamiast kilku workflowów nasłuchujących na te same eventy, jeden router odbiera event, rozpoznaje intencję i uruchamia właściwy job.

## Problem, Który Rozwiązuje

Poprzedni układ uruchamiał kilka workflowów dla jednego zdarzenia. Przykład: issue utworzone z labelami generowało `opened`, `labeled`, `labeled`, więc analiza i status odpalały się kilka razy równolegle. Przy komendzie w komentarzu startowało kilka workflowów, z których większość kończyła się jako `skipped`.

Router ogranicza to do jednego runu `PDLC Agent Router`.

## Decyzje Routingu

| Event | Warunek | Job |
|---|---|---|
| `issues` | nowe zwykłe issue | `risk-assessment` |
| `repository_dispatch` | `pdlc_issue_created` | `risk-assessment` |
| `repository_dispatch` | `pdlc_stage_command` z komendą stage | `stage-agent` |
| `repository_dispatch` | `pdlc_stage_command` z `/approve ai-coding` | `local-coding` |
| `workflow_dispatch` | input `command` z komendą stage | `stage-agent` |
| `workflow_dispatch` | input `command` z `/approve ai-coding` | `local-coding` |
| `issue_comment` | `/pdlc research`, `/pdlc analyze`, `/pdlc risk`, `/pdlc architecture`, `/pdlc plan` | `stage-agent` |
| `issue_comment` | `/pdlc answer` z `stage: <stage>` | `stage-agent` |
| `issue_comment` | `/approve ai-coding` | `local-coding` |
| `push` | commit message `[PDLC #16] /pdlc analyze` | `stage-agent` |
| `push` | commit message `[PDLC issue:16] /approve ai-coding` | `local-coding` |
| `issue_comment` na PR | `/fix-review` | `review-fix` |
| `pull_request_review_comment` | `/fix-review` | `review-fix` |
| `pull_request_review` | `/fix-review` | `review-fix` |

## Pliki

- `.github/workflows/pdlc-agent-router.yml` - jeden centralny workflow.
- `.github/scripts/pdlc-agent-router.mjs` - skrypt decyzyjny, który wystawia outputy routingu.
- Skrypty wykonawcze AI pozostają osobne: `pdlc-local-claude-stage-worker.ps1`, `pdlc-local-claude-worker.ps1`, `pdlc-local-claude-review-fix-worker.ps1`.

## Zasada

Router decyduje, który agent działa w danym momencie. Agenci wykonawczy nie nasłuchują już bezpośrednio na eventy GitHuba jako osobne workflowy.

Nowe issue zawsze przechodzi przez ocenę ryzyka autonomii. Tryb `pdlc-mode:full-auto` używa `workflow_dispatch` z inputami `issue_number` i `command`, ponieważ komentarze utworzone przez `GITHUB_TOKEN` nie są pewnym mechanizmem odpalania kolejnych workflowów.
