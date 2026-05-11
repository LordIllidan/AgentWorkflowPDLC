# PDLC Autonomy Risk Agent

Issue: #22 [PDLC] Generowanie rpaortów
Branch: agent/pdlc-issue-22-pdlc-generowanie-rpaort-w
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25688045541
Agent: risk-agent
Model: sonnet
Autonomy mode: semi-auto

## Agent Output

Mode: Semi-auto
Status: READY

---

# Karta Oceny Ryzyka Autonomii — Issue #22: Generowanie raportów

**Data oceny:** 2026-05-11  
**Agent:** risk-agent  
**Issue:** #22 — [PDLC] Generowanie rpaortów  
**Repozytorium:** AgentWorkflowPDLC

---

## Streszczenie decyzji

Zadanie obejmuje generowanie raportu z listy sprzedanych polis na podstawie tabeli `Polisy`. Zakres jest ograniczony (odczyt danych, transformacja, prezentacja), jednak brakuje kluczowych specyfikacji: formatu wyjściowego, zestawu pól, kontroli dostępu i wymagań RODO. Tabela `Polisy` z dużym prawdopodobieństwem zawiera dane osobowe ubezpieczonych (PII) — to podnosi wrażliwość danych do poziomu **wysokiego**.

Rekomendowany tryb: **Semi-auto**. Agenty mogą pracować nad każdym etapem, ale człowiek autoryzuje przejście po każdym artefakcie. Nie zaleca się trybu Full-auto ze względu na niejasne wymagania dotyczące bezpieczeństwa danych i brak sprecyzowanych kryteriów akceptacji.

---

## Czynniki ryzyka

| # | Czynnik | Poziom | Uzasadnienie |
|---|---------|--------|--------------|
| 1 | **Wrażliwość danych** | Wysoki | Tabela `Polisy` prawdopodobnie zawiera dane osobowe (imię, nazwisko, PESEL, adres, suma ubezpieczenia). Ryzyko naruszenia RODO przy złym projekcie raportu lub braku kontroli dostępu. |
| 2 | **Niekompletność wymagań** | Wysoki | Issue zawiera tylko jedno zdanie biznesowe. Brak: formatu wyjścia (PDF/CSV/XLSX/web), zakresu dat, filtrów, kolumn raportu, uprawnień ról. |
| 3 | **Kontrola dostępu** | Średni | Raport ze sprzedaży polis może być dostępny dla różnych ról (Manager, Underwriter, Coordinator). Brak specyfikacji, kto widzi jakie dane — ryzyko nadmiarowego ujawnienia. |
| 4 | **Złożoność techniczna** | Niski | Generowanie raportu to operacja odczytu — brak mutacji danych. Stosunkowo prosty zakres implementacji. |
| 5 | **Odwracalność** | Niski (pozytywny) | Operacja tylko do odczytu. Brak ryzyka uszkodzenia danych produkcyjnych. |
| 6 | **Testowalność** | Średni | Można weryfikować wynik względem znanych danych w tabeli. Jednak bez specyfikacji formatu i pól testy akceptacyjne są niemożliwe do napisania. |
| 7 | **Zasięg awarii (blast radius)** | Niski | Read-only. Najgorszy scenariusz: niepoprawny raport lub wyciek danych w raporcie — brak ryzyka uszkodzenia bazy. |

**Łączna ocena ryzyka: MEDIUM** (zgodna z initial risk guess).  
Czynnik podwyższający: potencjalne PII w tabeli Polisy.

---

## Ograniczenia autonomii agentów

| Etap PDLC | Dozwolona autonomia | Wymagana akcja człowieka |
|-----------|--------------------|-----------------------|
| Research | Pełna — agent może eksplorować schemat tabeli i repozytorium | Zatwierdzenie wyników przed kolejnym etapem |
| Requirements (Analityk) | Pełna — agent formułuje wymagania na podstawie kontekstu | **Obowiązkowe zatwierdzenie** — ze względu na PII i brak kryteriów |
| Architecture / ADR | Pełna — agent proponuje decyzje techniczne | **Obowiązkowe zatwierdzenie** — decyzje dot. bezpieczeństwa danych |
| Implementation Plan | Pełna | Zatwierdzenie przed kodowaniem |
| Test Plan | Pełna | Zatwierdzenie przed testami |
| Kodowanie (PR) | Semi-auto — agent generuje kod, otwiera PR | **Code review obowiązkowy** — ze względu na obsługę PII |
| Security Review | Pełna | Zatwierdzenie wyników przeglądu |
| Release | Brak autonomii — wymagana decyzja człowieka | Zawsze manualna decyzja o wdrożeniu |

---

## Punkty kontrolne człowieka (Human Checkpoints)

1. **Po etapie Requirements** — zatwierdzenie listy pól raportu, formatu wyjścia, zakresu dostępu ról. Gate: `Requirements approved`.
2. **Po etapie Architecture** — zatwierdzenie decyzji dot. anonimizacji/pseudonimizacji PII w raporcie, kontroli dostępu. Gate: `Architecture approved`.
3. **Code Review (PR)** — przegląd implementacji pod kątem wycieku danych, poprawności zapytań SQL/ORM. Gate: `Review approved`.
4. **Security Review** — weryfikacja czy raport nie eksponuje nadmiarowych danych. Gate: `Security approved`.
5. **Release** — manualna decyzja o wdrożeniu. Gate: `Release readiness approved`.

---

## Warunki zatrzymania (Stop Conditions)

Agent musi zatrzymać pracę i zgłosić blokadę, jeśli:

- Schemat tabeli `Polisy` zawiera kolumny jednoznacznie identyfikujące osoby fizyczne (PESEL, NIP, imię+nazwisko+adres) — wymagana konsultacja z DPO lub prawnikiem przed kontynuacją.
- Brak jakiejkolwiek warstwy autentykacji/autoryzacji w repozytorium — agent nie implementuje raportu bez istniejącej kontroli dostępu.
- Wymagania po etapie Research nadal niekompletne — agent nie przechodzi do Implementation Plan.
- PR generuje zapytanie zwracające wszystkie kolumny tabeli (`SELECT *`) bez jawnej listy pól — blokada code review.

---

## Założenia (do weryfikacji przez Analityka)

1. Tabela `Polisy` istnieje w bazie danych projektu AgentWorkflowPDLC (nie jest to zewnętrzny system).
2. „Sprzedane polisy" = polisy ze statusem wskazującym na finalizację sprzedaży (konkretna kolumna statusu do ustalenia).
3. Raport dotyczy prezentacji danych, nie ich modyfikacji.
4. Repozytorium AgentWorkflowPDLC to środowisko demo/workflow — jeśli to produkcja ubezpieczeniowa, ryzyko wzrasta do HIGH i tryb powinien być zmieniony na Developer.

---

## Następna komenda

```text
/pdlc research
```