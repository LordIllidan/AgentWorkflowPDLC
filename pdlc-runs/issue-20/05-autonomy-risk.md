# PDLC Autonomy Risk Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25263118093
Agent: risk-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Mode: Full-auto
Status: READY

# Ocena Ryzyka Autonomii — Issue #20
## PDLC: Dodać 3 algorytmy analizy ryzyk w mieszkalnictwie

**Data:** 2026-05-03
**Agent:** risk-agent
**Issue:** [#20](https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20)

---

## Podsumowanie Decyzji

Zadanie polega na implementacji trzech deterministycznych algorytmów oceny ryzyka mieszkalnictwa w aplikacji przykładowej (`sample-app`). Zakres jest precyzyjnie zdefiniowany: dane wejściowe i wyjściowe każdego algorytmu są opisane w treści issue, kryteria akceptacji są mierzalne, formuły są zamknięte algebraicznie, a zmiana nie dotyka infrastruktury produkcyjnej, danych wrażliwych, systemów zewnętrznych ani istniejących endpointów.

**Rekomendacja: `Full-auto`.** Agenty mogą samodzielnie przechodzić przez kolejne etapy PDLC po wyprodukowaniu każdego artefaktu. Wymagane są trzy ludzkie checkpointy opisane poniżej — CP-3 (code review przed merge) jest obowiązkowy.

---

## Czynniki Ryzyka

| # | Wymiar | Poziom | Uzasadnienie |
|---|--------|--------|--------------|
| 1 | Wpływ biznesowy | **Niski** | Aplikacja przykładowa (`sample-app`), brak użytkowników produkcyjnych. Błąd w algorytmie nie powoduje straty finansowej, prawnej ani reputacyjnej. |
| 2 | Złożoność techniczna | **Niski–Średni** | Trzy oddzielne algorytmy: punktowy (sumowanie składowych), wagowy (iloczyn wektora wag i wartości stref), regułowy (reguły binarne z minimum). Logika deterministyczna, formuły zamknięte. Brak ML, brak zewnętrznych API, brak integracji rejestrów. |
| 3 | Odwracalność | **Pełna** | Wyłącznie nowe pliki i nowe endpointy. Rollback = revert commits lub zamknięcie PR. Brak migracji schematu bazy danych; brak modyfikacji istniejącego endpointu `/risk-score`. |
| 4 | Wrażliwość danych | **Brak** | Algorytmy operują na cechach fizycznych nieruchomości: wiek budynku, piętro, strefy zagrożeń, flagi techniczne. Brak PII, brak danych medycznych, brak haseł, brak PESEL, brak danych finansowych o osobach. `insuredSumPLN` to liczba całkowita opisująca wartość nieruchomości — nie jest to transakcja ani dane osobowe. |
| 5 | Wpływ na bezpieczeństwo | **Brak** | Nowy endpoint `POST /api/risk/housing/evaluate` przyjmuje liczby i wartości enum. Backend używa typowanych rekordów C# i `System.Text.Json` — brak SQL, brak shell injection, brak template rendering. Brak zmiany autentykacji, autoryzacji ani ACL. |
| 6 | Testowalność | **Wysoka** | Algorytmy deterministyczne — te same dane wejściowe zawsze dają ten sam wynik. Progi klasyfikacyjne i reguły binarne dają się łatwo pokryć testami jednostkowymi. xUnit dla backendu .NET, Vitest dla Angular. |
| 7 | Blast radius | **Niski** | Zmiany izolowane do nowego podkatalogu `Housing/` (backend) i nowego podkatalogu `housing/` (frontend). Modyfikacje plików istniejących minimalne: `Program.cs` (jeden nowy `app.MapPost`), `main.ts` (jedna linia `provideHttpClient()`), `app.component.ts` (import i tag komponentu). |
| 8 | Zgodność / compliance | **Brak** | Aplikacja przykładowa, brak regulatora, brak wymagań GDPR ponad istniejący stan projektu. |
| 9 | Zależności zewnętrzne | **Brak** | Algorytmy nie integrują się z GUS, IMGW, ISOK ani żadnym zewnętrznym rejestrem. Dane wejściowe dostarcza użytkownik ręcznie przez formularz. |

**Całkowita ocena ryzyka: NISKA**

---

## Kontrakt API — Kształt Danych

Endpoint:
```
POST /api/risk/housing/evaluate
Content-Type: application/json
```

**Request:**
```json
{
  "buildingAge": 35,
  "floor": 3,
  "totalFloors": 10,
  "securityLevel": "medium",
  "claimsLast5Years": 1,
  "location": {
    "floodZone": "B",
    "fireRiskZone": "low",
    "theftRiskZone": "high",
    "buildingDensity": "urban"
  },
  "specialFlags": {
    "isVacant": false,
    "isWoodenStructure": false,
    "missingInspections": true,
    "insuredSumPLN": 450000
  }
}
```

**Response `200 OK`:**
```json
{
  "algorithms": {
    "pointBased": {
      "score": 35,
      "classification": "medium",
      "breakdown": {
        "agePenalty": 20,
        "floorFactor": 5,
        "securityDiscount": 10,
        "claimsPenalty": 20
      }
    },
    "weightBased": {
      "score": 0.67,
      "classification": "high",
      "breakdown": {
        "flood": 0.18,
        "fire": 0.02,
        "theft": 0.35,
        "density": 0.12
      }
    },
    "ruleBased": {
      "classification": "medium",
      "triggeredRules": ["MISSING_INSPECTIONS"],
      "blockedRules": ["VACANT_PROPERTY", "WOODEN_STRUCTURE", "HIGH_INSURED_SUM"]
    }
  },
  "recommended": {
    "classification": "high",
    "rationale": "Algorytm wagowy wskazuje wysokie ryzyko kradzieży w strefie miejskiej (0.67). Algorytm regułowy sygnalizuje brak przeglądów technicznych."
  }
}
```

---

## Formuły Algorytmów

### ALG-1 — PropertyScoreAlgorithm (punktowy)

```
score = age_penalty(buildingAge)
      + floor_factor(floor, totalFloors)
      − security_discount(securityLevel)
      + claims_penalty(claimsLast5Years)

age_penalty:
  < 10 lat → 0 | 10–30 → 10 | 31–50 → 20 | > 50 → 35

floor_factor:
  floor ≤ 1 → 10 | 2–4 → 5 | 5–9 → 0 | ≥ 10 → −5

security_discount:
  none → 0 | basic → 5 | medium → 10 | high → 20

claims_penalty:
  0 → 0 | 1 → 20 | 2 → 40 | ≥ 3 → 60

Klasyfikacja:
  score < 30              → low
  30 ≤ score < 60         → medium
  60 ≤ score < 90         → high
  score ≥ 90              → critical
  (wynik ujemny < 30 → low)
```

### ALG-2 — LocationWeightAlgorithm (wagowy)

```
score = 0.30 × flood_score(floodZone)
      + 0.20 × fire_score(fireRiskZone)
      + 0.35 × theft_score(theftRiskZone)
      + 0.15 × density_score(buildingDensity)

flood_score:   A=1.0, B=0.6, C=0.3, none=0.0
fire_score:    high=1.0, medium=0.5, low=0.1
theft_score:   high=1.0, medium=0.5, low=0.1
density_score: urban=0.8, suburban=0.4, rural=0.1

Klasyfikacja:
  score < 0.25              → low
  0.25 ≤ score < 0.50       → medium
  0.50 ≤ score < 0.75       → high
  score ≥ 0.75              → critical
```

### ALG-3 — SpecialCaseRuleAlgorithm (regułowy)

```
Reguły binarne — każda wymusza minimalny poziom:
  VACANT_PROPERTY:     isVacant = true          → minimum: high
  WOODEN_STRUCTURE:    isWoodenStructure = true → minimum: high
  MISSING_INSPECTIONS: missingInspections = true → minimum: medium
  HIGH_INSURED_SUM:    insuredSumPLN > 500 000  → minimum: medium
  (warunek ścisły: 500 000 nie wyzwala; 500 001 wyzwala)

wynik = max(wszystkie minima wyzwolonych reguł)
żadna reguła → low
Porządek: low < medium < high < critical
```

### Logika rekomendacji

```
recommended = max(alg1.classification, alg2.classification, alg3.classification)

rationale:
  critical w jakimkolwiek     → "Algorytm {X} wskazuje ryzyko krytyczne."
  wszystkie trzy równe        → "Wszystkie algorytmy zgodne: {klasa}."
  dwa zgodne, jeden niższy    → "Algorytm {X} i {Y} wskazują {klasa}."
  wszystkie różne             → "Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."
```

---

## Limity Autonomii

Agenty **mogą** samodzielnie:
- Przejść przez wszystkie etapy PDLC: research → analyze → architecture → plan → implementation.
- Zaimplementować wszystkie trzy algorytmy i logikę rekomendacji zgodnie z kontraktem powyżej.
- Napisać testy jednostkowe pokrywające każdy próg klasyfikacyjny i każdą regułę binarną.
- Zbudować komponent Angular `HousingRiskComponent` z formularzem i widokiem porównania.
- Napisać dokumentację techniczną opisującą założenia, formuły i przykładowe dane.

Agenty **nie mogą** bez ludzkiego zatwierdzenia:
- Zmieniać wag algorytmu wagowego na wartości inne niż: `flood=0.30, fire=0.20, theft=0.35, density=0.15`.
- Modyfikować istniejących endpointów API — wyłącznie dodawać nowe.
- Modyfikować istniejącego `RiskClass` w `risk-summary.ts` — nowy typ `HousingRiskClass` jest oddzielny.
- Mergować PR do gałęzi `main`.
- Dodawać klasy `regulated` do `HousingRiskClass` (ta klasa należy do domeny PDLC, nie mieszkalnictwa).

---

## Checkpointy Ludzkie

| # | Etap | Wymagane działanie | Uzasadnienie |
|---|------|--------------------|--------------|
| CP-1 | Po artefakcie `architecture` | Zatwierdzić kształt API, nazwy endpointów i typy domenowe | Kontrakt API jest bazą dla obu stosów — zmiana po implementacji kosztuje refaktoring w dwóch miejscach jednocześnie. |
| CP-2 | Po artefakcie `plan` | Zatwierdzić kolejność kroków implementacji i warunki ukończenia | Upewnić się, że implementacja frontendu nie startuje przed stabilnym API backendu. |
| CP-3 | Przed merge do `main` | Code review PR — weryfikacja poprawności formuł, kompletności testów, zgodności z design systemem | Gwarancja poprawności matematycznej algorytmów i deterministyczności wyników przed wejściem do `main`. |

---

## Warunki Zatrzymania

Agent powinien wstrzymać się i zgłosić `Status: BLOCKED_QUESTIONS` jeśli:

1. `sample-app/dotnet-api/` nie istnieje lub nie jest projektem .NET — algorytmy muszą trafić do backendu, nie do Angular.
2. Istniejący `Program.cs` nie używa Minimal API (`app.MapPost`) — inna architektura routingu wymaga ręcznej decyzji o integracji.
3. `src/main.ts` w Angular używa `bootstrapModule` zamiast `bootstrapApplication` — inna ścieżka integracji `HttpClient`.
4. Wymagania dotyczące progu `HIGH_INSURED_SUM` są inne niż `> 500 000 PLN` (np. inna waluta lub inny próg).
5. Wagi algorytmu wagowego mają być inne niż podane w issue — agent zatrzymuje się i pyta zamiast samodzielnie dobierać wartości.

---

## Następny krok

```
/pdlc research
```