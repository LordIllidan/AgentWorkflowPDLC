# PDLC Planner Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25287425164
Agent: planner-agent
Model: sonnet
Autonomy mode: full-auto

## Agent Output

Status: READY

# Plan Implementacji — Issue #20: Trzy algorytmy analizy ryzyk w mieszkalnictwie

**Data:** 2026-05-03
**Agent:** planner-agent
**Issue:** [#20](https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20)
**Poprzednie etapy:** `05-autonomy-risk.md`, `10-research.md`, `20-analysis.md`, `40-architecture.md`

---

## Podsumowanie Wykonawcze

Implementacja obejmuje dwa stosy technologiczne — backend .NET 8 i frontend Angular 20 — w aplikacji przykładowej `sample-app`. Całość realizowana w jednym PR na gałęzi `agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni`. Brak zmian w istniejących endpointach, typach i komponentach — wszystkie nowe elementy trafiają do nowych plików i jednego nowego podkatalogu `Housing/`.

**Łączna liczba plików:** 16 nowych + 3 modyfikacje istniejących.

**Kluczowe ustalenia z `10-research.md`:**
- Backend używa `Results.Json()`, nie `Results.Ok()` — nowy endpoint zachowuje spójność
- `@angular/forms` nieobecny — formularze wyłącznie przez sygnały + event binding
- `provideHttpClient()` nieobecny w `main.ts` — wymaga dodania
- Bez `JsonStringEnumConverter` .NET 8 serializuje C# enum jako liczby, nie stringi
- Frontend wywołuje backend bezpośrednio przez URL `http://localhost:8080/...` — brak proxy

**Checkpointy ludzkie przed merge:** code review PR (CP-3).

---

## Sekwencja Implementacji

Kolejność wyznaczona przez zależności: modele → algorytmy → endpoint → testy backendu → typy frontendu → serwis → testy serwisu → komponent → testy komponentu → integracja → dokumentacja.

```
Krok  Platforma   Plik                                                          Zależność
────  ─────────── ───────────────────────────────────────────────────────────── ─────────────────────
  1   .NET        Housing/HousingRiskModels.cs                                  (brak)
  2   .NET        Housing/PropertyScoreAlgorithm.cs                             Krok 1
  3   .NET        Housing/LocationWeightAlgorithm.cs                            Krok 1
  4   .NET        Housing/SpecialCaseRuleAlgorithm.cs                           Krok 1
  5   .NET        Housing/HousingRiskRecommender.cs                             Krok 1
  6   .NET        Program.cs (MODIFY)                                           Kroki 1–5
  7   xUnit       dotnet-api-tests/dotnet-api-tests.csproj                      Kroki 1–6
  8   xUnit       Housing/PropertyScoreAlgorithmTests.cs                        Krok 7
  9   xUnit       Housing/LocationWeightAlgorithmTests.cs                       Krok 7
 10   xUnit       Housing/SpecialCaseRuleAlgorithmTests.cs                      Krok 7
 11   xUnit       Housing/HousingRiskRecommenderTests.cs                        Krok 7
 12   Angular     housing/housing-risk.types.ts                                 (brak)
 13   Angular     housing/housing-risk.service.ts                               Krok 12
 14   Vitest      housing/housing-risk.service.test.ts                          Krok 13
 15   Angular     housing/housing-risk.component.ts                             Kroki 12–13
 16   Vitest      housing/housing-risk.component.test.ts                        Krok 15
 17   Angular     src/main.ts (MODIFY)                                          Krok 13
 18   Angular     src/app/app.component.ts (MODIFY)                             Krok 15
 19   Docs        sample-app/docs/housing-risk-algorithms.md                    Kroki 1–18
```

**Weryfikacja po grupie kroków:**
- Po krokach 1–6: `dotnet build sample-app/dotnet-api/` — zero błędów kompilacji.
- Po krokach 7–11: `dotnet test sample-app/dotnet-api-tests/` — wszystkie testy zielone.
- Po krokach 12–16: `npm test` w `sample-app/angular-frontend/` — testy Vitest przechodzą.
- Po krokach 17–18: `npm start` — aplikacja uruchamia się bez błędów w konsoli przeglądarki.
- Po kroku 19: kontrola manualna kompletności sekcji dokumentu.

---

## Plan Zmian — Plik po Pliku

### Backend — `sample-app/dotnet-api/`

#### Krok 1 — `Housing/HousingRiskModels.cs` (CREATE)

Wszystkie typy domenowe modułu Housing w jednym pliku. Brak zewnętrznych zależności poza `System`.

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

---

#### Krok 2 — `Housing/PropertyScoreAlgorithm.cs` (CREATE)

Klasa statyczna i bezstanowa. Implementuje formuły z `40-architecture.md` §ALG-1.

```csharp
namespace SampleRiskApi.Housing;

public static class PropertyScoreAlgorithm
{
    public static PointBasedResult Evaluate(HousingEvaluationRequest req)
    {
        int agePenalty = req.BuildingAge switch
        {
            < 10                    => 0,
            >= 10 and <= 30         => 10,
            >= 31 and <= 50         => 20,
            _                       => 35
        };

        int floorFactor = req.Floor switch
        {
            <= 1                    => 10,
            >= 2 and <= 4           => 5,
            >= 5 and <= 9           => 0,
            _                       => -5
        };

        int securityDiscount = req.SecurityLevel switch
        {
            SecurityLevel.None      => 0,
            SecurityLevel.Basic     => 5,
            SecurityLevel.Medium    => 10,
            SecurityLevel.High      => 20,
            _                       => 0
        };

        int claimsPenalty = req.ClaimsLast5Years switch
        {
            0   => 0,
            1   => 20,
            2   => 40,
            _   => 60
        };

        int score = agePenalty + floorFactor - securityDiscount + claimsPenalty;

        var classification = score switch
        {
            < 30              => HousingRiskLevel.Low,
            >= 30 and < 60    => HousingRiskLevel.Medium,
            >= 60 and < 90    => HousingRiskLevel.High,
            _                 => HousingRiskLevel.Critical
        };

        return new PointBasedResult(score, classification,
            new PointBasedBreakdown(agePenalty, floorFactor, securityDiscount, claimsPenalty));
    }
}
```

---

#### Krok 3 — `Housing/LocationWeightAlgorithm.cs` (CREATE)

```csharp
namespace SampleRiskApi.Housing;

public static class LocationWeightAlgorithm
{
    private const double WFlood   = 0.30;
    private const double WFire    = 0.20;
    private const double WTheft   = 0.35;
    private const double WDensity = 0.15;

    public static WeightBasedResult Evaluate(HousingEvaluationRequest req)
    {
        double floodScore = req.Location.FloodZone switch
        {
            FloodZone.A     => 1.0,
            FloodZone.B     => 0.6,
            FloodZone.C     => 0.3,
            FloodZone.None  => 0.0,
            _               => 0.0
        };
        double fireScore = req.Location.FireRiskZone switch
        {
            RiskZone.High   => 1.0,
            RiskZone.Medium => 0.5,
            RiskZone.Low    => 0.1,
            _               => 0.0
        };
        double theftScore = req.Location.TheftRiskZone switch
        {
            RiskZone.High   => 1.0,
            RiskZone.Medium => 0.5,
            RiskZone.Low    => 0.1,
            _               => 0.0
        };
        double densityScore = req.Location.BuildingDensity switch
        {
            BuildingDensity.Urban    => 0.8,
            BuildingDensity.Suburban => 0.4,
            BuildingDensity.Rural    => 0.1,
            _                        => 0.0
        };

        double flood   = WFlood   * floodScore;
        double fire    = WFire    * fireScore;
        double theft   = WTheft   * theftScore;
        double density = WDensity * densityScore;
        double total   = Math.Round(flood + fire + theft + density, 2);

        var classification = total switch
        {
            < 0.25              => HousingRiskLevel.Low,
            >= 0.25 and < 0.50  => HousingRiskLevel.Medium,
            >= 0.50 and < 0.75  => HousingRiskLevel.High,
            _                   => HousingRiskLevel.Critical
        };

        return new WeightBasedResult(total, classification,
            new WeightBasedBreakdown(
                Math.Round(flood,   2),
                Math.Round(fire,    2),
                Math.Round(theft,   2),
                Math.Round(density, 2)));
    }
}
```

---

#### Krok 4 — `Housing/SpecialCaseRuleAlgorithm.cs` (CREATE)

```csharp
namespace SampleRiskApi.Housing;

public static class SpecialCaseRuleAlgorithm
{
    private static readonly string[] AllRules =
        ["VACANT_PROPERTY", "WOODEN_STRUCTURE", "MISSING_INSPECTIONS", "HIGH_INSURED_SUM"];

    public static RuleBasedResult Evaluate(HousingEvaluationRequest req)
    {
        var triggered = new List<string>();
        var level     = HousingRiskLevel.Low;

        if (req.SpecialFlags.IsVacant)
        {
            triggered.Add("VACANT_PROPERTY");
            if (level < HousingRiskLevel.High) level = HousingRiskLevel.High;
        }
        if (req.SpecialFlags.IsWoodenStructure)
        {
            triggered.Add("WOODEN_STRUCTURE");
            if (level < HousingRiskLevel.High) level = HousingRiskLevel.High;
        }
        if (req.SpecialFlags.MissingInspections)
        {
            triggered.Add("MISSING_INSPECTIONS");
            if (level < HousingRiskLevel.Medium) level = HousingRiskLevel.Medium;
        }
        if (req.SpecialFlags.InsuredSumPLN > 500_000)
        {
            triggered.Add("HIGH_INSURED_SUM");
            if (level < HousingRiskLevel.Medium) level = HousingRiskLevel.Medium;
        }

        var blocked = AllRules.Except(triggered).ToArray();
        return new RuleBasedResult(level, [.. triggered], blocked);
    }
}
```

---

#### Krok 5 — `Housing/HousingRiskRecommender.cs` (CREATE)

```csharp
namespace SampleRiskApi.Housing;

public static class HousingRiskRecommender
{
    public static RecommendedResult Recommend(
        HousingRiskLevel pointBased,
        HousingRiskLevel weightBased,
        HousingRiskLevel ruleBased)
    {
        var levels = new[] { pointBased, weightBased, ruleBased };
        var max    = levels.Max();

        string rationale;

        if (max == HousingRiskLevel.Critical)
        {
            var name = pointBased  == HousingRiskLevel.Critical ? "punktowy"
                     : weightBased == HousingRiskLevel.Critical ? "wagowy"
                     : "regułowy";
            rationale = $"Algorytm {name} wskazuje ryzyko krytyczne.";
        }
        else if (levels.Distinct().Count() == 1)
        {
            rationale = $"Wszystkie algorytmy zgodne: {FormatLevel(max)}.";
        }
        else if (levels.Count(l => l == max) >= 2)
        {
            rationale = $"Dwa lub więcej algorytmów wskazuje: {FormatLevel(max)}.";
        }
        else
        {
            rationale = $"Rozbieżność algorytmów. Przyjęto najwyższy wynik: {FormatLevel(max)}.";
        }

        return new RecommendedResult(max, rationale);
    }

    private static string FormatLevel(HousingRiskLevel level) => level.ToString().ToLower();
}
```

---

#### Krok 6 — `Program.cs` (MODIFY)

Dodać trzy bloki do istniejącego `Program.cs`. Nie modyfikować istniejącego endpointu `/risk-score`.

**Uwaga:** Istniejący kod używa `Results.Json()` — nowy endpoint zachowuje tę samą konwencję dla spójności.

```csharp
// 1. Dodać using na początku pliku (za istniejącymi):
using SampleRiskApi.Housing;

// 2. Dodać konfigurację JSON — deserializacja stringów JSON do C# enum:
//    (przed app.Build())
builder.Services.ConfigureHttpJsonOptions(opts =>
    opts.SerializerOptions.Converters.Add(
        new System.Text.Json.Serialization.JsonStringEnumConverter(
            System.Text.Json.JsonNamingPolicy.CamelCase)));

// 3. Dodać endpoint przed app.Run():
app.MapPost("/api/risk/housing/evaluate", (HousingEvaluationRequest req) =>
{
    var errors = new Dictionary<string, string>();
    if (req.BuildingAge < 0)
        errors["buildingAge"] = "buildingAge must be >= 0";
    if (req.Floor < 0)
        errors["floor"] = "floor must be >= 0";
    if (req.TotalFloors < 1)
        errors["totalFloors"] = "totalFloors must be >= 1";
    if (req.Floor > req.TotalFloors)
        errors["floor"] = $"floor ({req.Floor}) cannot exceed totalFloors ({req.TotalFloors})";
    if (req.ClaimsLast5Years < 0)
        errors["claimsLast5Years"] = "claimsLast5Years must be >= 0";
    if (req.SpecialFlags.InsuredSumPLN < 0)
        errors["insuredSumPLN"] = "insuredSumPLN must be >= 0";

    if (errors.Count > 0)
        return Results.Json(new { error = "Validation failed", fields = errors },
            statusCode: 400);

    var pointBased  = PropertyScoreAlgorithm.Evaluate(req);
    var weightBased = LocationWeightAlgorithm.Evaluate(req);
    var ruleBased   = SpecialCaseRuleAlgorithm.Evaluate(req);
    var recommended = HousingRiskRecommender.Recommend(
        pointBased.Classification,
        weightBased.Classification,
        ruleBased.Classification);

    return Results.Json(new HousingEvaluationResponse(
        new AlgorithmsResult(pointBased, weightBased, ruleBased),
        recommended));
});
```

---

### Testy backendu — `sample-app/dotnet-api-tests/`

#### Krok 7 — `dotnet-api-tests.csproj` (CREATE)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="xunit" Version="2.9.0" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.10.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\dotnet-api\SampleRiskApi.csproj" />
  </ItemGroup>
</Project>
```

---

#### Krok 8 — `Housing/PropertyScoreAlgorithmTests.cs` (CREATE)

Pokrywa przypadki T1-01 do T1-10 z `20-analysis.md`. Testy jednostkowe bez uruchamiania serwera HTTP.

| ID | age | floor | total | security | claims | Oczekiwany score | Klasa |
|----|-----|-------|-------|----------|--------|-----------------|-------|
| T1-01 | 35 | 3 | 10 | medium | 1 | 20+5−10+20 = **35** | `medium` |
| T1-02 | 55 | 0 | 5 | none | 3 | 35+10−0+60 = **105** | `critical` |
| T1-03 | 5 | 12 | 20 | high | 0 | 0+(−5)−20+0 = **−25** | `low` |
| T1-04 | 20 | 5 | 10 | none | 0 | 10+0−0+0 = **10** | `low` (score=10, <30) |
| T1-05 | 35 | 0 | 5 | none | 0 | 20+10−0+0 = **30** | `medium` (próg) |
| T1-06 | 35 | 3 | 10 | none | 1 | 20+5−0+20 = **45** | `medium` |
| T1-07 | 55 | 2 | 5 | none | 1 | 35+5−0+20 = **60** | `high` (próg) |
| T1-08 | 55 | 0 | 5 | basic | 2 | 35+10−5+40 = **80** | `high` |
| T1-09 | 55 | 0 | 5 | none | 2 | 35+10−0+40 = **85** | `high` |
| T1-10 | 0 | 0 | 1 | basic | 0 | 0+10−5+0 = **5** | `low` |

Próg `score=90 → critical`: `age=55 (35) + floor=0 (10) + sec=none (0) + claims=3 (60) = 105`.
Próg `score=89 → high`: kombinacja do sumy 89 — np. `age=55 (35) + floor=0 (10) + claims=3 (60) - sec=high (20) = 85` — użyć age=55, floor=0, sec=basic, claims=3: 35+10-5+60=100. Alternatywnie zadeklarować test z oczekiwanym score=89 przez wybór kombinacji. Coding worker tworzy odpowiednią kombinację wartości wejściowych, której suma wynosi dokładnie 89.

---

#### Krok 9 — `Housing/LocationWeightAlgorithmTests.cs` (CREATE)

Pokrywa T2-01 do T2-07 z `20-analysis.md`.

| ID | floodZone | fireRiskZone | theftRiskZone | buildingDensity | Score | Klasa |
|----|-----------|-------------|--------------|----------------|-------|-------|
| T2-01 | B | low | high | urban | 0.18+0.02+0.35+0.12 = **0.67** | `high` |
| T2-02 | none | low | low | rural | 0+0.02+0.035+0.015 = **0.07** | `low` |
| T2-03 | A | high | high | urban | 0.30+0.20+0.35+0.12 = **0.97** | `critical` |
| T2-04 | C | medium | medium | suburban | 0.09+0.10+0.175+0.06 = **0.43** | `medium` |
| T2-05 | B | low | low | rural | 0.18+0.02+0.035+0.015 = **0.25** | `medium` (próg) |
| T2-06 | B | low | high | rural | 0.18+0.02+0.35+0.015 = **0.57** | `high` (≥ 0.50) |
| T2-07 | A | high | high | rural | 0.30+0.20+0.35+0.015 = **0.87** | `critical` (≥ 0.75) |

Testy weryfikują wynik numeryczny z tolerancją ±0.01 (zaokrąglenie zmiennoprzecinkowe) ORAZ klasę ryzyka.

---

#### Krok 10 — `Housing/SpecialCaseRuleAlgorithmTests.cs` (CREATE)

Pokrywa T3-01 do T3-08 z `20-analysis.md`.

| ID | isVacant | isWoodenStructure | missingInspections | insuredSumPLN | triggeredRules | Klasa |
|----|----------|-------------------|--------------------|--------------|---------------|-------|
| T3-01 | false | false | false | 300 000 | [] | `low` |
| T3-02 | false | false | true | 300 000 | [MISSING_INSPECTIONS] | `medium` |
| T3-03 | false | false | false | 500 001 | [HIGH_INSURED_SUM] | `medium` |
| T3-04 | false | false | false | **500 000** | [] | `low` (ścisłe `>`) |
| T3-05 | true | false | false | 0 | [VACANT_PROPERTY] | `high` |
| T3-06 | false | true | false | 0 | [WOODEN_STRUCTURE] | `high` |
| T3-07 | true | true | true | 600 000 | [VACANT_PROPERTY, WOODEN_STRUCTURE, MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `high` |
| T3-08 | false | false | true | 500 001 | [MISSING_INSPECTIONS, HIGH_INSURED_SUM] | `medium` |

**Przypadek graniczny T3-04 jest krytyczny** — test musi explicite weryfikować, że `insuredSumPLN = 500 000` (nie 500 001) zwraca `low` z pustą listą reguł.

---

#### Krok 11 — `Housing/HousingRiskRecommenderTests.cs` (CREATE)

Pokrywa TR-01 do TR-05 plus trzy przypadki testowe rationale.

| ID | ALG-1 | ALG-2 | ALG-3 | Rekomendacja | Typ rationale |
|----|-------|-------|-------|-------------|---------------|
| TR-01 | medium | high | medium | `high` | Dwa lub więcej wskazuje `high` |
| TR-02 | low | low | low | `low` | Wszystkie zgodne: `low` |
| TR-03 | low | medium | high | `high` | Rozbieżność — przyjęto najwyższy |
| TR-04 | critical | low | low | `critical` | Algorytm punktowy wskazuje krytyczne |
| TR-05 | medium | medium | medium | `medium` | Wszystkie zgodne: `medium` |
| TR-06 | low | critical | low | `critical` | Algorytm wagowy wskazuje krytyczne |
| TR-07 | critical | critical | low | `critical` | Algorytm punktowy wskazuje krytyczne |
| TR-08 | low | medium | low | `medium` | Rozbieżność — przyjęto najwyższy |

---

### Frontend — `sample-app/angular-frontend/`

#### Krok 12 — `src/app/housing/housing-risk.types.ts` (CREATE)

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

#### Krok 13 — `src/app/housing/housing-risk.service.ts` (CREATE)

```typescript
import { Injectable, inject } from '@angular/core';
import { HttpClient }          from '@angular/common/http';
import { Observable }          from 'rxjs';
import { HousingEvaluationRequest, HousingEvaluationResponse } from './housing-risk.types';

@Injectable({ providedIn: 'root' })
export class HousingRiskService {
  private readonly http = inject(HttpClient);

  evaluate(req: HousingEvaluationRequest): Observable<HousingEvaluationResponse> {
    return this.http.post<HousingEvaluationResponse>(
      'http://localhost:8080/api/risk/housing/evaluate', req);
  }
}
```

URL bezpośredni — brak proxy Angular w `angular.json` (potwierdzone w `10-research.md`).

---

#### Krok 14 — `src/app/housing/housing-risk.service.test.ts` (CREATE)

Dwa testy:
1. `evaluate()` wysyła `POST` na właściwy URL z podanym ciałem requestu.
2. Ciało requestu jest przekazywane bez modyfikacji do `HttpClient.post()`.

Używa `provideHttpClientTesting()` i `HttpTestingController`.

```typescript
import { TestBed }             from '@angular/core/testing';
import { provideHttpClient }   from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { HousingRiskService }  from './housing-risk.service';
import { HousingEvaluationRequest } from './housing-risk.types';

describe('HousingRiskService', () => {
  let service: HousingRiskService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()]
    });
    service  = TestBed.inject(HousingRiskService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('sends POST to correct URL', () => {
    const req = { /* minimal valid request */ } as HousingEvaluationRequest;
    service.evaluate(req).subscribe();
    const testReq = httpMock.expectOne('http://localhost:8080/api/risk/housing/evaluate');
    expect(testReq.request.method).toBe('POST');
    testReq.flush({});
  });

  it('passes request body unchanged', () => {
    const req = { buildingAge: 35 } as HousingEvaluationRequest;
    service.evaluate(req).subscribe();
    const testReq = httpMock.expectOne(r => r.url.includes('/evaluate'));
    expect(testReq.request.body).toEqual(req);
    testReq.flush({});
  });
});
```

---

#### Krok 15 — `src/app/housing/housing-risk.component.ts` (CREATE)

Standalone component z Angular Signals. Sygnały wejściowe formularza (nie `FormGroup`), sygnały wyjściowe (`result`, `isLoading`, `errorMessage`).

**Sygnały stanu:**
```typescript
// wejście
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

// wyjście
readonly result        = signal<HousingEvaluationResponse | null>(null);
readonly isLoading     = signal(false);
readonly errorMessage  = signal<string | null>(null);
```

**Obsługa błędów HTTP:**

| Status | Komunikat |
|--------|-----------|
| 400 | `"Błąd walidacji: {fields}"` |
| 0 (brak połączenia) | `"Nie można połączyć się z API."` |
| 5xx | `"Błąd serwera. Spróbuj ponownie."` |

**Układ widoku porównania:**

```
┌─ ALG-1 Punktowy ──┐  ┌─ ALG-2 Wagowy ───┐  ┌─ ALG-3 Regułowy ─┐
│  score: 35         │  │  score: 0.67      │  │  reguły: 1        │
│  [ MEDIUM ]        │  │  [  HIGH  ]       │  │  [ MEDIUM ]       │
└────────────────────┘  └──────────────────┘  └───────────────────┘
┌─ ★ REKOMENDACJA ──────────────────────────────────────────────────┐
│  [  HIGH  ]  "Rozbieżność algorytmów. Przyjęto: high."            │
└────────────────────────────────────────────────────────────────────┘
```

**Badge klasy ryzyka — OKLCH (design system):**

| Klasa | Hue | Tło | Border | Tekst/dot |
|-------|-----|-----|--------|-----------|
| `low` | 145 | `oklch(95% 0.16 145)` | `oklch(80% 0.16 145)` | `oklch(60% 0.16 145)` |
| `medium` | 75 | `oklch(95% 0.16 75)` | `oklch(80% 0.16 75)` | `oklch(60% 0.16 75)` |
| `high` | 38 | `oklch(95% 0.16 38)` | `oklch(80% 0.16 38)` | `oklch(60% 0.16 38)` |
| `critical` | 18 | `oklch(95% 0.16 18)` | `oklch(80% 0.16 18)` | `oklch(60% 0.16 18)` |

Zawsze para tło + border — nigdy sam kolor bez obramowania (reguła `design.md`).

---

#### Krok 16 — `src/app/housing/housing-risk.component.test.ts` (CREATE)

Cztery testy przy użyciu Vitest + Angular TestBed:

| ID | Scenariusz | Weryfikacja |
|----|------------|-------------|
| C-01 | Komponent renderuje się bez błędów | Brak wyjątku w `TestBed.createComponent` |
| C-02 | Po odpowiedzi 200 wyświetla cztery karty | Trzy karty algorytmów + karta rekomendacji widoczne w DOM |
| C-03 | Po odpowiedzi 400 wyświetla komunikat błędu | `errorMessage` zawiera tekst `"Błąd walidacji"` |
| C-04 | Po błędzie sieci (status 0) wyświetla komunikat | `errorMessage` zawiera `"Nie można połączyć się z API."` |

---

#### Krok 17 — `src/main.ts` (MODIFY)

```typescript
// Przed zmianą:
bootstrapApplication(AppComponent);

// Po zmianie:
import { provideHttpClient } from '@angular/common/http';
bootstrapApplication(AppComponent, {
  providers: [provideHttpClient()]
});
```

Jeśli `provideHttpClient()` już istnieje — pominąć krok, nie duplikować.

---

#### Krok 18 — `src/app/app.component.ts` (MODIFY)

```typescript
// Dodać do imports dekoratora:
import { HousingRiskComponent } from './housing/housing-risk.component';

// W tablicy imports:
imports: [...istniejące, HousingRiskComponent],

// W template — dodać po istniejącej sekcji:
<app-housing-risk></app-housing-risk>
```

---

### Dokumentacja

#### Krok 19 — `sample-app/docs/housing-risk-algorithms.md` (CREATE)

Dokument musi zawierać wszystkie z poniższych sekcji:

| # | Sekcja | Zawartość minimalna |
|---|--------|---------------------|
| 1 | Przegląd | Cel trzech algorytmów, porównanie perspektyw, zasada `max()` dla rekomendacji |
| 2 | ALG-1: Punktowy | Formuła, tablice mapowań składowych, przykład: age=35, floor=3, sec=medium, claims=1 → score=35 → `medium` |
| 3 | ALG-2: Wagowy | Formuła z wagami, tablice stref, uzasadnienie wag (natcat, KGP), przykład: B, low, high, urban → 0.67 → `high` |
| 4 | ALG-3: Regułowy | Definicje reguł binarnych, pseudokod, przykład: missingInspections=true, sum=450 000 → `medium` |
| 5 | Logika rekomendacji | Zasada `max()`, cztery przypadki rationale, przykład rozbieżności |
| 6 | API | Kompletny przykład request/response JSON |
| 7 | Uruchomienie | `dotnet run` (backend) + `npm start` (frontend) — porty i URL |

---

## Plan Testów

### Stack .NET — `dotnet-api-tests/`

| Plik testowy | Przypadki | Narzędzie | Pokrycie |
|---|---|---|---|
| `PropertyScoreAlgorithmTests.cs` | 10 (T1-01–T1-10) | xUnit | Wszystkie progi klasyfikacyjne, wynik ujemny |
| `LocationWeightAlgorithmTests.cs` | 7 (T2-01–T2-07) | xUnit | Wszystkie strefy, progi 0.25/0.50/0.75 |
| `SpecialCaseRuleAlgorithmTests.cs` | 8 (T3-01–T3-08) | xUnit | Każda reguła osobno, wartość graniczna 500 000/500 001 |
| `HousingRiskRecommenderTests.cs` | 8 (TR-01–TR-08) | xUnit | Wszystkie przypadki rationale |
| **Łącznie** | **33** | `dotnet test sample-app/dotnet-api-tests/` | |

### Walidacja API (testy manualne)

| ID | Dane | Oczekiwany status |
|----|------|------------------|
| TV-01 | `floodZone: "X"` (nieznana wartość) | `400 Bad Request` |
| TV-02 | `buildingAge: -1` | `400 Bad Request` |
| TV-03 | `floor: 5, totalFloors: 3` | `400 Bad Request` |
| TV-04 | `claimsLast5Years: -1` | `400 Bad Request` |
| TV-05 | `insuredSumPLN: -100` | `400 Bad Request` |
| TV-06 | Kompletne poprawne dane (przykład z `10-research.md`) | `200 OK` + JSON z trzema algorytmami |
| TV-07 | `POST /risk-score` (istniejący endpoint) | `200 OK` — brak regresji |

### Stack Angular / Vitest

| Plik testowy | Przypadki | Narzędzie | Pokrycie |
|---|---|---|---|
| `housing-risk.service.test.ts` | 2 | Vitest + HttpTestingController | URL, body |
| `housing-risk.component.test.ts` | 4 (C-01–C-04) | Vitest + Angular TestBed | Render, 200, 400, status 0 |
| **Łącznie** | **6** | `npm test` w `angular-frontend/` | |

---

## Plan Dokumentacji

**Plik docelowy:** `sample-app/docs/housing-risk-algorithms.md`

Coding worker pisze dokumentację jako ostatni krok (krok 19), gdy implementacja i testy są ukończone. Nie generować przed implementacją — przykłady obliczeniowe muszą być zweryfikowane przez testy jednostkowe.

---

## Plan Rollback

Wszystkie zmiany addytywne — rollback bez migracji schematu.

| Sytuacja | Działanie |
|----------|-----------|
| Błąd w algorytmie po merge | Revert commita dla pliku `Housing/XxxAlgorithm.cs` |
| Błąd integracji frontendu | Usunięcie `<app-housing-risk>` z template i importu w `app.component.ts` |
| Błąd endpointu | Usunięcie bloku `app.MapPost("/api/risk/housing/evaluate", ...)` z `Program.cs` |
| Pełny rollback | `git revert` lub zamknięcie PR bez merge — `main` niezmieniony |

Istniejący endpoint `/risk-score` i typ `RiskClass` nie są modyfikowane — rollback Housing ich nie dotyka.

---

## Handoff dla Coding Workera

### Zakres pracy

```
Repozytorium: LordIllidan/AgentWorkflowPDLC
Katalog:      sample-app/
Branch:       agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
```

### Pliki do STWORZENIA (16 plików)

```
sample-app/dotnet-api/Housing/HousingRiskModels.cs
sample-app/dotnet-api/Housing/PropertyScoreAlgorithm.cs
sample-app/dotnet-api/Housing/LocationWeightAlgorithm.cs
sample-app/dotnet-api/Housing/SpecialCaseRuleAlgorithm.cs
sample-app/dotnet-api/Housing/HousingRiskRecommender.cs
sample-app/dotnet-api-tests/dotnet-api-tests.csproj
sample-app/dotnet-api-tests/Housing/PropertyScoreAlgorithmTests.cs
sample-app/dotnet-api-tests/Housing/LocationWeightAlgorithmTests.cs
sample-app/dotnet-api-tests/Housing/SpecialCaseRuleAlgorithmTests.cs
sample-app/dotnet-api-tests/Housing/HousingRiskRecommenderTests.cs
sample-app/angular-frontend/src/app/housing/housing-risk.types.ts
sample-app/angular-frontend/src/app/housing/housing-risk.service.ts
sample-app/angular-frontend/src/app/housing/housing-risk.service.test.ts
sample-app/angular-frontend/src/app/housing/housing-risk.component.ts
sample-app/angular-frontend/src/app/housing/housing-risk.component.test.ts
sample-app/docs/housing-risk-algorithms.md
```

### Pliki do MODYFIKACJI (3 pliki)

```
sample-app/dotnet-api/Program.cs
  → dodać: using SampleRiskApi.Housing;
  → dodać: JsonStringEnumConverter z CamelCaseNamingPolicy w ConfigureHttpJsonOptions
  → dodać: app.MapPost("/api/risk/housing/evaluate", ...) używając Results.Json()
  → NIE modyfikować: istniejącego endpointu /risk-score

sample-app/angular-frontend/src/main.ts
  → dodać: import { provideHttpClient } from '@angular/common/http';
  → dodać: provideHttpClient() do tablicy providers
  → (pominąć jeśli provideHttpClient() już istnieje)

sample-app/angular-frontend/src/app/app.component.ts
  → dodać: import HousingRiskComponent
  → dodać: HousingRiskComponent do tablicy imports w dekoratorze
  → dodać: <app-housing-risk> w template po istniejącej sekcji
```

### Warunki ukończenia

- [ ] `dotnet build sample-app/dotnet-api/` — zero błędów kompilacji
- [ ] `dotnet test sample-app/dotnet-api-tests/` — wszystkie 33 testy zielone
- [ ] `npm test` w `sample-app/angular-frontend/` — wszystkie 6 testów Vitest zielone
- [ ] `npm start` w `sample-app/angular-frontend/` — aplikacja uruchamia się bez błędów w konsoli przeglądarki
- [ ] Ręczne wypełnienie formularza + weryfikacja czterech kart (ALG-1, ALG-2, ALG-3, Rekomendacja)
- [ ] `POST /risk-score` nadal zwraca `200 OK` — brak regresji
- [ ] `sample-app/docs/housing-risk-algorithms.md` zawiera wszystkie 7 sekcji

### Ograniczenia

Coding worker **nie może**:
- Modyfikować plików spoza listy powyżej
- Zmieniać wag algorytmu wagowego (`flood=0.30, fire=0.20, theft=0.35, density=0.15`)
- Używać `Results.Ok()` zamiast `Results.Json()` w nowym endpoincie
- Dodawać klasy `regulated` do `HousingRiskClass`
- Mergować PR do `main` — wymagany code review (CP-3)

### Warunki zatrzymania (zgłosić blokadę)

1. `sample-app/dotnet-api/SampleRiskApi.csproj` nie istnieje lub ma inną nazwę — zaktualizować `<ProjectReference>` w `.csproj` testów przed kontynuacją.
2. `src/main.ts` używa `bootstrapModule` zamiast `bootstrapApplication` — wymagana inna ścieżka integracji `HttpClient`.
3. Backend używa .NET 6 — składnia `Results.Json()` z `statusCode:` może wymagać innej przeciążonej sygnatury.
4. `builder.Services.ConfigureHttpJsonOptions` nie istnieje (inna wersja SDK) — użyć `builder.Services.AddControllers().AddJsonOptions(...)` lub stringów bezpośrednich zamiast C# enum w request/response.

---

## Checkpointy Ludzkie

| # | Moment | Wymagane działanie | Uzasadnienie |
|---|--------|--------------------|--------------|
| CP-1 | Po `40-architecture.md` | Zatwierdzić kształt API, nazwy endpointów, typy domenowe | Spełniony przez zatwierdzenie `40-architecture.md` |
| CP-2 | Po `50-plan.md` | Zatwierdzić kolejność kroków i warunki ukończenia | Spełniany przez zatwierdzenie niniejszego artefaktu |
| CP-3 | Przed merge do `main` | Code review PR — weryfikacja formuł, testów, zgodności z `design.md` | Gwarancja poprawności matematycznej algorytmów i deterministyczności wyników |

---

```text
/approve ai-coding
```