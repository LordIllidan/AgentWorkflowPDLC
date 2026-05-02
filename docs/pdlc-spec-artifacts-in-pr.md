# PDLC Long-Lived Spec Pull Requests

## Cel

Wyniki pracy agentów PDLC mają być zapisywane w jednym długowiecznym PR powiązanym z issue. PR jest źródłem prawdy dla spec-driven development.

## Przepływ Kontekstu

Po utworzeniu issue zawsze uruchamia się agent oceny ryzyka autonomii. Agent taguje issue jednym z trybów:

- `pdlc-mode:developer` - zadanie ma realizować developer,
- `pdlc-mode:semi-auto` - domyślny tryb sterowany komentarzami,
- `pdlc-mode:full-auto` - agenci po zakończeniu etapu sami dispatchują kolejny krok.

Każdy stage agent najpierw szuka otwartego PR powiązanego z issue. Jeśli PR nie istnieje, agent tworzy branch i PR. Jeśli PR istnieje, agent checkoutuje jego branch i dopisuje kolejny artefakt.

Komentarze issue służą tylko do sterowania i statusu. Nie są źródłem prawdy dla kolejnych agentów.

```text
pdlc-runs/issue-<number>/00-issue.md
pdlc-runs/issue-<number>/05-autonomy-risk.md
pdlc-runs/issue-<number>/10-research.md
pdlc-runs/issue-<number>/20-analysis.md
pdlc-runs/issue-<number>/40-architecture.md
pdlc-runs/issue-<number>/50-plan.md
pdlc-runs/issue-<number>/60-implementation.md
```

## Znaczenie

PR zawiera wtedy zarówno kod, jak i kontekst decyzyjny:

- research,
- user stories,
- risk/autonomy decision,
- architecture boundaries,
- implementation plan,
- implementation summary,
- konfigurację agentów i runtime.

Reviewer nie musi rekonstruować procesu z komentarzy issue. Może czytać spec bezpośrednio w diffie PR.

## Zasada

Jeden issue ma jeden długowieczny PR. Każdy agent dopisuje commit do tego samego PR.
