# PDLC Analyst Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25272204074
Agent: analyst-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Status: READY

# PDLC Analiza — Issue #20: Trzy algorytmy analizy ryzyk w mieszkalnictwie

**Data:** 2026-05-03
**Agent:** analyst-agent
**Issue:** [#20](https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20)
**Poprzednie etapy:** `05-autonomy-risk.md`, `10-research.md`

---

## Zakres Produktowy

### Co jest w zakresie

System oceny ryzyka mieszkalnictwa złożony z trzech niezależnych algorytmów zaimplementowanych w aplikacji przykładowej (`sample-app`). Każdy algorytm stosuje inną metodologię i zwraca wynik osobno. Backend udostępnia jeden endpoint REST; frontend prezentuje porównanie wyników i rekomendację końcową.

| Komponent | Lokalizacja | Zmiana |
|-----------|-------------|--------|
| Backend .NET 8 | `sample-app/dotnet-api/Program.cs` + nowe klasy `Housing/` | Nowy endpoint `POST /api/risk/housing/evaluate` |
| Frontend Angular 20 | `sample-app/angular-frontend/` | Nowy standalone component `HousingRiskComponent` + serwis `HousingRiskService` |
| Typy | `sample-app/angular-frontend/housing-risk.types.ts` | Nowe typy `HousingRiskClass`, `HousingEvaluationRequest`, `HousingEvaluationResponse` |
| Testy backend | `sample-app/dotnet-api/` | xUnit — testy jednostkowe każdego algorytmu |
| Testy frontend | `sample-app/angular-frontend/` | Vitest — testy serwisu i komponentu |
| Dokumentacja | `sample-app/docs/housing-risk-algorithms.md` | Opis założeń i przykładowych danych wejściowych |

### Trzy algorytmy

| ID algorytmu | Klasa | Metodologia | Dane wejściowe |
|---|---|---|---|
| `ALG-1` | `PropertyScoreAlgorithm` | Punktowy — cechy nieruchomości | Wiek, piętro, zabezpieczenia, historia szkód |
| `ALG-2` | `LocationWeightAlgorithm` | Wagowy — lokalizacja i ekspozycja | Strefy: powódź, pożar, kradzież, gęstość zabudowy |
| `ALG-3` | `SpecialCaseRuleAlgorithm` | Regułowy — przypadki specjalne | Pustostan, drewno, brak przeglądów, suma ubezpieczenia |

---

## Historie Użytkownika

| ID | Rola | Potrzeba | Wartość biznesowa |
|----|------|----------|-------------------|
| US-01 | Inżynier Ryzyka | Chcę wprowadzić dane nieruchomości i zobaczyć wynik algorytmu punktowego osobno | Ocena cech fizycznych budynku bez szumu danych lokalizacyjnych |
| US-02 | Inżynier Ryzyka | Chcę zobaczyć wynik algorytmu wagowego osobno na podstawie stref zagrożeń | Ocena ryzyka lokalizacyjnego niezależna od stanu technicznego |
| US-03 | Inżynier Ryzyka | Chcę zobaczyć wynik algorytmu regułowego osobno z listą wyzwolonych reguł | Identyfikacja przypadków specjalnych, które wymagają ręcznej weryfikacji |
| US-04 | Inżynier Ryzyka | Chcę zobaczyć rekomendowaną klasyfikację końcową z uzasadnieniem | Jedna jasna decyzja zamiast interpretowania trzech wyników samodzielnie |
| US-05 | Inżynier Ryzyka | Chcę porównać wszystkie trzy wyniki w jednym widoku | Przejrzysty obraz rozbieżności między perspektywami oceny |
| US-06 | Deweloper / QA | Chcę mieć testy jednostkowe każdego algorytmu obejmujące progi graniczne | Gwarancja deterministyczności i możliwość bezpiecznego refaktorowania |
| US-07 | Deweloper / Architekt | Chcę dokumentację opisującą założenia algorytmów i przykładowe dane | Onboarding nowych osób i podstawa do audytu metodologii |
| US-08 | System (backend) | Endpoint musi walidować dane wejściowe i zwracać `400 Bad Request` dla nieprawidłowych wartości | Bezpieczeństwo API i czytelne komunikaty błędów dla frontendu |

---

## Kryteria Akceptacji

### US-01 — Algorytm punktowy

**Given** użytkownik wypełnił formularz z: wiek budynku, piętro, łączna liczba pięter, poziom zabezpieczeń, liczba szkód w 5 latach
**When** kliknie „Oblicz ryzyko"
**Then** system zwróci:
- `score` jako liczbę całkowitą
- `classification` jako jedną z: `low | medium | high | critical`
- `breakdown` z czterema składowymi: `agePenalty`, `floorFactor`, `securityDiscount`, `claimsPenalty`
- Wynik jest identyczny przy ponownym wysłaniu tych samych danych

**And** progi klasyfikacyjne:
- `score < 30` → `low`
- `30 ≤ score < 60` → `medium`
- `60 ≤ score < 90` → `high`
- `score ≥ 90` → `critical`

### US-02 — Algorytm wagowy

**Given** użytkownik wypełnił formularz z: strefa powodziowa (`A|B|C|none`), strefa pożarowa (`high|medium|low`), strefa kradzieżowa (`high|medium|low`), gęstość zabudowy (`urban|suburban|rural`)
**When** kliknie „Oblicz ryzyko"
**Then** system zwróci:
- `score` jako liczbę zmiennoprzecinkową 0.0–1.0 (2 miejsca po przecinku)
- `classification` jako jedną z: `low | medium | high | critical`
- `breakdown` z czterema wkładami: `flood`, `fire`, `theft`, `density` (wartości po przemnożeniu przez wagę)
- Suma wkładów w `breakdown` równa `score` (tolerancja ±0.01 na zaokrąglenie)

**And** progi klasyfikacyjne:
- `score < 0.25` → `low`
- `0.25 ≤ score < 0.50` → `medium`
- `0.50 ≤ score < 0.75` → `high`
- `score ≥ 0.75` → `critical`

### US-03 — Algorytm regułowy

**Given** użytkownik wypełnił formularz z: czy pustostan (`bool`), czy budynek drewniany (`bool`), czy brak przeglądów (`bool`), suma ubezpieczenia w PLN (`int`)
**When** kliknie „Oblicz ryzyko"
**Then** system zwróci:
- `classification` jako jedną z: `low | medium | high | critical`
- `triggeredRules` jako listę ID wyzwolonych reguł (np. `["MISSING_INSPECTIONS"]`)
- `blockedRules` jako listę ID reguł nieaktywnych
- Gdy żadna reguła nie jest wyzwolona: `classification = low`, `triggeredRules = []`

**And** reguły:

| Reguła | Warunek | Minimalny poziom |
|--------|---------|-----------------|
| `VACANT_PROPERTY` | `isVacant = true` | `high` |
| `WOODEN_STRUCTURE` | `isWoodenStructure = true` | `high` |
| `MISSING_INSPECTIONS` | `missingInspections = true` | `medium` |
| `HIGH_INSURED_SUM` | `insuredSumPLN > 500 000` | `medium` |

### US-04 — Rekomendacja końcowa

**Given** backend obliczył wszystkie trzy algorytmy dla tych samych danych wejściowych
**When** frontend otrzyma odpowiedź z endpointu
**Then** sekcja `recommended` zawiera:
- `classification` = maksimum z trzech wyników (porządek: `low < medium < high < critical`)
- `rationale` — zdanie po polsku wyjaśniające dlaczego ten poziom; wskazuje który algorytm zadecydował
- Gdy wszystkie trzy algorytmy zwrócą tę samą klasę → rationale: `"Wszystkie algorytmy zgodne: {klasa}."`
- Gdy dwa z trzech zgodne → rationale wskazuje te dwa
- Gdy wszystkie różne → rationale: `"Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."`

### US-05 — Widok porównania

**Given** użytkownik wypełnił formularz i kliknął „Oblicz ryzyko"
**When** odpowiedź z API wróci bez błędu
**Then** na stronie widoczne są jednocześnie:
- Trzy karty — po jednej na algorytm — z nazwą, klasą ryzyka (jako badge z kolorem wg design systemu) i skróconym breakdown
- Jedna wyróżniona karta „Rekomendacja" z klasą i rationale
- Klasy ryzyka używają kolorów z design systemu (`low=green`, `medium=yellow`, `high=orange`, `critical=red`)

**When** użytkownik ponownie wypełni formularz innymi wartościami i kliknie „Oblicz"
**Then** widok aktualizuje się bez przeładowania strony

### US-06 — Testy jednostkowe algorytmów

**Given** implementacja algorytmów jest gotowa
**When** uruchomione zostaną testy
**Then**:
- Każdy algorytm ma co najmniej tyle testów ile wartości progowych i reguł (patrz sekcja Test Scenarios)
- Testy przechodzą przy uruchomieniu `npm test` (frontend) i `dotnet test` (backend)
- Każdy test weryfikuje konkretny przykład obliczeniowy z sekcji Research, a nie tylko typ zwracanego obiektu

### US-07 — Dokumentacja

**Given** implementacja jest skończona
**When** programista lub analityk otworzy `sample-app/docs/housing-risk-algorithms.md`
**Then** dokument zawiera:
- Opis celu każdego algorytmu (1–2 zdania)
- Tabelę mapowań składowych z wartościami liczbowymi
- Formuły obliczeniowe
- Co najmniej jeden kompletny przykład obliczeniowy na algorytm
- Opis logiki rekomendacji

### US-08 — Walidacja API

**Given** klient wysyła `POST /api/risk/housing/evaluate` z nieprawidłową wartością enum (np. `floodZone: "X"`)
**When** request dotrze do backendu
**Then**:
- Backend zwróci `400 Bad Request`
- Treść błędu wskazuje które pole jest nieprawidłowe
- Istniejący endpoint `/risk-score` nie jest modyfikowany i nadal działa

**Given** klient wysyła `buildingAge = -5` lub `floor > totalFloors`
**When** request dotrze do backendu
**Then**:
- Backend zwróci `400 Bad Request` z opisem naruszenia

---

## Wymagania Funkcjonalne

| ID | Wymaganie |
|----|-----------|
| FR-01 | Backend udostępnia `POST /api/risk/housing/evaluate` zwracający wyniki wszystkich trzech algorytmów i rekomendację w jednej odpowiedzi JSON |
| FR-02 | Algorytm punktowy (`ALG-1`) oblicza `score` jako sumę czterech składowych wg ustalonych tablic wartości |
| FR-03 | Algorytm wagowy (`ALG-2`) oblicza `score` jako ważoną sumę czterech znormalizowanych wskaźników; wagi: flood=0.30, fire=0.20, theft=0.35, density=0.15 |
| FR-04 | Algorytm regułowy (`ALG-3`) sprawdza cztery reguły binarne i zwraca najwyższy z wymuszonych minimów |
| FR-05 | Logika rekomendacji wybiera `max(ALG-1, ALG-2, ALG-3)` w porządku `low < medium < high < critical` |
| FR-06 | Każdy algorytm zwraca szczegółowy `breakdown` — nie tylko klasę końcową |
| FR-07 | Frontend renderuje wyniki w komponencie `HousingRiskComponent` bez przeładowania strony |
| FR-08 | Frontend używa serwisu `HousingRiskService` do komunikacji z backendem |
| FR-09 | Klasy ryzyka w UI renderowane jako kolorowe badge zgodne z design systemem |
| FR-10 | Backend waliduje wszystkie pola wejściowe i zwraca `400` dla błędnych danych |
| FR-11 | Istniejący endpoint `/risk-score` pozostaje bez zmian |

---

## Wymagania Niefunkcjonalne

| ID | Wymiar | Wymaganie |
|----|--------|-----------|
| NF-01 | Deterministyczność | Te same dane wejściowe zawsze dają ten sam wynik we wszystkich algorytmach |
| NF-02 | Wydajność | Endpoint `/api/risk/housing/evaluate` odpowiada w < 200 ms dla pojedynczego żądania (obliczenia in-memory, brak I/O) |
| NF-03 | Izolacja | Nowy moduł Housing nie modyfikuje istniejących klas, metod ani endpointów |
| NF-04 | Testowalność | Logika algorytmów oddzielona od warstwy HTTP — możliwy test jednostkowy bez uruchamiania serwera |
| NF-05 | Czytelność kodu | Każda tablica mapowań (np. `age_penalty`) zapisana jako konstanta nazwana, nie magic number w formule |
| NF-06 | Zgodność z design systemem | Kolory badge: `low` → hue 145, `medium` → 75, `high` → 38, `critical` → 18; chroma 0.16, lightness 60% |
| NF-07 | Typy TypeScript | Nowe typy `HousingRiskClass`, `HousingEvaluationRequest`, `HousingEvaluationResponse` w osobnym pliku; nie modyfikować istniejącego `RiskClass` |
| NF-08 | Pokrycie testami | Każdy próg klasyfikacyjny i każde mapowanie strefy musi mieć własny test case |

---

## Poza Zakresem

| Element | Uzasadnienie wykluczenia |
|---------|--------------------------|
| Integracja z zewnętrznymi rejestrami (GUS, IMGW, mapy zagrożeń) | Dane wejściowe dostarcza użytkownik ręcznie — integracje są osobnym zakresem |
| Persystencja wyników w bazie danych | Aplikacja przykładowa nie ma warstwy persistence poza istniejącą |
| Klasa ryzyka `regulated` | Ta klasa należy do domeny PDLC, nie mieszkalnictwa |
| Historyczne porównanie wyników | Brak wymagania w issue; można dodać w przyszłości |
| Tryb batch (wiele nieruchomości jednocześnie) | Jeden request = jedna nieruchomość |
| Modyfikacja istniejącego endpointu `/risk-score` | Zmiana zagrożona regresją; nowe algorytmy idą do osobnego endpointu |
| Modyfikacja nawigacji `NAV` w `insurance-x/` | Repozytorium docelowe to `sample-app/`, nie `insurance-x/` |
| Machine Learning / modele probabilistyczne | Algorytmy są deterministyczne z góry ustalonych formuł |
| Konwersja walut | Wszystkie sumy w PLN; brak wymagania wielowalutowości |
| Autoryzacja dostępu do endpointu | Aplikacja przykładowa nie ma auth w warstwie API |

---

## Założenia

| ID | Założenie | Weryfikacja |
|----|-----------|-------------|
| A-01 | Backend `sample-app/dotnet-api/` to .NET 8 minimal API z `Program.cs` jako punktem wejścia | Potwierdzone w `10-research.md` |
| A-02 | Frontend używa `HttpClient` (lub mockowanego serwisu w testach) — brak Angular proxy | Potwierdzone w `10-research.md` |
| A-03 | Testy frontendu używają Vitest, nie Karma/Jasmine | Potwierdzone w `10-research.md` |
| A-04 | Waluta to PLN; próg `HIGH_INSURED_SUM` to dokładnie `> 500 000 PLN` (wartość 500 000 nie wyzwala reguły) | Potwierdzone w `05-autonomy-risk.md` |
| A-05 | Kolejność implementacji: Backend → Frontend → Dokumentacja | Wynika z zależności API |
| A-06 | Wynik ujemny algorytmu punktowego (np. `score = -25`) klasyfikowany jako `low` (warunek `< 30` obejmuje wartości ujemne) | Wynika z definicji progu |

---

## Scenariusze Testowe

### ALG-1 — Algorytm punktowy

| ID testu | Dane wejściowe | Oczekiwany score | Oczekiwana klasa |
|----------|---------------|-----------------|-----------------|
| T1-01 | age=35, floor=3, total=10, security=medium, claims=1 | 20+5−10+20=**35** | `medium` |
| T1-02 | age=55, floor=0, total=5, security=none, claims=3 | 35+10−0+60=**105** | `critical` |
| T1-03 | age=5, floor=12, total=20, security=high, claims=0 | 0+(−5)−20+0=**−25** | `low` |
| T1-04 | score dokładnie 29 | 29 | `low` |
| T1-05 | score dokładnie 30 | 30 | `medium` |
| T1-06 | score dokładnie 59 | 59 | `medium` |
| T1-07 | score dokładnie 60 | 60 | `high` |
| T1-08 | score dokładnie 89 | 89 | `high` |
| T1-09 | score dokładnie 90 | 90 | `critical` |
| T1-10 | age=0, floor=0, total=1, security=basic, claims=0 | 0+10−5+0=**5** | `low` |

### ALG-2 — Algorytm wagowy

| ID testu | floodZone | fireRiskZone | theftRiskZone | buildingDensity | Oczekiwany score | Klasa |
|----------|-----------|-------------|--------------|----------------|-----------------|-------|
| T2-01 | B | low | high | urban | 0.18+0.02+0.35+0.12=**0.67** | `high` |
| T2-02 | none | low | low | rural | 0+0.02+0.035+0.015=**0.07** | `low` |
| T2-03 | A | high | high | urban | 0.30+0.20+0.35+0.12=**0.97** | `critical` |
| T2-04 | C | medium | medium | suburban | 0.09+0.10+0.175+0.06=**0.425** | `medium` |
| T2-05 | Próg 0.25 dokładnie | — | — | — | 0.25 | `medium` |
| T2-06 | Próg 0.50 dokładnie | — | — | — | 0.50 | `high` |
| T2-07 | Próg 0.75 dokładnie | — | — | — | 0.75 | `critical` |

### ALG-3 — Algorytm regułowy

| ID testu | isVacant | isWoodenStructure | missingInspections | insuredSumPLN | triggeredRules | Klasa |
|----------|----------|-------------------|-------------------|--------------|---------------|-------|
| T3-01 | false | false | false | 300000 | [] | `low` |
| T3-02 | false | false | true | 300000 | [MISSING_INSPECTIONS] | `medium` |
| T3-03 | false | false | false | 500001 | [HIGH_INSURED_SUM] | `medium` |
| T3-04 | false | false | false | 500000 | [] | `low` (próg > 500000) |
| T3-05 | true | false | false | 0 | [VACANT_PROPERTY] | `high` |
| T3-06 | false | true | false | 0 | [WOODEN_STRUCTURE] | `high` |
| T3-07 | true | true | true | 600000 | [VACANT, WOODEN, MISSING, HIGH_SUM] | `high` |
| T3-08 | false | false | true | 500001 | [MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `medium` |

### Rekomendacja końcowa

| ID testu | ALG-1 | ALG-2 | ALG-3 | Oczekiwana rekomendacja | Typ rationale |
|----------|-------|-------|-------|------------------------|---------------|
| TR-01 | medium | high | medium | `high` | Dwa algorytmy wskazują medium, jeden wskazuje high |
| TR-02 | low | low | low | `low` | Wszystkie zgodne |
| TR-03 | low | medium | high | `high` | Rozbieżność algorytmów |
| TR-04 | critical | low | low | `critical` | Jeden algorytm krytyczny = zawsze critical |
| TR-05 | medium | medium | medium | `medium` | Wszystkie zgodne |

### Walidacja API

| ID testu | Dane wejściowe | Oczekiwany status HTTP |
|----------|---------------|----------------------|
| TV-01 | `floodZone: "X"` (nieznana wartość) | `400 Bad Request` |
| TV-02 | `buildingAge: -1` | `400 Bad Request` |
| TV-03 | `floor: 5`, `totalFloors: 3` (floor > total) | `400 Bad Request` |
| TV-04 | `claimsLast5Years: -1` | `400 Bad Request` |
| TV-05 | Kompletne, poprawne dane | `200 OK` + JSON ze wszystkimi trzema algorytmami |
| TV-06 | `GET /risk-score` (istniejący endpoint) | `200 OK` — brak regresji |

---

## Kształt API — Kontrakt

### Request

```
POST /api/risk/housing/evaluate
Content-Type: application/json
```

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

Dozwolone wartości enum:
- `securityLevel`: `none | basic | medium | high`
- `floodZone`: `A | B | C | none`
- `fireRiskZone`: `high | medium | low`
- `theftRiskZone`: `high | medium | low`
- `buildingDensity`: `urban | suburban | rural`

Walidacja liczbowa: `buildingAge ≥ 0`, `floor ≥ 0`, `floor ≤ totalFloors`, `claimsLast5Years ≥ 0`, `insuredSumPLN ≥ 0`.

### Response `200 OK`

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

### Response `400 Bad Request`

```json
{
  "error": "Validation failed",
  "fields": {
    "floor": "floor (5) cannot exceed totalFloors (3)"
  }
}
```

---

## Następne polecenie

```text
/pdlc architecture
```