# PDLC Architect Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25287339331
Agent: architect-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Status: READY

# Architektura — Issue #20: Trzy algorytmy analizy ryzyk w mieszkalnictwie

**Data:** 2026-05-03
**Agent:** architect-agent
**Issue:** [#20](https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20)
**Poprzednie etapy:** `05-autonomy-risk.md`, `10-research.md`, `20-analysis.md`

---

## Podsumowanie Decyzji Architektonicznych

Implementacja trzech algorytmów oceny ryzyka mieszkalnictwa wymaga minimalnych, izolowanych zmian w dwóch komponentach aplikacji przykładowej `sample-app`. Żadna istniejąca klasa, typ ani endpoint nie jest modyfikowana — wszystkie nowe elementy trafiają do nowych plików w nowych katalogach.

Zweryfikowany stan repozytorium (2026-05-03):

| Element | Stan |
|---------|------|
| `sample-app/dotnet-api/Program.cs` | Istnieje — Minimal API z `Results.Json()`, dwa endpointy (`GET /`, `POST /risk-score`) |
| `sample-app/dotnet-api/SampleRiskApi.csproj` | Istnieje — .NET 8 |
| `sample-app/dotnet-api-tests/` | **Nie istnieje** — wymaga stworzenia |
| `sample-app/angular-frontend/src/main.ts` | Istnieje — `bootstrapApplication`, **brak** `provideHttpClient()` |
| `sample-app/angular-frontend/src/app/app.component.ts` | Istnieje — standalone, inline template |
| `sample-app/angular-frontend/src/app/risk-summary.ts` | Istnieje — zawiera `RiskClass` z klasą `regulated` |
| `@angular/forms` | **Nieobecny** w `package.json` — formularze przez sygnały + event binding |

**Pięć kluczowych decyzji architektonicznych:**

| # | Decyzja | Wybór | Uzasadnienie |
|---|---------|-------|--------------|
| ADR-1 | Organizacja backendu | Nowy katalog `Housing/` w `dotnet-api/` | Izolacja modułu; logika algorytmów niezależna od warstwy HTTP |
| ADR-2 | Testy backendu | Nowy projekt xUnit `dotnet-api-tests/` | Standardowy wzorzec .NET; testy bez uruchamiania serwera |
| ADR-3 | Integracja frontendu | `HousingRiskComponent` jako nowa sekcja w `AppComponent` | Brak routera w aplikacji; minimalna zmiana; komponent standalone |
| ADR-4 | Typy TypeScript | Nowy plik `housing-risk.types.ts` — `HousingRiskClass` oddzielnie od `RiskClass` | Różne domeny (PDLC ≠ mieszkalnictwo); klasa `regulated` nie dotyczy mieszkalnictwa |
| ADR-5 | HTTP w frontendzie | Dodać `provideHttpClient()` do `main.ts` | Brak w aplikacji; jeden punkt konfiguracji DI |

---

## Dotknięte Aplikacje i Pliki

### Backend — `sample-app/dotnet-api/`

| Operacja | Plik | Opis |
|----------|------|------|
| MODIFY | `Program.cs` | Dodać endpoint `POST /api/risk/housing/evaluate` i `using SampleRiskApi.Housing;` |
| CREATE | `Housing/HousingRiskModels.cs` | Rekordy request/response + enumeracje domenowe |
| CREATE | `Housing/PropertyScoreAlgorithm.cs` | ALG-1 — algorytm punktowy cech nieruchomości |
| CREATE | `Housing/LocationWeightAlgorithm.cs` | ALG-2 — algorytm wagowy lokalizacji i ekspozycji |
| CREATE | `Housing/SpecialCaseRuleAlgorithm.cs` | ALG-3 — algorytm regułowy przypadków specjalnych |
| CREATE | `Housing/HousingRiskRecommender.cs` | Logika agregacji i rekomendacji końcowej |

### Testy backendu — `sample-app/dotnet-api-tests/` *(nowy projekt)*

| Operacja | Plik | Opis |
|----------|------|------|
| CREATE | `dotnet-api-tests.csproj` | Projekt xUnit z `<ProjectReference>` do `SampleRiskApi` |
| CREATE | `Housing/PropertyScoreAlgorithmTests.cs` | Testy ALG-1 — 10 przypadków (T1-01–T1-10) |
| CREATE | `Housing/LocationWeightAlgorithmTests.cs` | Testy ALG-2 — 7 przypadków (T2-01–T2-07) |
| CREATE | `Housing/SpecialCaseRuleAlgorithmTests.cs` | Testy ALG-3 — 8 przypadków (T3-01–T3-08) |
| CREATE | `Housing/HousingRiskRecommenderTests.cs` | Testy rekomendacji — 5 przypadków (TR-01–TR-05) + 3 rationale |

### Frontend — `sample-app/angular-frontend/`

| Operacja | Plik | Opis |
|----------|------|------|
| MODIFY | `src/main.ts` | Dodać `provideHttpClient()` do `bootstrapApplication` |
| MODIFY | `src/app/app.component.ts` | Importować i renderować `HousingRiskComponent` jako drugą sekcję |
| CREATE | `src/app/housing/housing-risk.types.ts` | `HousingRiskClass`, typy request/response |
| CREATE | `src/app/housing/housing-risk.service.ts` | `HousingRiskService` — `HttpClient.post()` |
| CREATE | `src/app/housing/housing-risk.component.ts` | Standalone component z formularzem i widokiem porównania |
| CREATE | `src/app/housing/housing-risk.service.test.ts` | Vitest — testy serwisu |
| CREATE | `src/app/housing/housing-risk.component.test.ts` | Vitest + Angular TestBed — testy komponentu |

### Dokumentacja

| Operacja | Plik | Opis |
|----------|------|------|
| CREATE | `sample-app/docs/housing-risk-algorithms.md` | Opis założeń, formuły, przykłady dla każdego algorytmu |

**Łącznie: 16 nowych plików + 3 modyfikacje istniejących.**

---

## Model Domenowy

### Backend — hierarchia typów .NET (`HousingRiskModels.cs`)

```csharp
namespace SampleRiskApi.Housing;

public enum HousingRiskLevel { Low, Medium, High, Critical }
public enum SecurityLevel    { None, Basic, Medium, High }
public enum FloodZone        { A, B, C, None }
public enum RiskZone         { High, Medium, Low }
public enum BuildingDensity  { Urban, Suburban, Rural }

public sealed record LocationData(
    FloodZone       FloodZone,
    RiskZone        FireRiskZone,
    RiskZone        TheftRiskZone,
    BuildingDensity BuildingDensity);

public sealed record SpecialFlagsData(
    bool IsVacant,
    bool IsWoodenStructure,
    bool MissingInspections,
    int  InsuredSumPLN);

public sealed record HousingEvaluationRequest(
    int              BuildingAge,
    int              Floor,
    int              TotalFloors,
    SecurityLevel    SecurityLevel,
    int              ClaimsLast5Years,
    LocationData     Location,
    SpecialFlagsData SpecialFlags);

public sealed record PointBasedBreakdown(
    int AgePenalty, int FloorFactor, int SecurityDiscount, int ClaimsPenalty);

public sealed record WeightBasedBreakdown(
    double Flood, double Fire, double Theft, double Density);

public sealed record PointBasedResult(
    int Score, HousingRiskLevel Classification, PointBasedBreakdown Breakdown);

public sealed record WeightBasedResult(
    double Score, HousingRiskLevel Classification, WeightBasedBreakdown Breakdown);

public sealed record RuleBasedResult(
    HousingRiskLevel Classification,
    string[]         TriggeredRules,
    string[]         BlockedRules);

public sealed record AlgorithmsResult(
    PointBasedResult  PointBased,
    WeightBasedResult WeightBased,
    RuleBasedResult   RuleBased);

public sealed record RecommendedResult(
    HousingRiskLevel Classification,
    string           Rationale);

public sealed record HousingEvaluationResponse(
    AlgorithmsResult  Algorithms,
    RecommendedResult Recommended);
```

**Uwaga krytyczna — serializacja enumów:** Domyślnie .NET 8 serializuje enum jako liczby (`0, 1, 2`). Aby request JSON z wartościami `"medium"`, `"B"`, `"high"` był poprawnie deserializowany do C# enum, wymagany jest `JsonStringEnumConverter` z `CamelCaseNamingPolicy` w `builder.Services.ConfigureHttpJsonOptions()`. Response używa stringów dla klas ryzyka (tak jak istniejący `/risk-score`) — alternatywnie enum `HousingRiskLevel` konwertowany do stringa przy budowie odpowiedzi.

### Frontend — typy TypeScript (`housing-risk.types.ts`)

```typescript
export type HousingRiskClass = 'low' | 'medium' | 'high' | 'critical';
export type SecurityLevel    = 'none' | 'basic' | 'medium' | 'high';
export type FloodZone        = 'A' | 'B' | 'C' | 'none';
export type RiskZoneLevel    = 'high' | 'medium' | 'low';
export type BuildingDensity  = 'urban' | 'suburban' | 'rural';

export interface HousingLocationData {
  floodZone:       FloodZone;
  fireRiskZone:    RiskZoneLevel;
  theftRiskZone:   RiskZoneLevel;
  buildingDensity: BuildingDensity;
}

export interface HousingSpecialFlags {
  isVacant:           boolean;
  isWoodenStructure:  boolean;
  missingInspections: boolean;
  insuredSumPLN:      number;
}

export interface HousingEvaluationRequest {
  buildingAge:      number;
  floor:            number;
  totalFloors:      number;
  securityLevel:    SecurityLevel;
  claimsLast5Years: number;
  location:         HousingLocationData;
  specialFlags:     HousingSpecialFlags;
}

export interface PointBasedBreakdown {
  agePenalty: number; floorFactor: number;
  securityDiscount: number; claimsPenalty: number;
}
export interface WeightBasedBreakdown {
  flood: number; fire: number; theft: number; density: number;
}
export interface PointBasedResult {
  score: number; classification: HousingRiskClass; breakdown: PointBasedBreakdown;
}
export interface WeightBasedResult {
  score: number; classification: HousingRiskClass; breakdown: WeightBasedBreakdown;
}
export interface RuleBasedResult {
  classification: HousingRiskClass;
  triggeredRules: string[];
  blockedRules: string[];
}
export interface AlgorithmsResult {
  pointBased: PointBasedResult;
  weightBased: WeightBasedResult;
  ruleBased: RuleBasedResult;
}
export interface RecommendedResult {
  classification: HousingRiskClass;
  rationale: string;
}
export interface HousingEvaluationResponse {
  algorithms: AlgorithmsResult;
  recommended: RecommendedResult;
}
```

`HousingRiskClass` nie zawiera klasy `regulated` — ta należy do domeny PDLC. Nie modyfikować istniejącego `risk-summary.ts`.

---

## Interfejsy Algorytmów i Reguła Rekomendacji

### Sygnatury metod C# — statyczne i bezstanowe

```csharp
public static class PropertyScoreAlgorithm
{
    public static PointBasedResult Evaluate(HousingEvaluationRequest req);
}

public static class LocationWeightAlgorithm
{
    public static WeightBasedResult Evaluate(HousingEvaluationRequest req);
}

public static class SpecialCaseRuleAlgorithm
{
    public static RuleBasedResult Evaluate(HousingEvaluationRequest req);
}

public static class HousingRiskRecommender
{
    public static RecommendedResult Recommend(
        HousingRiskLevel pointBased,
        HousingRiskLevel weightBased,
        HousingRiskLevel ruleBased);
}
```

Metody statyczne i bezstanowe — identyczne dane wejściowe zawsze dają identyczny wynik. Brak DI. Testowalne bez uruchamiania serwera HTTP.

### ALG-1 — PropertyScoreAlgorithm (formuła)

```
score = age_penalty(buildingAge)
      + floor_factor(floor)
      − security_discount(securityLevel)
      + claims_penalty(claimsLast5Years)

age_penalty:
  buildingAge < 10            →  0
  10 ≤ buildingAge ≤ 30       → 10
  31 ≤ buildingAge ≤ 50       → 20
  buildingAge > 50            → 35

floor_factor:
  floor ≤ 1                   → 10
  2 ≤ floor ≤ 4               →  5
  5 ≤ floor ≤ 9               →  0
  floor ≥ 10                  → −5

security_discount:
  None → 0 | Basic → 5 | Medium → 10 | High → 20

claims_penalty:
  0 szkód → 0 | 1 → 20 | 2 → 40 | ≥ 3 → 60

Klasyfikacja:
  score <  30                 → low
  30 ≤ score < 60             → medium
  60 ≤ score < 90             → high
  score ≥ 90                  → critical
  (wynik ujemny: warunek < 30 obejmuje wartości ujemne → low)
```

### ALG-2 — LocationWeightAlgorithm (formuła)

```
score = 0.30 × flood_score(floodZone)
      + 0.20 × fire_score(fireRiskZone)
      + 0.35 × theft_score(theftRiskZone)
      + 0.15 × density_score(buildingDensity)

flood_score:   A=1.0, B=0.6, C=0.3, none=0.0
fire_score:    high=1.0, medium=0.5, low=0.1
theft_score:   high=1.0, medium=0.5, low=0.1
density_score: urban=0.8, suburban=0.4, rural=0.1

Suma wag: 1.00 (zmiana wag wymaga zatwierdzenia ludzkiego — limit autonomii)

Klasyfikacja:
  score <  0.25               → low
  0.25 ≤ score < 0.50         → medium
  0.50 ≤ score < 0.75         → high
  score ≥ 0.75                → critical

Score zaokrąglony do 2 miejsc po przecinku (Math.Round).
```

### ALG-3 — SpecialCaseRuleAlgorithm (reguły binarne)

```
Reguły — każda wymusza minimalny poziom:
  VACANT_PROPERTY:     isVacant = true            → minimum: high
  WOODEN_STRUCTURE:    isWoodenStructure = true   → minimum: high
  MISSING_INSPECTIONS: missingInspections = true  → minimum: medium
  HIGH_INSURED_SUM:    insuredSumPLN > 500 000    → minimum: medium
  (warunek ścisły: 500 000 nie wyzwala; 500 001 wyzwala)

wynik = max(wszystkie minima wyzwolonych reguł)
żadna reguła → low
Porządek: low < medium < high < critical
```

### Logika rekomendacji (deterministyczna)

```
order: low=1, medium=2, high=3, critical=4

recommended = max(ALG-1.classification,
                  ALG-2.classification,
                  ALG-3.classification)

rationale:
  critical w jakimkolwiek         → "Algorytm {punktowy/wagowy/regułowy} wskazuje ryzyko krytyczne."
  wszystkie trzy równe            → "Wszystkie algorytmy zgodne: {klasa}."
  dwa lub więcej wskazuje max     → "Dwa lub więcej algorytmów wskazuje: {klasa}."
  wszystkie różne                 → "Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."
```

---

## Kontrakt API

### Endpoint

```
POST /api/risk/housing/evaluate
Content-Type: application/json
```

Istniejące endpointy bez zmian: `GET /` i `POST /risk-score`.

### Request — przykład

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

**Dozwolone wartości enum:**

| Pole | Dozwolone wartości |
|------|--------------------|
| `securityLevel` | `none`, `basic`, `medium`, `high` |
| `floodZone` | `A`, `B`, `C`, `none` |
| `fireRiskZone` | `high`, `medium`, `low` |
| `theftRiskZone` | `high`, `medium`, `low` |
| `buildingDensity` | `urban`, `suburban`, `rural` |

**Walidacja liczbowa:** `buildingAge ≥ 0`, `floor ≥ 0`, `totalFloors ≥ 1`, `floor ≤ totalFloors`, `claimsLast5Years ≥ 0`, `insuredSumPLN ≥ 0`.

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

Przy wielu błędach odpowiedź zawiera wszystkie naruszenia naraz w polu `fields`.

---

## Walidacja i Obsługa Błędów

### Walidacja backendu (przed algorytmami)

| Pole | Reguła | Komunikat |
|------|--------|-----------|
| `buildingAge` | ≥ 0 | `buildingAge must be >= 0` |
| `floor` | ≥ 0 | `floor must be >= 0` |
| `totalFloors` | ≥ 1 | `totalFloors must be >= 1` |
| `floor` | ≤ `totalFloors` | `floor ({f}) cannot exceed totalFloors ({t})` |
| `claimsLast5Years` | ≥ 0 | `claimsLast5Years must be >= 0` |
| `insuredSumPLN` | ≥ 0 | `insuredSumPLN must be >= 0` |
| Wszystkie enum | wartość z listy | `Unknown value '{v}'. Allowed: {lista}` |

Nieznana wartość enum deserializowana przez `JsonStringEnumConverter` — .NET rzuci wyjątek deserializacji zanim trafi do walidacji ręcznej. Alternatywnie: string input + ręczna walidacja jak w istniejącym `/risk-score`.

### Obsługa błędów HTTP w frontendzie

```typescript
readonly errorMessage = signal<string | null>(null);

// HTTP 400 → "Błąd walidacji: {fields}"
// status 0  → "Nie można połączyć się z API."
// HTTP 5xx  → "Błąd serwera. Spróbuj ponownie."
```

Po poprawnej odpowiedzi `errorMessage` resetuje się do `null`.

---

## Struktura Komponentu Frontend

### `HousingRiskComponent` — sygnały

```typescript
// wejście formularza
readonly buildingAge        = signal(0);
readonly floor              = signal(0);
readonly totalFloors        = signal(1);
readonly securityLevel      = signal<SecurityLevel>('none');
readonly claimsLast5Years   = signal(0);
readonly floodZone          = signal<FloodZone>('none');
readonly fireRiskZone       = signal<RiskZoneLevel>('low');
readonly theftRiskZone      = signal<RiskZoneLevel>('low');
readonly buildingDensity    = signal<BuildingDensity>('rural');
readonly isVacant           = signal(false);
readonly isWoodenStructure  = signal(false);
readonly missingInspections = signal(false);
readonly insuredSumPLN      = signal(0);

// wynik
readonly result        = signal<HousingEvaluationResponse | null>(null);
readonly isLoading     = signal(false);
readonly errorMessage  = signal<string | null>(null);

evaluate(): void;
```

Brak `FormGroup` — `@angular/forms` nieobecny w `package.json`. Binding przez `(input)` i `(change)` identycznie jak istniejący `AppComponent`.

### Układ widoku porównania

```
┌─ ALG-1 Punktowy ─┐  ┌─ ALG-2 Wagowy ──┐  ┌─ ALG-3 Regułowy ┐
│  score: 35        │  │  score: 0.67     │  │  reguły: 1      │
│  [ MEDIUM ]       │  │  [  HIGH  ]      │  │  [ MEDIUM ]     │
└───────────────────┘  └─────────────────┘  └─────────────────┘
┌─ ★ REKOMENDACJA ─────────────────────────────────────────────┐
│  [  HIGH  ]  "Rozbieżność algorytmów. Przyjęto: high."       │
└───────────────────────────────────────────────────────────────┘
```

### Badge klasy ryzyka — OKLCH (design system)

| Klasa | Hue | Tło | Border | Tekst/dot |
|-------|-----|-----|--------|-----------|
| `low` | 145 | `oklch(95% 0.16 145)` | `oklch(80% 0.16 145)` | `oklch(60% 0.16 145)` |
| `medium` | 75 | `oklch(95% 0.16 75)` | `oklch(80% 0.16 75)` | `oklch(60% 0.16 75)` |
| `high` | 38 | `oklch(95% 0.16 38)` | `oklch(80% 0.16 38)` | `oklch(60% 0.16 38)` |
| `critical` | 18 | `oklch(95% 0.16 18)` | `oklch(80% 0.16 18)` | `oklch(60% 0.16 18)` |

Zawsze para tło + border — nigdy sam kolor bez obramowania (reguła design.md).

---

## Macierz Testów z Przypadkami Brzegowymi

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
| T2-06 | B | low | high | rural | 0.18+0.02+0.35+0.015=**0.565** | `high` (próg ≥ 0.50) |
| T2-07 | A | high | high | rural | 0.30+0.20+0.35+0.015=**0.865** | `critical` (próg ≥ 0.75) |

### ALG-3 — Algorytm regułowy

| ID | isVacant | isWoodenStructure | missingInspections | insuredSumPLN | triggeredRules | Klasa |
|----|----------|-------------------|-------------------|--------------|---------------|-------|
| T3-01 | false | false | false | 300 000 | [] | `low` |
| T3-02 | false | false | true | 300 000 | [MISSING_INSPECTIONS] | `medium` |
| T3-03 | false | false | false | 500 001 | [HIGH_INSURED_SUM] | `medium` |
| T3-04 | false | false | false | **500 000** | [] | `low` (warunek ścisły `>`) |
| T3-05 | true | false | false | 0 | [VACANT_PROPERTY] | `high` |
| T3-06 | false | true | false | 0 | [WOODEN_STRUCTURE] | `high` |
| T3-07 | true | true | true | 600 000 | [wszystkie 4] | `high` |
| T3-08 | false | false | true | 500 001 | [MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `medium` |

### Rekomendacja końcowa

| ID | ALG-1 | ALG-2 | ALG-3 | Rekomendacja | Typ rationale |
|----|-------|-------|-------|-------------|---------------|
| TR-01 | medium | high | medium | `high` | Dwa lub więcej wskazuje high |
| TR-02 | low | low | low | `low` | Wszystkie zgodne |
| TR-03 | low | medium | high | `high` | Rozbieżność — przyjęto najwyższy |
| TR-04 | critical | low | low | `critical` | Algorytm punktowy wskazuje krytyczne |
| TR-05 | medium | medium | medium | `medium` | Wszystkie zgodne |

### Walidacja API

| ID | Dane wejściowe | Oczekiwany status |
|----|---------------|------------------|
| TV-01 | `floodZone: "X"` | `400 Bad Request` |
| TV-02 | `buildingAge: -1` | `400 Bad Request` |
| TV-03 | `floor: 5`, `totalFloors: 3` | `400 Bad Request` |
| TV-04 | `claimsLast5Years: -1` | `400 Bad Request` |
| TV-05 | `insuredSumPLN: -100` | `400 Bad Request` |
| TV-06 | Kompletne poprawne dane | `200 OK` z trzema algorytmami |
| TV-07 | `POST /risk-score` (istniejący) | `200 OK` — brak regresji |

---

## Bezpieczeństwo, Dane i Prywatność

| Wymiar | Ocena | Szczegół |
|--------|-------|---------|
| Dane osobowe (PII) | **Brak** | Dane opisują nieruchomość: cechy fizyczne, strefy zagrożeń, flagi techniczne. Brak imienia, adresu, PESEL, danych kontaktowych. |
| Uwierzytelnianie | **Brak wpływu** | Nowy endpoint bez auth — identycznie jak istniejący `/risk-score`. Aplikacja przykładowa nie ma warstwy auth. |
| Autoryzacja | **Brak wpływu** | Brak ACL. Brak zmian względem istniejącej konfiguracji. |
| Wstrzyknięcie | **Brak ryzyka** | Wejścia to liczby i stringi enum. Backend używa typowanych rekordów C# i `System.Text.Json`. Brak SQL, brak shell, brak template rendering. |
| CORS | **Brak zmian** | Nowy endpoint dziedziczy konfigurację `app.UseCors()` jeśli istnieje. |
| Dane finansowe | **Minimalne** | `insuredSumPLN` to liczba całkowita — nie jest to transakcja. Brak wymagań PCI DSS. |
| Logowanie | **Brak zmian** | Aplikacja nie loguje requestów. W przyszłości: nie logować `insuredSumPLN` bez analizy GDPR. |
| Obserwabilność | **Poza zakresem** | Aplikacja przykładowa bez metryk i tracingu. Brak wymogu w tym issue. |

---

## Decyzje Architektoniczne (ADR)

### ADR-1: Katalog `Housing/` zamiast inline w `Program.cs`

**Kontekst:** Istniejący `Program.cs` ma dwa rekordy inline i jest minimalne (36 linii). Nowe algorytmy to 4–5 klas z logiką tablicową.

**Decyzja:** Nowy podkatalog `Housing/` w `dotnet-api/`. Każdy algorytm to osobny plik statycznej klasy.

**Konsekwencje:** Izolacja domeny; algorytmy testowalne bez HTTP; `Program.cs` pozostaje minimalne z jednym nowym `MapPost`. Rollback = usunięcie katalogu i jednej linii w `Program.cs`.

---

### ADR-2: Osobny projekt testów xUnit (`dotnet-api-tests/`)

**Kontekst:** `SampleRiskApi.csproj` nie ma xUnit. Brak jakichkolwiek testów .NET w repozytorium.

**Decyzja:** Nowy projekt `dotnet-api-tests/dotnet-api-tests.csproj` z `<ProjectReference>` do `SampleRiskApi`.

**Konsekwencje:** `dotnet test sample-app/dotnet-api-tests/` uruchamia testy. Wzorzec standardowy .NET; brak ryzyka kolizji z kodem produkcyjnym.

---

### ADR-3: `HousingRiskComponent` jako nowa sekcja w `AppComponent`, bez routera

**Kontekst:** `main.ts` nie ma `provideRouter()`. Cała aplikacja to jeden `AppComponent` z inline template. Brak `RouterModule`.

**Decyzja:** `HousingRiskComponent` importowany i renderowany jako drugi blok HTML w `AppComponent`.

**Konsekwencje:** Minimalna zmiana (1 import + 1 tag w template). Oba widoki widoczne jednocześnie. Routing można dodać w przyszłości bez refaktorowania algorytmów.

---

### ADR-4: `HousingRiskClass` oddzielnie od `RiskClass`

**Kontekst:** `risk-summary.ts` eksportuje `RiskClass = 'low' | 'medium' | 'high' | 'regulated' | 'critical'`. Klasa `regulated` należy do domeny PDLC — nie ma sensu w kontekście mieszkalnictwa.

**Decyzja:** Nowy typ `HousingRiskClass = 'low' | 'medium' | 'high' | 'critical'` w osobnym pliku `housing-risk.types.ts`.

**Konsekwencje:** Ścisła typizacja TypeScript; niemożliwe pomyłkowe użycie `'regulated'` w logice mieszkalnictwa; brak modyfikacji istniejącego pliku.

---

### ADR-5: `provideHttpClient()` w `main.ts`

**Kontekst:** `main.ts` wywołuje `bootstrapApplication(AppComponent)` bez żadnych providers. `HousingRiskService` potrzebuje `HttpClient` przez DI.

**Decyzja:** Jedna linia `{ providers: [provideHttpClient()] }` w `bootstrapApplication` w `src/main.ts`.

**Konsekwencje:** `HttpClient` dostępny w całej aplikacji. Testy serwisu używają `provideHttpClientTesting()`.

---

## Kolejność Implementacji

```
 1.  Backend — modele i enumeracje      Housing/HousingRiskModels.cs
 2.  Backend — ALG-1                    Housing/PropertyScoreAlgorithm.cs
 3.  Backend — ALG-2                    Housing/LocationWeightAlgorithm.cs
 4.  Backend — ALG-3                    Housing/SpecialCaseRuleAlgorithm.cs
 5.  Backend — rekomendacja             Housing/HousingRiskRecommender.cs
 6.  Backend — endpoint                 Program.cs (jeden nowy MapPost + JsonStringEnumConverter)
 7.  Testy backendu — projekt           dotnet-api-tests/dotnet-api-tests.csproj
 8.  Testy backendu — ALG-1             Housing/PropertyScoreAlgorithmTests.cs
 9.  Testy backendu — ALG-2             Housing/LocationWeightAlgorithmTests.cs
10.  Testy backendu — ALG-3             Housing/SpecialCaseRuleAlgorithmTests.cs
11.  Testy backendu — rekomendacja      Housing/HousingRiskRecommenderTests.cs
12.  Frontend — typy                    housing/housing-risk.types.ts
13.  Frontend — serwis                  housing/housing-risk.service.ts
14.  Testy serwisu                      housing/housing-risk.service.test.ts
15.  Frontend — komponent               housing/housing-risk.component.ts
16.  Testy komponentu                   housing/housing-risk.component.test.ts
17.  provideHttpClient                  src/main.ts
18.  Integracja w AppComponent          src/app/app.component.ts
19.  Dokumentacja                       sample-app/docs/housing-risk-algorithms.md
```

Weryfikacja po grupach:
- Po krokach 1–6: `dotnet build sample-app/dotnet-api/` — zero błędów.
- Po krokach 7–11: `dotnet test sample-app/dotnet-api-tests/` — 32 testy zielone.
- Po krokach 12–16: `npm test` w `angular-frontend/` — 6 testów Vitest zielone.
- Po krokach 17–18: `npm start` — aplikacja bez błędów w konsoli przeglądarki.

---

## Checkpointy Ludzkie

| # | Etap | Wymagane działanie | Uzasadnienie |
|---|------|--------------------|--------------|
| CP-1 | Po tym artefakcie | Zatwierdzić kształt API, nazwy endpointów i typy domenowe | Kontrakt API jest bazą dla obu stosów — zmiana po implementacji kosztuje refaktoring w dwóch miejscach |
| CP-2 | Po artefakcie `plan` | Zatwierdzić kolejność kroków i warunki ukończenia | Upewnić się, że frontend nie startuje przed stabilnym API |
| CP-3 | Przed merge do `main` | Code review PR — weryfikacja formuł, testów, zgodności z design.md | Gwarancja poprawności matematycznej i deterministyczności wyników |

---

```text
/pdlc plan
```
```