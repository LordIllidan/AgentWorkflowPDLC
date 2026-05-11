# PDLC Autonomy Risk Agent

Issue: #24 [PDLC] Formularz dla zgłsozenia  szkody do polisy X
Branch: agent/pdlc-issue-24-pdlc-formularz-dla-zg-sozenia-szkody-do-polisy-x
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25689346040
Agent: risk-agent
Model: sonnet
Autonomy mode: semi-auto

## Agent Output

Mode: Semi-auto
Status: READY

# Karta Ryzyka Autonomii — Issue #24
## Formularz zgłoszenia szkody do polisy X

---

## Podsumowanie decyzji

Funkcjonalność obejmuje publiczny formularz przyjmowania szkód, zapis danych osobowych klientów do bazy danych, integrację z kanałami Teams/Slack oraz mechanizm przypomnień i eskalacji do managera. Wszystkie te elementy razem tworzą poziom ryzyka **MEDIUM**, przy czym komponent danych osobowych (RODO/GDPR) i integracje zewnętrzne wymagają obligatoryjnych bram ludzkich przed wdrożeniem.

Agenci mogą bezpiecznie realizować kolejne etapy PDLC (research, requirements, architecture, implementation, tests), ale każdy etap wymaga zatwierdzenia przez człowieka przed przejściem do następnego. Nie dopuszcza się trybu Full-auto ze względu na przetwarzanie PII i zapis do bazy produkcyjnej.

---

## Czynniki ryzyka

| # | Czynnik | Poziom | Uzasadnienie |
|---|---------|--------|--------------|
| 1 | **Dane osobowe (PII)** | 🔴 WYSOKI | Formularz zbiera imię/nazwisko, dane kontaktowe, opis szkody — wszystko podlega RODO. Konieczna ocena: podstawa prawna przetwarzania, czas retencji, sposób szyfrowania w bazie. |
| 2 | **Integracja zewnętrzna (Teams / Slack)** | 🟡 ŚREDNI | Wiadomości wysyłane na wspólny kanał zawierają dane klienta. Konieczne: weryfikacja konfiguracji kanału (dostęp), format komunikatu bez nadmiarowych PII, obsługa błędów przy niedostępności webhooków. |
| 3 | **Zapis do bazy danych** | 🟡 ŚREDNI | Trwały zapis — operacja nieodwracalna bez jawnego usunięcia. Wymaga definicji schematu, indeksów, reguł walidacji po stronie backendu i polityki retencji. |
| 4 | **Logika przypomnień / eskalacji** | 🟡 ŚREDNI | Harmonogram: 1h → przypomnienie, 2h → notyfikacja do managera. Wymaga niezawodnego mechanizmu (job scheduler / queue), obsługi przypadków brzegowych (agent podejmie po 1h59min, manager już powiadomiony?), idempotentności. |
| 5 | **Bezpieczeństwo formularza publicznego** | 🟡 ŚREDNI | Formularz dostępny publicznie — ryzyko spamu, brute-force po numerze polisy, nadużycia API. Wymagane: rate limiting, CAPTCHA lub inna weryfikacja, walidacja numeru polisy. |
| 6 | **Złożoność techniczna** | 🟢 NISKI-ŚREDNI | Standardowy CRUD + integracje. Nie wymaga algorytmów ML ani skomplikowanej logiki domenowej. Dobrze zdefiniowany zakres. |
| 7 | **Odwracalność** | 🟡 ŚREDNI | Zgłoszenie zapisane w bazie i wiadomość wysłana na kanał — częściowo nieodwracalne. Soft-delete może być wymagany dla zgłoszeń testowych. |
| 8 | **Testowalność** | 🟡 ŚREDNI | Logika formularza i walidacja — łatwo testowalne. Timing (1h/2h) i integracje zewnętrzne — wymagają mockowania i testów integracyjnych. |

---

## Limity autonomii agentów

Agenci **MOGĄ** autonomicznie:
- Analizować wymagania i przygotować specyfikację (research + requirements)
- Zaprojektować schemat bazy danych i kształt API
- Napisać kod formularza, serwisu, logiki przypomnień
- Wygenerować testy jednostkowe i integracyjne
- Przygotować dokumentację

Agenci **NIE MOGĄ** autonomicznie:
- Zadecydować o podstawie prawnej przetwarzania danych (wymaga prawnika / DPO)
- Wybrać konkretnego kanału Teams/Slack ani konfigurować webhooków w środowiskach produkcyjnych
- Zdefiniować polityki retencji danych bez zatwierdzenia biznesowego
- Wdrożyć na środowisko produkcyjne
- Pominąć bramę security-review (obowiązkowa dla formularzy publicznych z PII)

---

## Bramy ludzkie (checkpoints)

| Etap PDLC | Wymagane zatwierdzenie | Powód |
|-----------|----------------------|-------|
| Requirements | ✅ Obligatoryjne | Doprecyzowanie: które dane osobowe, podstawa prawna RODO, czas retencji, role mające dostęp do kanału |
| Architecture / ADR | ✅ Obligatoryjne | Wybór mechanizmu harmonogramu (cron job, message queue, hangfire?), decyzja o architekturze powiadomień |
| Implementation PR | ✅ Obligatoryjne | Code review ze szczególnym uwzględnieniem walidacji wejścia i obsługi PII |
| Security review | ✅ **OBOWIĄZKOWE** | Formularz publiczny + PII = bezwzględny wymóg security review przed merge |
| QA | ✅ Obligatoryjne | Weryfikacja scenariuszy timing (1h/2h), edge cases, testy na środowisku staging |
| Release | ✅ Obligatoryjne | Go/no-go od managera przed wdrożeniem produkcyjnym |

---

## Warunki zatrzymania (stop conditions)

Proces należy **zatrzymać i eskalować** jeśli:

1. Analiza requirements wykaże brak zdefiniowanej podstawy prawnej RODO dla zbieranych danych — bez tego żaden kod nie może być pisany.
2. Nie istnieje środowisko staging z odizolowaną bazą danych — testy z prawdziwymi danymi klientów są niedopuszczalne.
3. Kanał Teams/Slack przeznaczony na zgłoszenia nie ma ograniczonego dostępu (tylko agenci/managerowie) — wyciek PII klientów.
4. Security review zwróci krytyczne lub wysokie wyniki bez planu naprawczego.
5. Brak mechanizmu soft-delete lub anonimizacji zgłoszeń po upływie okresu retencji.

---

## Następne polecenie

```
/pdlc research
```