# PDLC Research Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25287176166
Agent: research-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Status: READY

# PDLC Research — Issue #20: Trzy algorytmy analizy ryzyk w mieszkalnictwie

**Data:** 2026-05-03
**Agent:** research-agent
**Issue:** [#20](https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20)

---

## Podsumowanie Wykonawcze

Issue #20 wymaga dodania trzech niezależnych algorytmów oceny ryzyka mieszkalnictwa do aplikacji przykładowej `sample-app`. Algorytmy różnią się metodologią: scoring cech fizycznych nieruchomości (ALG-1), ważona suma ekspozycji lokalizacyjnej (ALG-2), klasyfikacja binarna przypadków specjalnych (ALG-3). Wszystkie algorytmy są deterministyczne, formuły zamknięte, brak integracji zewnętrznej.

**Weryfikacja stanu repozytorium (na dzień 2026-05-03):**

| Element | Stan potwierdzony |
|---------|------------------|
| Backend | `sample-app/dotnet-api/` — .NET 8 minimal API, `Program.cs` z `Results.Json()`, projekt `SampleRiskApi.csproj` |
| Frontend | Angular 20 standalone, `bootstrapApplication`, Signals (`signal`, `computed`), inline template/styles |
| Testy frontend | Vitest 3.1, jsdom, Angular TestBed przez `@angular/platform-browser-dynamic/testing` |
| `@angular/forms` | **Nieobecny** w `package.json` — formularze muszą używać event binding z sygnałami (jak w istniejącym `AppComponent`) |
| `provideHttpClient()` | **Nieobecny** w `main.ts` — wymaga dodania |
| `Results.Json()` | Backend używa `Results.Json()` — nie `Results.Ok()`. Nowy endpoint powinien zachować spójność z istniejącym kodem |
| Istniejący RiskClass | `'low' \| 'medium' \| 'high' \| 'regulated' \| 'critical'` — klasa `regulated` należy do domeny PDLC |
| Brak proxy Angular | Frontend wywołuje backend bezpośrednio przez URL; brak `proxy.conf.json` |

**Kluczowa korekta do `50-plan.md`:** Krok 6 używał `Results.Ok()` — powinno być `Results.Json()` lub `Results.Ok()` (oba poprawne w .NET minimal API; dla spójności z istniejącym kodem: `Results.Json()`).

**Zakres implementacji gotowy do realizacji.** Wszystkie etapy PDLC (`05`, `10`, `20`, `40`, `50`) są kompletne.

---

## Założenia Domenowe

### Kontekst ubezpieczeniowy

Ocena ryzyka mieszkalnictwa w polskich ubezpieczeniach majątkowych opiera się na trzech niezależnych filarach:

1. **Cechy fizyczne nieruchomości** — wiek budynku, piętro, zabezpieczenia, historia szkód. Dostępne przy zawarciu umowy, mierzalne przez rzeczoznawcę lub deklarację klienta.
2. **Ekspozycja lokalizacyjna** — strefy zagrożeń (powódź ISOK, pożar, kradzież wg KGP). Zależne od zewnętrznych rejestrów; w tej implementacji podawane ręcznie przez użytkownika.
3. **Przypadki specjalne** — warunki nieciągłe, nieobjęte formułami ciągłymi (pustostan, drewno, brak przeglądów). Wymagają klasyfikacji zero/jeden.

### Ograniczenia tej implementacji

- Dane wejściowe dostarcza użytkownik ręcznie — brak integracji z GUS, IMGW-PIB, ISOK, KGP.
- Waluta wyłącznie PLN; próg wysokiej sumy ubezpieczenia: `insuredSumPLN > 500 000` (warunek ścisły — 500 000 nie wyzwala reguły).
- Klasy ryzyka mieszkalnictwa: `low | medium | high | critical`. Klasa `regulated` nie jest stosowana — należy do domeny PDLC.
- Wyniki deterministyczne: te same dane wejściowe → ten sam wynik, zawsze.
- Rekomendacja końcowa: `max()` z trzech wyników (zasada ostrożności), nie ML ani głosowanie.
- Brak uwierzytelniania endpointu (aplikacja przykładowa — brak warstwy auth).

---

## Algorytm 1: Punktowy — `PropertyScoreAlgorithm`

### Metodologia

Sumowanie punktów za cechy fizyczne nieruchomości. Wynik całkowity (może być ujemny); mapowany na klasę ryzyka przez cztery progi.

### Dane wejściowe

| Pole | Typ | Dozwolone wartości |
|------|-----|-------------------|
| `buildingAge` | `int` | ≥ 0 |
| `floor` | `int` | ≥ 0; ≤ `totalFloors` |
| `totalFloors` | `int` | ≥ 1 |
| `securityLevel` | `string` | `none \| basic \| medium \| high` |
| `claimsLast5Years` | `int` | ≥ 0 |

### Formuła

```
score = age_penalty(buildingAge)
      + floor_factor(floor, totalFloors)
      − security_discount(securityLevel)
      + claims_penalty(claimsLast5Years)
```

### Tablice składowych

| Składowa | Warunek | Punkty |
|----------|---------|--------|
| `age_penalty` | wiek < 10 lat | 0 |
| | 10–30 lat | 10 |
| | 31–50 lat | 20 |
| | > 50 lat | 35 |
| `floor_factor` | floor ≤ 1 (parter/1 piętro) | +10 |
| | floor 2–4 | +5 |
| | floor 5–9 | 0 |
| | floor ≥ 10 | −5 |
| `security_discount` | `none` | 0 |
| | `basic` | −5 (odejmowane od kary) |
| | `medium` | −10 |
| | `high` | −20 |
| `claims_penalty` | 0 szkód | 0 |
| | 1 szkoda | +20 |
| | 2 szkody | +40 |
| | ≥ 3 szkody | +60 |

### Mapowanie na klasę ryzyka

| Score | Klasa |
|-------|-------|
| < 30 (w tym ujemne) | `low` |
| 30–59 | `medium` |
| 60–89 | `high` |
| ≥ 90 | `critical` |

### Dane wyjściowe

`score` (int), `classification` (HousingRiskClass), `breakdown` (cztery składowe osobno).

### Przykład obliczeniowy

Dane: wiek=35, piętro=3, łącznie=10 pięter, zabezpieczenia=medium, szkody=1.

```
age_penalty(35)           = 20
floor_factor(3, 10)       = 5
security_discount(medium) = 10
claims_penalty(1)         = 20

score = 20 + 5 - 10 + 20 = 35  →  medium
```

---

## Algorytm 2: Wagowy — `LocationWeightAlgorithm`

### Metodologia

Ważona suma znormalizowanych wskaźników stref zagrożeń. Wynik w przedziale 0.0–1.0 (zmiennoprzecinkowy, zaokrąglany do 2 miejsc).

### Dane wejściowe

| Pole | Typ | Dozwolone wartości |
|------|-----|-------------------|
| `floodZone` | `string` | `A \| B \| C \| none` |
| `fireRiskZone` | `string` | `high \| medium \| low` |
| `theftRiskZone` | `string` | `high \| medium \| low` |
| `buildingDensity` | `string` | `urban \| suburban \| rural` |

### Formuła i wagi

```
score = 0.30 × flood_score(floodZone)
      + 0.20 × fire_score(fireRiskZone)
      + 0.35 × theft_score(theftRiskZone)
      + 0.15 × density_score(buildingDensity)
```

| Wymiar | Waga | Uzasadnienie |
|--------|------|-------------|
| Powódź | 0.30 | Najwyższe szkody jednostkowe w Polsce (Swiss Re natcat); mitygacja poza kontrolą właściciela |
| Pożar | 0.20 | Wysokie szkody; częściowo pokryte przez zabezpieczenia (ALG-1) |
| Kradzież | 0.35 | Najwyższa częstotliwość szkód w PL wg KGP; dominuje w portfelach mieszkaniowych |
| Gęstość zabudowy | 0.15 | Korelat kradzieży i pożaru; współczynnik pomocniczy |

**Suma wag: 1.00** — zmiana wag wymaga zatwierdzenia ludzkiego (limit autonomii w `05-autonomy-risk.md`).

### Mapowania stref

| Parametr | Wartość | Score |
|----------|---------|-------|
| `floodZone` | A (strefa bezpośredniego zagrożenia) | 1.0 |
| | B (strefa pośrednia) | 0.6 |
| | C (strefa potencjalna) | 0.3 |
| | none | 0.0 |
| `fireRiskZone` | high | 1.0 |
| | medium | 0.5 |
| | low | 0.1 |
| `theftRiskZone` | high | 1.0 |
| | medium | 0.5 |
| | low | 0.1 |
| `buildingDensity` | urban | 0.8 |
| | suburban | 0.4 |
| | rural | 0.1 |

### Mapowanie na klasę ryzyka

| Score | Klasa |
|-------|-------|
| < 0.25 | `low` |
| 0.25–0.499… | `medium` |
| 0.50–0.749… | `high` |
| ≥ 0.75 | `critical` |

### Dane wyjściowe

`score` (double, 2 miejsca po przecinku), `classification` (HousingRiskClass), `breakdown` (cztery wkłady po przemnożeniu przez wagę — suma równa `score` ±0.01).

### Przykład obliczeniowy

Dane: `floodZone=B`, `fireRiskZone=low`, `theftRiskZone=high`, `buildingDensity=urban`.

```
flood:   0.30 × 0.6 = 0.18
fire:    0.20 × 0.1 = 0.02
theft:   0.35 × 1.0 = 0.35
density: 0.15 × 0.8 = 0.12

score = 0.67  →  high
```

---

## Algorytm 3: Regułowy — `SpecialCaseRuleAlgorithm`

### Metodologia

Cztery reguły binarne. Każda wyzwolona reguła wymusza minimalny poziom ryzyka. Wynik końcowy = maksimum wymuszonych minimów. Żadna reguła nieaktywna → `low`.

### Dane wejściowe

| Pole | Typ | Dozwolone wartości |
|------|-----|-------------------|
| `isVacant` | `bool` | `true \| false` |
| `isWoodenStructure` | `bool` | `true \| false` |
| `missingInspections` | `bool` | `true \| false` |
| `insuredSumPLN` | `int` | ≥ 0 |

### Definicje reguł

| ID reguły | Warunek wyzwolenia | Min. poziom | Uzasadnienie |
|-----------|-------------------|-------------|-------------|
| `VACANT_PROPERTY` | `isVacant = true` | `high` | Brak bieżącego nadzoru; wyższe ryzyko wandalizmu i nieobjętego pożaru |
| `WOODEN_STRUCTURE` | `isWoodenStructure = true` | `high` | Wyższy współczynnik rozprzestrzeniania ognia wg EN 13501-1 |
| `MISSING_INSPECTIONS` | `missingInspections = true` | `medium` | Nieznany stan instalacji elektrycznej/gazowej |
| `HIGH_INSURED_SUM` | `insuredSumPLN > 500 000` | `medium` | Wysoka ekspozycja finansowa wymaga dodatkowej weryfikacji |

**Uwaga:** Warunek dla `HIGH_INSURED_SUM` jest ścisły (`>`), nie `>=`. Wartość dokładnie 500 000 PLN **nie wyzwala** reguły.

### Pseudokod

```
function evaluate(input):
  triggered = []
  level     = 'low'

  if input.isVacant:
    triggered += ['VACANT_PROPERTY']
    level = max(level, 'high')

  if input.isWoodenStructure:
    triggered += ['WOODEN_STRUCTURE']
    level = max(level, 'high')

  if input.missingInspections:
    triggered += ['MISSING_INSPECTIONS']
    level = max(level, 'medium')

  if input.insuredSumPLN > 500_000:
    triggered += ['HIGH_INSURED_SUM']
    level = max(level, 'medium')

  blocked = ALL_RULES - triggered

  return { classification: level, triggeredRules: triggered, blockedRules: blocked }

Porządek klas: low < medium < high < critical
```

### Dane wyjściowe

`classification` (HousingRiskClass), `triggeredRules` (lista ID wyzwolonych reguł), `blockedRules` (lista pozostałych — przydatna w UI do wyjaśnienia decyzji).

### Przykład obliczeniowy

Dane: `isVacant=false`, `isWoodenStructure=false`, `missingInspections=true`, `insuredSumPLN=450 000`.

```
VACANT_PROPERTY:     false           →  nie wyzwolona
WOODEN_STRUCTURE:    false           →  nie wyzwolona
MISSING_INSPECTIONS: true            →  wyzwolona, minimum: medium
HIGH_INSURED_SUM:    450 000 ≤ 500 000 → nie wyzwolona

triggered = [MISSING_INSPECTIONS]
wynik     = medium
```

---

## Logika Rekomendacji

```
order: low=1, medium=2, high=3, critical=4

recommended = max(ALG-1.classification,
                  ALG-2.classification,
                  ALG-3.classification)

rationale:
  jeśli critical w jakimkolwiek → "Algorytm {nazwa} wskazuje ryzyko krytyczne."
  jeśli wszystkie trzy równe    → "Wszystkie algorytmy zgodne: {klasa}."
  jeśli ≥ 2 wskazuje max        → "Dwa lub więcej algorytmów wskazuje: {klasa}."
  jeśli wszystkie różne         → "Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."
```

---

## Kształt API

### Request — `POST /api/risk/housing/evaluate`

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

**Walidacja wejść:** `buildingAge ≥ 0`; `floor ≥ 0`; `floor ≤ totalFloors`; `claimsLast5Years ≥ 0`; `insuredSumPLN ≥ 0`. Nieznane wartości enum → `400 Bad Request`.

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
    "floor": "floor (5) cannot exceed totalFloors (3)"
  }
}
```

---

## Przypadki Brzegowe i Scenariusze Testowe

### ALG-1 — Progi klasyfikacyjne

| ID | age | floor | total | security | claims | Score | Klasa |
|----|-----|-------|-------|----------|--------|-------|-------|
| T1-01 | 35 | 3 | 10 | medium | 1 | 35 | `medium` |
| T1-02 | 55 | 0 | 5 | none | 3 | 105 | `critical` |
| T1-03 | 5 | 12 | 20 | high | 0 | −25 | `low` |
| T1-04 | — | — | — | — | — | 29 | `low` |
| T1-05 | — | — | — | — | — | 30 | `medium` (próg) |
| T1-06 | — | — | — | — | — | 59 | `medium` |
| T1-07 | — | — | — | — | — | 60 | `high` (próg) |
| T1-08 | — | — | — | — | — | 89 | `high` |
| T1-09 | — | — | — | — | — | 90 | `critical` (próg) |
| T1-10 | 0 | 0 | 1 | basic | 0 | 5 | `low` |

### ALG-2 — Wartości graniczne

| ID | floodZone | fireRiskZone | theftRiskZone | buildingDensity | Score | Klasa |
|----|-----------|-------------|--------------|----------------|-------|-------|
| T2-01 | B | low | high | urban | 0.67 | `high` |
| T2-02 | none | low | low | rural | 0.07 | `low` |
| T2-03 | A | high | high | urban | 0.97 | `critical` |
| T2-04 | C | medium | medium | suburban | 0.43 | `medium` |
| T2-05 | (dobrane arytmetycznie) | | | | 0.25 | `medium` (próg) |
| T2-06 | (dobrane arytmetycznie) | | | | 0.50 | `high` (próg) |
| T2-07 | (dobrane arytmetycznie) | | | | 0.75 | `critical` (próg) |

### ALG-3 — Granice reguł

| ID | isVacant | isWooden | missingInspections | insuredSumPLN | triggeredRules | Klasa |
|----|----------|----------|--------------------|--------------|---------------|-------|
| T3-01 | false | false | false | 300 000 | [] | `low` |
| T3-02 | false | false | true | 300 000 | [MISSING_INSPECTIONS] | `medium` |
| T3-03 | false | false | false | 500 001 | [HIGH_INSURED_SUM] | `medium` |
| T3-04 | false | false | false | **500 000** | [] | `low` (warunek >) |
| T3-05 | true | false | false | 0 | [VACANT_PROPERTY] | `high` |
| T3-06 | false | true | false | 0 | [WOODEN_STRUCTURE] | `high` |
| T3-07 | true | true | true | 600 000 | [wszystkie 4] | `high` |
| T3-08 | false | false | true | 500 001 | [MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `medium` |

### Rekomendacja

| ID | ALG-1 | ALG-2 | ALG-3 | Rekomendacja |
|----|-------|-------|-------|-------------|
| TR-01 | medium | high | medium | `high` |
| TR-02 | low | low | low | `low` |
| TR-03 | low | medium | high | `high` |
| TR-04 | critical | low | low | `critical` |
| TR-05 | medium | medium | medium | `medium` |

---

## Ustalenia Technologiczne z Repozytorium

| Element | Ustalenie | Implikacja dla implementacji |
|---------|-----------|---------------------------|
| Backend pattern | `Results.Json()` — nie `Results.Ok()` | Endpoint housing używa `Results.Json()` dla spójności |
| `@angular/forms` | **Nieobecny** w `package.json` | Formularz oparty wyłącznie na sygnałach + event binding `(input)` / `(change)`, identycznie jak istniejący `AppComponent` |
| TestBed | Konfigurowany przez `test-setup.ts` (`BrowserDynamicTestingModule`) | Testy komponentu mogą używać `TestBed` z Vitest |
| Brak routera | `main.ts` bez `provideRouter()` | `HousingRiskComponent` renderowany jako blok HTML w `AppComponent`, nie jako trasa |
| JSON enum serialization | Brak `JsonStringEnumConverter` w `Program.cs` | Należy dodać `JsonStringEnumConverter` lub używać string enum zamiast C# enum — inaczej deserializacja json z `"medium"` do `SecurityLevel.Medium` się nie powiedzie |
| Istniejący endpoint | `POST /risk-score` — brak zmian | Nowy endpoint całkowicie addytywny; `/risk-score` bez dotykania |
| Projekt .NET | `SampleRiskApi.csproj`, namespace `SampleRiskApi` | Nowe klasy: `namespace SampleRiskApi.Housing;` |

**Ważna uwaga do `50-plan.md` — serializacja enumów w .NET:** Bez `JsonStringEnumConverter`, .NET 8 minimal API domyślnie serializuje C# enum jako **liczby** (`0, 1, 2, 3`), a nie stringi (`"low"`, `"medium"`, `"high"`, `"critical"`). Należy albo:
- Dodać `JsonStringEnumConverter` z `CamelCaseNamingPolicy` do `builder.Services.ConfigureHttpJsonOptions()`, lub
- Użyć stringów bezpośrednio zamiast `enum HousingRiskLevel` (pattern identyczny jak istniejący `riskClass` w `/risk-score`).

Rekomendacja: stringi bezpośrednie w response (`"low"`, `"medium"`, `"high"`, `"critical"`) — spójne z istniejącym `/risk-score`, które zwraca `string RiskClass`. Enumeracje C# można zachować wewnętrznie w logice algorytmów i konwertować przy budowie odpowiedzi.

---

## Referencje Rynkowe i Architektoniczne

| Obszar | Źródło | Zastosowanie |
|--------|--------|-------------|
| Strefy powodziowe A/B/C | ISOK (Informatyczny System Osłony Kraju), IMGW-PIB | Mapowanie `floodZone` w ALG-2 |
| Wskaźniki kradzieży | KGP Statystyki Policji — raport roczny | Uzasadnienie wagi 0.35 dla `theftRiskZone` |
| Ognioodporność materiałów | EN 13501-1 (reakcja na ogień) | Reguła `WOODEN_STRUCTURE` w ALG-3 |
| Taryfikacja ubezpieczeń | PZU, Warta, ERGO Hestia — addytywne modele punktowe | ALG-1: uproszczony GLM bez regresji |
| Zarządzanie ryzykiem | ISO 31000:2018 | Trójwarstwowy model identyfikacja–ocena–klasyfikacja |
| Swiss Re natcat | Raporty powodzi w Polsce | Uzasadnienie wagi 0.30 dla `floodZone` |
| Zasada ostrożności | Standard reasekuracyjny | `recommended = max()` zamiast średniej |

---

## Rekomendacja dla Repozytorium

**Backend (`sample-app/dotnet-api/`):**
- Dodać katalog `Housing/` z klasami algorytmów (statyczne, bezstanowe).
- Endpoint `POST /api/risk/housing/evaluate` w `Program.cs` — jeden `app.MapPost`.
- Response używa stringów dla klas ryzyka (jak istniejący `/risk-score`) — nie C# enum.
- Dodać `JsonStringEnumConverter` **tylko jeśli** request body zawiera enum pola (`securityLevel`, `floodZone`, etc.) — bez konwertera `.NET` nie deserializuje stringów JSON do C# enum.
- Nowy projekt xUnit `dotnet-api-tests/` — algorytmy testowalne bez HTTP.

**Frontend (`sample-app/angular-frontend/`):**
- Nowy standalone component `HousingRiskComponent` z formularzem opartym na sygnałach (bez `ReactiveFormsModule` — pakiet nieobecny).
- Serwis `HousingRiskService` z `HttpClient`.
- Dodać `provideHttpClient()` do `main.ts`.
- Nowy typ `HousingRiskClass = 'low' | 'medium' | 'high' | 'critical'` w osobnym pliku — nie modyfikować istniejącego `RiskClass`.
- Testy przez Vitest + Angular TestBed (`test-setup.ts` już skonfigurowany).

**Kolejność implementacji:** Backend → Testy backendu → Frontend typy → Serwis → Testy serwisu → Komponent → Testy komponentu → Integracja w `AppComponent` → Dokumentacja.

---

```text
/pdlc analyze
```