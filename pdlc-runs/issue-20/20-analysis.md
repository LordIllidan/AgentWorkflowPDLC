# PDLC Analyst Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25287266063
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
| Frontend Angular 20 | `sample-app/angular-frontend/src/app/housing/` | Nowy standalone component `HousingRiskComponent` + serwis `HousingRiskService` |
| Typy TypeScript | `sample-app/angular-frontend/src/app/housing/housing-risk.types.ts` | Nowe typy `HousingRiskClass`, `HousingEvaluationRequest`, `HousingEvaluationResponse` |
| Testy backend | `sample-app/dotnet-api-tests/` | xUnit — testy jednostkowe każdego algorytmu (nowy projekt) |
| Testy frontend | `sample-app/angular-frontend/src/app/housing/` | Vitest — testy serwisu i komponentu |
| Dokumentacja | `sample-app/docs/housing-risk-algorithms.md` | Opis założeń, formuł i przykładowych danych wejściowych |

### Trzy algorytmy

| ID | Klasa C# | Metodologia | Dane wejściowe |
|----|----------|-------------|----------------|
| ALG-1 | `PropertyScoreAlgorithm` | Punktowy — cechy fizyczne nieruchomości | Wiek budynku, piętro, zabezpieczenia, historia szkód |
| ALG-2 | `LocationWeightAlgorithm` | Wagowy — lokalizacja i ekspozycja | Strefy: powódź, pożar, kradzież, gęstość zabudowy |
| ALG-3 | `SpecialCaseRuleAlgorithm` | Regułowy — przypadki specjalne | Pustostan, drewno, brak przeglądów, suma ubezpieczenia |

### Ustalenia technologiczne z repozytorium (na 2026-05-03)

| Element | Stan | Implikacja |
|---------|------|------------|
| Backend pattern | `Results.Json()` — nie `Results.Ok()` | Nowy endpoint używa `Results.Json()` dla spójności |
| `@angular/forms` | **Nieobecny** w `package.json` | Formularz oparty wyłącznie na sygnałach + event binding `(input)` / `(change)` |
| `provideHttpClient()` | **Nieobecny** w `main.ts` | Wymaga dodania do `bootstrapApplication` |
| JSON enum w .NET | Brak `JsonStringEnumConverter` | Dodać konwerter lub używać stringów bezpośrednio w response — domyślnie .NET serializuje enum jako liczby |
| Brak proxy Angular | Frontend wywołuje backend bezpośrednio przez URL | `HousingRiskService` używa pełnego URL `http://localhost:8080/api/...` |
| Istniejący endpoint | `POST /risk-score` — brak zmian | Nowy endpoint całkowicie addytywny |
| Namespace .NET | `SampleRiskApi` | Nowe klasy: `namespace SampleRiskApi.Housing;` |
| Testy frontend | Vitest 3.1 + jsdom + Angular TestBed | Nie Karma/Jasmine; `test-setup.ts` już skonfigurowany |

---

## Historie Użytkownika

| ID | Rola | Potrzeba | Wartość biznesowa |
|----|------|----------|-------------------|
| US-01 | Inżynier Ryzyka | Chcę wprowadzić dane nieruchomości i zobaczyć wynik algorytmu punktowego osobno | Ocena cech fizycznych budynku bez szumu danych lokalizacyjnych |
| US-02 | Inżynier Ryzyka | Chcę zobaczyć wynik algorytmu wagowego osobno na podstawie stref zagrożeń | Ocena ryzyka lokalizacyjnego niezależna od stanu technicznego budynku |
| US-03 | Inżynier Ryzyka | Chcę zobaczyć wynik algorytmu regułowego osobno z listą wyzwolonych reguł | Identyfikacja przypadków specjalnych wymagających ręcznej weryfikacji |
| US-04 | Inżynier Ryzyka | Chcę zobaczyć rekomendowaną klasyfikację końcową z uzasadnieniem w języku polskim | Jedna jasna decyzja zamiast samodzielnego interpretowania trzech wyników |
| US-05 | Inżynier Ryzyka | Chcę porównać wszystkie trzy wyniki w jednym widoku jednocześnie | Przejrzysty obraz rozbieżności między perspektywami oceny |
| US-06 | Deweloper / QA | Chcę mieć testy jednostkowe każdego algorytmu obejmujące wartości progowe i przypadki graniczne | Gwarancja deterministyczności i możliwość bezpiecznego refaktorowania w przyszłości |
| US-07 | Deweloper / Architekt | Chcę dokumentację opisującą założenia algorytmów, formuły i przykładowe dane wejściowe | Onboarding nowych osób i podstawa do audytu metodologii ubezpieczeniowej |
| US-08 | System (backend) | Endpoint musi walidować dane wejściowe i zwracać `400 Bad Request` dla nieprawidłowych wartości | Bezpieczeństwo API i czytelne komunikaty błędów dla frontendu |

---

## Kryteria Akceptacji

### US-01 — Algorytm punktowy (ALG-1)

**Given** użytkownik wypełnił formularz z: wiek budynku (`buildingAge`), piętro (`floor`), łączna liczba pięter (`totalFloors`), poziom zabezpieczeń (`securityLevel`), liczba szkód w ostatnich 5 latach (`claimsLast5Years`)

**When** kliknie „Oblicz ryzyko"

**Then** system zwróci:
- `score` jako liczbę całkowitą (może być ujemna — klasyfikowana jako `low`)
- `classification` jako jedną z: `low | medium | high | critical`
- `breakdown` z czterema składowymi: `agePenalty`, `floorFactor`, `securityDiscount`, `claimsPenalty`
- Wynik jest identyczny przy ponownym wysłaniu tych samych danych

**And** progi klasyfikacyjne są ściśle określone:

| Warunek | Klasa |
|---------|-------|
| `score < 30` (w tym ujemne) | `low` |
| `30 ≤ score < 60` | `medium` |
| `60 ≤ score < 90` | `high` |
| `score ≥ 90` | `critical` |

**And** tablice składowych:

| Składowa | Warunek | Wartość |
|----------|---------|---------|
| `agePenalty` | wiek < 10 lat | 0 |
| | 10–30 lat | +10 |
| | 31–50 lat | +20 |
| | > 50 lat | +35 |
| `floorFactor` | floor ≤ 1 | +10 |
| | floor 2–4 | +5 |
| | floor 5–9 | 0 |
| | floor ≥ 10 | −5 |
| `securityDiscount` | `none` | 0 |
| | `basic` | −5 |
| | `medium` | −10 |
| | `high` | −20 |
| `claimsPenalty` | 0 szkód | 0 |
| | 1 szkoda | +20 |
| | 2 szkody | +40 |
| | ≥ 3 szkody | +60 |

---

### US-02 — Algorytm wagowy (ALG-2)

**Given** użytkownik wypełnił formularz z: strefa powodziowa (`A|B|C|none`), strefa pożarowa (`high|medium|low`), strefa kradzieżowa (`high|medium|low`), gęstość zabudowy (`urban|suburban|rural`)

**When** kliknie „Oblicz ryzyko"

**Then** system zwróci:
- `score` jako liczbę zmiennoprzecinkową 0.0–1.0, zaokrągloną do 2 miejsc po przecinku
- `classification` jako jedną z: `low | medium | high | critical`
- `breakdown` z czterema wkładami: `flood`, `fire`, `theft`, `density` (każdy = wartość strefy × waga)
- Suma wkładów w `breakdown` równa `score` (tolerancja ±0.01 na zaokrąglenie zmiennoprzecinkowe)

**And** formuła i wagi:

```
score = 0.30 × flood_score(floodZone)
      + 0.20 × fire_score(fireRiskZone)
      + 0.35 × theft_score(theftRiskZone)
      + 0.15 × density_score(buildingDensity)
```

| Parametr | Wartość | Score |
|----------|---------|-------|
| `floodZone` A | strefa bezpośredniego zagrożenia | 1.0 |
| `floodZone` B | strefa pośrednia | 0.6 |
| `floodZone` C | strefa potencjalna | 0.3 |
| `floodZone` none | brak strefy | 0.0 |
| `fireRiskZone` / `theftRiskZone` high | — | 1.0 |
| `fireRiskZone` / `theftRiskZone` medium | — | 0.5 |
| `fireRiskZone` / `theftRiskZone` low | — | 0.1 |
| `buildingDensity` urban | — | 0.8 |
| `buildingDensity` suburban | — | 0.4 |
| `buildingDensity` rural | — | 0.1 |

**And** progi klasyfikacyjne:

| Warunek | Klasa |
|---------|-------|
| `score < 0.25` | `low` |
| `0.25 ≤ score < 0.50` | `medium` |
| `0.50 ≤ score < 0.75` | `high` |
| `score ≥ 0.75` | `critical` |

---

### US-03 — Algorytm regułowy (ALG-3)

**Given** użytkownik wypełnił formularz z: czy pustostan (`isVacant: bool`), czy budynek drewniany (`isWoodenStructure: bool`), czy brak przeglądów (`missingInspections: bool`), suma ubezpieczenia w PLN (`insuredSumPLN: int`)

**When** kliknie „Oblicz ryzyko"

**Then** system zwróci:
- `classification` jako jedną z: `low | medium | high | critical`
- `triggeredRules` jako listę ID wyzwolonych reguł (np. `["MISSING_INSPECTIONS"]`)
- `blockedRules` jako listę pozostałych reguł nieaktywnych
- Gdy żadna reguła nie jest wyzwolona: `classification = low`, `triggeredRules = []`

**And** definicje reguł binarnych:

| ID reguły | Warunek wyzwolenia | Minimalny poziom |
|-----------|-------------------|-----------------|
| `VACANT_PROPERTY` | `isVacant = true` | `high` |
| `WOODEN_STRUCTURE` | `isWoodenStructure = true` | `high` |
| `MISSING_INSPECTIONS` | `missingInspections = true` | `medium` |
| `HIGH_INSURED_SUM` | `insuredSumPLN > 500 000` (**ścisłe `>`**) | `medium` |

**And** wynik końcowy = maksimum z wymuszonych minimów; porządek: `low < medium < high < critical`

**And** wartość dokładnie `insuredSumPLN = 500 000` **nie wyzwala** reguły `HIGH_INSURED_SUM`

---

### US-04 — Rekomendacja końcowa

**Given** backend obliczył wszystkie trzy algorytmy dla tych samych danych wejściowych

**When** frontend otrzyma odpowiedź z endpointu

**Then** sekcja `recommended` zawiera:
- `classification` = `max(ALG-1, ALG-2, ALG-3)` w porządku `low < medium < high < critical`
- `rationale` — zdanie po polsku wyjaśniające, który algorytm zadecydował

**And** logika rationale:

| Sytuacja | Tekst rationale |
|----------|----------------|
| Którykolwiek zwraca `critical` | `"Algorytm {punktowy/wagowy/regułowy} wskazuje ryzyko krytyczne."` |
| Wszystkie trzy równe (nie `critical`) | `"Wszystkie algorytmy zgodne: {klasa}."` |
| Dwa lub więcej wskazuje max | `"Dwa lub więcej algorytmów wskazuje: {klasa}."` |
| Wszystkie różne | `"Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."` |

---

### US-05 — Widok porównania

**Given** użytkownik wypełnił formularz i kliknął „Oblicz ryzyko"

**When** odpowiedź z API wróci bez błędu (`200 OK`)

**Then** na stronie widoczne są jednocześnie:
- Trzy karty — po jednej na algorytm — z nazwą, klasą ryzyka jako kolorowy badge i skróconym breakdown
- Jedna wyróżniona karta „Rekomendacja" z klasą i rationale
- Kolory badge zgodne z design systemem OKLCH (chroma 0.16, lightness 60%, para tło+border):

| Klasa | Hue | Tło | Border |
|-------|-----|-----|--------|
| `low` | 145 | `oklch(95% 0.16 145)` | `oklch(80% 0.16 145)` |
| `medium` | 75 | `oklch(95% 0.16 75)` | `oklch(80% 0.16 75)` |
| `high` | 38 | `oklch(95% 0.16 38)` | `oklch(80% 0.16 38)` |
| `critical` | 18 | `oklch(95% 0.16 18)` | `oklch(80% 0.16 18)` |

**When** użytkownik ponownie wypełni formularz innymi wartościami i kliknie „Oblicz"

**Then** widok aktualizuje się bez przeładowania strony (Angular Signals)

---

### US-06 — Testy jednostkowe algorytmów

**Given** implementacja algorytmów jest gotowa

**When** uruchomione zostaną testy

**Then**:
- Backend: `dotnet test sample-app/dotnet-api-tests/` — co najmniej 32 przypadki testowe, wszystkie zielone
- Frontend: `npm test` w `sample-app/angular-frontend/` — co najmniej 6 przypadków Vitest, wszystkie zielone
- Każdy próg klasyfikacyjny i każda reguła binarna mają własny test z wartością graniczną
- Testy weryfikują konkretne wartości liczbowe, nie tylko typ zwracanego obiektu

---

### US-07 — Dokumentacja

**Given** implementacja jest skończona

**When** programista lub analityk otworzy `sample-app/docs/housing-risk-algorithms.md`

**Then** dokument zawiera:
- Opis celu każdego algorytmu (1–2 zdania)
- Tabelę mapowań składowych z wartościami liczbowymi
- Formuły obliczeniowe w czytelnej notacji
- Co najmniej jeden kompletny przykład obliczeniowy na algorytm
- Opis logiki rekomendacji z przypadkami rationale
- Kompletny przykład request/response JSON

---

### US-08 — Walidacja API

**Given** klient wysyła `POST /api/risk/housing/evaluate` z nieprawidłową wartością enum (np. `floodZone: "X"`)

**When** request dotrze do backendu

**Then**:
- Backend zwróci `400 Bad Request`
- Treść błędu zawiera pole `fields` wskazujące, które pole jest nieprawidłowe
- Istniejący endpoint `POST /risk-score` nie jest modyfikowany i nadal zwraca `200 OK`

**Given** klient wysyła `buildingAge = -1` lub `floor > totalFloors`

**When** request dotrze do backendu

**Then** backend zwróci `400 Bad Request` z opisem naruszenia w polu `fields`

---

## Wymagania Funkcjonalne

| ID | Wymaganie |
|----|-----------|
| FR-01 | Backend udostępnia `POST /api/risk/housing/evaluate` zwracający wyniki wszystkich trzech algorytmów i rekomendację w jednej odpowiedzi JSON (`200 OK`) |
| FR-02 | ALG-1 oblicza `score` jako sumę algebraiczną: `agePenalty + floorFactor − securityDiscount + claimsPenalty` wg ustalonych tablic wartości |
| FR-03 | ALG-2 oblicza `score` jako ważoną sumę czterech znormalizowanych wskaźników; wagi: `flood=0.30, fire=0.20, theft=0.35, density=0.15`; suma wag = 1.00 |
| FR-04 | ALG-3 sprawdza cztery reguły binarne i zwraca `max()` z wymuszonych minimów; wynik = `low` gdy żadna reguła nieaktywna |
| FR-05 | Logika rekomendacji wybiera `max(ALG-1, ALG-2, ALG-3)` w porządku `low < medium < high < critical` |
| FR-06 | Każdy algorytm zwraca szczegółowy `breakdown` — nie tylko klasę końcową |
| FR-07 | Frontend renderuje wyniki w komponencie `HousingRiskComponent` bez przeładowania strony (Angular Signals) |
| FR-08 | Frontend używa serwisu `HousingRiskService` z `HttpClient` do komunikacji z backendem |
| FR-09 | Klasy ryzyka w UI renderowane jako kolorowe badge zgodne z design systemem (OKLCH para tło+border) |
| FR-10 | Backend waliduje wszystkie pola wejściowe i zwraca `400` z polem `fields` dla błędnych danych |
| FR-11 | Istniejący endpoint `POST /risk-score` pozostaje bez żadnych zmian |
| FR-12 | Response JSON używa stringów dla klas ryzyka (`"low"`, `"medium"`, `"high"`, `"critical"`) — nie liczb całkowitych z C# enum |

---

## Wymagania Niefunkcjonalne

| ID | Wymiar | Wymaganie |
|----|--------|-----------|
| NF-01 | Deterministyczność | Te same dane wejściowe zawsze dają ten sam wynik we wszystkich trzech algorytmach — brak losowości, brak I/O zewnętrznego |
| NF-02 | Wydajność | Endpoint `/api/risk/housing/evaluate` odpowiada w < 200 ms dla pojedynczego żądania (obliczenia in-memory) |
| NF-03 | Izolacja | Moduł Housing nie modyfikuje istniejących klas, metod ani endpointów; rollback = revert pliku lub zamknięcie PR |
| NF-04 | Testowalność | Logika algorytmów oddzielona od warstwy HTTP — klasy statyczne i bezstanowe, testowalne bez uruchamiania serwera |
| NF-05 | Czytelność | Każda tablica mapowań zapisana jako stała z nazwą, nie magic number w formule |
| NF-06 | Zgodność z design systemem | Badge: chroma 0.16, lightness tekstu 60%, lightness tła 95%, lightness border 80%; zawsze para tło+border |
| NF-07 | Typy TypeScript | `HousingRiskClass = 'low' \| 'medium' \| 'high' \| 'critical'` w osobnym pliku; nie modyfikować istniejącego `RiskClass` |
| NF-08 | Pokrycie testami | Każdy próg klasyfikacyjny ALG-1, każde mapowanie strefy ALG-2, każda wartość graniczna ALG-3 (`insuredSumPLN = 500 000` vs `500 001`) mają własny test case |
| NF-09 | Spójność kodu | Backend używa `Results.Json()` (nie `Results.Ok()`) — spójność z istniejącym `/risk-score` |

---

## Poza Zakresem

| Element | Uzasadnienie wykluczenia |
|---------|--------------------------|
| Integracja z zewnętrznymi rejestrami (GUS, IMGW-PIB, ISOK, KGP) | Dane wejściowe dostarcza użytkownik ręcznie — integracje są osobnym zakresem |
| Persystencja wyników w bazie danych | Aplikacja przykładowa nie ma warstwy persistence poza istniejącą |
| Klasa ryzyka `regulated` | Należy do domeny PDLC, nie mieszkalnictwa; `HousingRiskClass` jej nie zawiera |
| Historyczne porównanie wyników | Brak wymagania w issue |
| Tryb batch (wiele nieruchomości jednocześnie) | Jeden request = jedna nieruchomość |
| Modyfikacja istniejącego endpointu `POST /risk-score` | Nowe algorytmy są addytywne; zmiana istniejącego endpointu niesie ryzyko regresji |
| Machine Learning / modele probabilistyczne | Algorytmy są deterministyczne na podstawie z góry ustalonych formuł |
| Konwersja walut | Wszystkie sumy w PLN; brak wymagania wielowalutowości |
| Autoryzacja dostępu do endpointu | Aplikacja przykładowa nie ma warstwy auth — identycznie jak istniejący `/risk-score` |
| Modyfikacja nawigacji `NAV` w `insurance-x/` | Docelowe repozytorium to `sample-app/`, nie `insurance-x/` |

---

## Założenia

| ID | Założenie | Weryfikacja |
|----|-----------|-------------|
| A-01 | Backend `sample-app/dotnet-api/` to .NET 8 minimal API z `Program.cs` jako punktem wejścia | Potwierdzone w `10-research.md` — `SampleRiskApi.csproj` istnieje |
| A-02 | Frontend nie ma `@angular/forms` — formularze przez sygnały + event binding | Potwierdzone w `10-research.md` — brak w `package.json` |
| A-03 | Testy frontendu używają Vitest 3.1 + Angular TestBed, nie Karma | Potwierdzone w `10-research.md` — `test-setup.ts` skonfigurowany |
| A-04 | Waluta PLN; próg `HIGH_INSURED_SUM` to dokładnie `> 500 000` (wartość 500 000 nie wyzwala) | Potwierdzone w `05-autonomy-risk.md` |
| A-05 | Wynik ujemny ALG-1 klasyfikowany jako `low` — warunek `score < 30` obejmuje wartości ujemne | Wynika z definicji progu |
| A-06 | Backend serializuje klasy ryzyka jako stringi (`"low"`) — wymaga `JsonStringEnumConverter` lub stringów bezpośrednich | Zidentyfikowane w `10-research.md`; wybór: stringi bezpośrednie jak w `/risk-score` |
| A-07 | `HousingRiskService` wywołuje backend przez pełny URL (brak proxy Angular) | Potwierdzone w `10-research.md` |
| A-08 | Kolejność implementacji: backend → testy backendu → typy frontendu → serwis → komponent → integracja → dokumentacja | Wynika z zależności API |

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

Dozwolone wartości:

| Pole | Wartości |
|------|----------|
| `securityLevel` | `none`, `basic`, `medium`, `high` |
| `floodZone` | `A`, `B`, `C`, `none` |
| `fireRiskZone` | `high`, `medium`, `low` |
| `theftRiskZone` | `high`, `medium`, `low` |
| `buildingDensity` | `urban`, `suburban`, `rural` |

Walidacja liczbowa: `buildingAge ≥ 0`, `floor ≥ 0`, `totalFloors ≥ 1`, `floor ≤ totalFloors`, `claimsLast5Years ≥ 0`, `insuredSumPLN ≥ 0`.

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
    "rationale": "Rozbieżność algorytmów. Przyjęto najwyższy wynik: high."
  }
}
```

### Response `400 Bad Request`

```json
{
  "error": "Validation failed",
  "fields": {
    "floodZone": "Unknown value 'X'. Allowed: A, B, C, none.",
    "floor": "floor (5) cannot exceed totalFloors (3)"
  }
}
```

---

## Scenariusze Testowe

### ALG-1 — Algorytm punktowy

| ID | age | floor | total | security | claims | Score | Klasa |
|----|-----|-------|-------|----------|--------|-------|-------|
| T1-01 | 35 | 3 | 10 | medium | 1 | 20+5−10+20=**35** | `medium` |
| T1-02 | 55 | 0 | 5 | none | 3 | 35+10−0+60=**105** | `critical` |
| T1-03 | 5 | 12 | 20 | high | 0 | 0+(−5)−20+0=**−25** | `low` |
| T1-04 | (score=29) | — | — | — | — | 29 | `low` |
| T1-05 | (score=30) | — | — | — | — | 30 | `medium` (próg) |
| T1-06 | (score=59) | — | — | — | — | 59 | `medium` |
| T1-07 | (score=60) | — | — | — | — | 60 | `high` (próg) |
| T1-08 | (score=89) | — | — | — | — | 89 | `high` |
| T1-09 | (score=90) | — | — | — | — | 90 | `critical` (próg) |
| T1-10 | 0 | 0 | 1 | basic | 0 | 0+10−5+0=**5** | `low` |

### ALG-2 — Algorytm wagowy

| ID | floodZone | fireRiskZone | theftRiskZone | buildingDensity | Score | Klasa |
|----|-----------|-------------|--------------|----------------|-------|-------|
| T2-01 | B | low | high | urban | 0.18+0.02+0.35+0.12=**0.67** | `high` |
| T2-02 | none | low | low | rural | 0+0.02+0.035+0.015=**0.07** | `low` |
| T2-03 | A | high | high | urban | 0.30+0.20+0.35+0.12=**0.97** | `critical` |
| T2-04 | C | medium | medium | suburban | 0.09+0.10+0.175+0.06=**0.425** | `medium` |
| T2-05 | B | low | low | rural | 0.18+0.02+0.035+0.015=**0.25** | `medium` (próg) |
| T2-06 | B | low | high | rural | 0.18+0.02+0.35+0.015=**0.565** → zaokr. do 0.57 | `high` (przykład ≥ 0.50) |
| T2-07 | A | high | high | rural | 0.30+0.20+0.35+0.015=**0.865** → zaokr. do 0.87 | `critical` (przykład ≥ 0.75) |

### ALG-3 — Algorytm regułowy

| ID | isVacant | isWoodenStructure | missingInspections | insuredSumPLN | triggeredRules | Klasa |
|----|----------|-------------------|-------------------|--------------|---------------|-------|
| T3-01 | false | false | false | 300 000 | [] | `low` |
| T3-02 | false | false | true | 300 000 | [MISSING_INSPECTIONS] | `medium` |
| T3-03 | false | false | false | 500 001 | [HIGH_INSURED_SUM] | `medium` |
| T3-04 | false | false | false | **500 000** | [] | `low` (warunek ścisły `>`) |
| T3-05 | true | false | false | 0 | [VACANT_PROPERTY] | `high` |
| T3-06 | false | true | false | 0 | [WOODEN_STRUCTURE] | `high` |
| T3-07 | true | true | true | 600 000 | [VACANT_PROPERTY, WOODEN_STRUCTURE, MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `high` |
| T3-08 | false | false | true | 500 001 | [MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `medium` |

### Rekomendacja końcowa

| ID | ALG-1 | ALG-2 | ALG-3 | Rekomendacja | Typ rationale |
|----|-------|-------|-------|-------------|---------------|
| TR-01 | medium | high | medium | `high` | Rozbieżność / jeden wyższy |
| TR-02 | low | low | low | `low` | Wszystkie zgodne |
| TR-03 | low | medium | high | `high` | Rozbieżność — przyjęto najwyższy |
| TR-04 | critical | low | low | `critical` | Jeden algorytm krytyczny |
| TR-05 | medium | medium | medium | `medium` | Wszystkie zgodne |

### Walidacja API

| ID | Dane wejściowe | Oczekiwany status HTTP |
|----|---------------|----------------------|
| TV-01 | `floodZone: "X"` (nieznana wartość) | `400 Bad Request` |
| TV-02 | `buildingAge: -1` | `400 Bad Request` |
| TV-03 | `floor: 5`, `totalFloors: 3` | `400 Bad Request` |
| TV-04 | `claimsLast5Years: -1` | `400 Bad Request` |
| TV-05 | `insuredSumPLN: -100` | `400 Bad Request` |
| TV-06 | Kompletne, poprawne dane (przykład z sekcji Request) | `200 OK` + JSON z trzema algorytmami |
| TV-07 | `POST /risk-score` (istniejący endpoint) | `200 OK` — brak regresji |

---

```text
/pdlc architecture
```