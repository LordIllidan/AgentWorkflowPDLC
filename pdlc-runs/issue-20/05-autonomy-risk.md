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

---

# Ocena Ryzyka Autonomii — Issue #20
## PDLC: Dodać 3 algorytmy analizy ryzyk w mieszkalnictwie

**Data:** 2026-05-03  
**Agent:** risk-agent  
**Issue:** [#20](https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20)

---

## Podsumowanie Decyzji

Zadanie polega na implementacji trzech deterministycznych algorytmów oceny ryzyka mieszkalnictwa w aplikacji przykładowej (`insurance-x`). Zakres jest dobrze zdefiniowany: wejścia i wyjścia każdego algorytmu są opisane w treści issue, kryteria akceptacji są mierzalne, a zmiana nie dotyka infrastruktury produkcyjnej, danych wrażliwych ani systemów zewnętrznych.

**Rekomendacja:** `agent-autonomous` (Full-auto). Agenty mogą samodzielnie przechodzić przez kolejne etapy PDLC po zatwierdzeniu każdego artefaktu. Wymagane są trzy checkpointy ludzkie opisane poniżej.

---

## Czynniki Ryzyka

| # | Wymiar | Poziom | Uzasadnienie |
|---|--------|--------|--------------|
| 1 | Wpływ biznesowy | **Niski** | Aplikacja przykładowa (`insurance-x`), brak użytkowników produkcyjnych. Błąd w algorytmie nie powoduje straty finansowej ani prawnej. |
| 2 | Złożoność techniczna | **Niski–Średni** | Trzy oddzielne algorytmy: punktowy, wagowy, regułowy. Logika deterministyczna, formuły algebraiczne. Brak ML, brak zewnętrznych API. |
| 3 | Odwracalność | **Pełna** | Nowe pliki i endpointy. Rollback = usunięcie brancha. Brak migracji schematu bazy danych. |
| 4 | Wrażliwość danych | **Brak** | Algorytmy operują na cechach nieruchomości (wiek, kondygnacja, lokalizacja). Brak PII, brak danych medycznych, brak haseł. |
| 5 | Wpływ na bezpieczeństwo | **Brak** | Nowe endpointy GET/POST dla kalkulacji ryzyka. Brak zmiany autentykacji, autoryzacji ani ACL. |
| 6 | Testowalność | **Wysoka** | Algorytmy deterministyczne — te same dane wejściowe zawsze dają ten sam wynik. Testy jednostkowe są proste do wygenerowania. |
| 7 | Blast radius | **Niski** | Zmiany izolowane do nowego modułu `RiskAlgorithms` (backend) i nowego komponentu porównania (frontend). Istniejące funkcje nie są modyfikowane. |
| 8 | Zgodność / compliance | **Brak** | Aplikacja przykładowa, brak regulatora, brak wymagań GDPR ponad to co już istnieje w projekcie. |

**Całkowita ocena ryzyka: NISKA**

---

## Kontrakt API — Kształt Danych

Wszystkie trzy algorytmy powinny być obsługiwane przez jeden endpoint z wynikami osobno:

```
POST /api/risk/housing/evaluate
```

**Request body:**
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

**Response body:**
```json
{
  "algorithms": {
    "pointBased": {
      "score": 62,
      "classification": "medium",
      "breakdown": {
        "buildingAge": 15,
        "floor": 5,
        "security": -8,
        "claims": 50
      }
    },
    "weightBased": {
      "score": 0.71,
      "classification": "high",
      "breakdown": {
        "flood": 0.18,
        "fire": 0.08,
        "theft": 0.28,
        "density": 0.17
      }
    },
    "ruleBased": {
      "classification": "medium",
      "triggeredRules": ["MISSING_INSPECTIONS"],
      "blockedRules": []
    }
  },
  "recommended": {
    "classification": "high",
    "rationale": "Algorytm wagowy wskazuje wysokie ryzyko kradzieży w strefie miejskiej; algorytm regułowy sygnalizuje brak przeglądów."
  }
}
```

---

## Formuły Algorytmów

### Algorytm 1: Punktowy (PropertyScoreAlgorithm)

```
score = base_score
      + age_penalty(buildingAge)
      + floor_factor(floor, totalFloors)
      - security_discount(securityLevel)
      + claims_penalty(claimsLast5Years)

gdzie:
  age_penalty:   <10 lat → 0, 10–30 → 10, 31–50 → 20, >50 → 35
  floor_factor:  parter/1 → 10, 2–4 → 5, 5–9 → 0, 10+ → -5
  security_discount: brak → 0, basic → 5, medium → 10, high → 20
  claims_penalty: 0 szkód → 0, 1 → 20, 2 → 40, 3+ → 60

Klasyfikacja:
  score < 30       → low
  30 ≤ score < 60  → medium
  60 ≤ score < 90  → high
  score ≥ 90       → critical
```

### Algorytm 2: Wagowy (LocationWeightAlgorithm)

```
score = w_flood * flood_score(floodZone)
      + w_fire  * fire_score(fireRiskZone)
      + w_theft * theft_score(theftRiskZone)
      + w_density * density_score(buildingDensity)

Wagi: w_flood=0.30, w_fire=0.20, w_theft=0.35, w_density=0.15

Mapowania stref (0.0–1.0):
  floodZone:       A → 1.0, B → 0.6, C → 0.3, none → 0.0
  fireRiskZone:    high → 1.0, medium → 0.5, low → 0.1
  theftRiskZone:   high → 1.0, medium → 0.5, low → 0.1
  buildingDensity: urban → 0.8, suburban → 0.4, rural → 0.1

Klasyfikacja:
  score < 0.25  → low
  0.25 ≤ score < 0.50 → medium
  0.50 ≤ score < 0.75 → high
  score ≥ 0.75        → critical
```

### Algorytm 3: Regułowy (SpecialCaseRuleAlgorithm)

```
Reguły (każda może podnieść klasyfikację do minimum danego poziomu):

  VACANT_PROPERTY:      isVacant=true          → minimum: high
  WOODEN_STRUCTURE:     isWoodenStructure=true → minimum: high
  MISSING_INSPECTIONS:  missingInspections=true → minimum: medium
  HIGH_INSURED_SUM:     insuredSumPLN > 500000  → minimum: medium

Wynik = najwyższy poziom spośród wszystkich wyzwolonych reguł.
Jeśli żadna reguła nie wyzwolona → low.
```

### Logika Rekomendacji

```
recommended = max(pointBased, weightBased, ruleBased)

Jeżeli co najmniej dwa algorytmy wskazują ten sam poziom → wynik tej klasy.
Jeżeli wszystkie trzy różne → poziom środkowy z adnotacją "rozbieżność algorytmów".
```

---

## Limity Autonomii

Agenty **mogą** samodzielnie:
- Zaimplementować wszystkie trzy algorytmy i logikę rekomendacji po zatwierdzonym planie.
- Napisać testy jednostkowe dla wszystkich formuł i reguł.
- Zbudować komponent Angular porównujący wyniki.
- Napisać dokumentację techniczną algorytmów.

Agenty **nie mogą** bez ludzkiego zatwierdzenia:
- Zmieniać wag algorytmu wagowego na wartości inne niż te z issue (jeśli pojawi się wątpliwość, zatrzymać i zapytać).
- Modyfikować istniejących endpointów API — tylko dodawać nowe.
- Zmieniać struktury nawigacji (`NAV` w `core/role.ts`) poza dodaniem jednej pozycji dla widoku porównania ryzyk.
- Mergować PR do `main`.

---

## Checkpointy Ludzkie

| # | Etap | Wymagane działanie | Uzasadnienie |
|---|------|--------------------|--------------|
| CP-1 | Po artefakcie `architecture` | Zatwierdzić kształt API i nazwy endpointów | Kontrakt API jest bazą dla frontendu i backendu — zmiana po implementacji kosztuje. |
| CP-2 | Po artefakcie `plan` | Zatwierdzić podział zadań i kolejność | Upewnić się, że implementacja frontendu nie startuje przed stabilnym API. |
| CP-3 | Przed merge do `main` | Code review PR | Weryfikacja poprawności formuł, kompletności testów, zgodności z design.md. |

---

## Warunki Zatrzymania

Agent powinien wstrzymać się i zgłosić blokadę (`Status: BLOCKED_QUESTIONS`) jeśli:

1. Istniejąca struktura backendu w `insurance-x/` jest niezgodna z REST (np. brak warstwy kontrolerów lub inny routing).
2. Projekt nie ma `.NET` backendu (proxy idzie na `localhost:5125`) — algorytmy muszą tam trafić, nie do Angular.
3. Wymagania co do jednostek `insuredSumPLN` są inne niż PLN (np. jest już konwersja walut w projekcie).

---

## Następny Krok

```
/pdlc research
```