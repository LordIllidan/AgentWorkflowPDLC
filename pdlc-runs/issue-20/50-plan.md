# PDLC Planner Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25272435172
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

**Szacowany nakład (coding worker):** 2–3 godziny przy pełnym kontekście z artefaktów.

**Checkpointy ludzkie przed merge:** code review PR (CP-3 wg `05-autonomy-risk.md`).

---

## Sekwencja Implementacji

Kolejność wyznaczona przez zależności: modele → algorytmy → endpoint → testy backendu → typy frontendu → serwis → testy serwisu → komponent → testy komponentu → integracja → dokumentacja.

```
Krok  Platforma   Plik                                                        Zależność
────  ─────────── ─────────────────────────────────────────────────────────── ───────────────────────
  1   .NET        Housing/HousingRiskModels.cs                                (brak)
  2   .NET        Housing/PropertyScoreAlgorithm.cs                           Krok 1
  3   .NET        Housing/LocationWeightAlgorithm.cs                          Krok 1
  4   .NET        Housing/SpecialCaseRuleAlgorithm.cs                         Krok 1
  5   .NET        Housing/HousingRiskRecommender.cs                           Krok 1
  6   .NET        Program.cs (MODIFY)                                         Kroki 1–5
  7   xUnit       dotnet-api-tests/dotnet-api-tests.csproj                    Kroki 1–6
  8   xUnit       Housing/PropertyScoreAlgorithmTests.cs                      Krok 7
  9   xUnit       Housing/LocationWeightAlgorithmTests.cs                     Krok 7
 10   xUnit       Housing/SpecialCaseRuleAlgorithmTests.cs                    Krok 7
 11   xUnit       Housing/HousingRiskRecommenderTests.cs                      Krok 7
 12   Angular     housing/housing-risk.types.ts                               (brak)
 13   Angular     housing/housing-risk.service.ts                             Krok 12
 14   Vitest      housing/housing-risk.service.test.ts                        Krok 13
 15   Angular     housing/housing-risk.component.ts                           Kroki 12–13
 16   Vitest      housing/housing-risk.component.test.ts                      Krok 15
 17   Angular     src/main.ts (MODIFY)                                        Krok 13
 18   Angular     src/app/app.component.ts (MODIFY)                           Krok 15
 19   Docs        sample-app/docs/housing-risk-algorithms.md                  Kroki 1–18
```

**Weryfikacja po grupie kroków:**
- Po krokach 1–6: `dotnet build sample-app/dotnet-api/` — zero błędów kompilacji.
- Po krokach 7–11: `dotnet test sample-app/dotnet-api-tests/` — wszystkie testy zielone.
- Po krokach 12–16: `npm test` w `sample-app/angular-frontend/` — testy Vitest przechodzą.
- Po krokach 17–18: `npm start` — aplikacja uruchamia się bez błędów w konsoli przeglądarki.
- Po kroku 19: kontrola manualna sekcji dokumentu.

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
            < 10                => 0,
            >= 10 and <= 30     => 10,
            >= 31 and <= 50     => 20,
            _                   => 35
        };

        int floorFactor = req.Floor switch
        {
            <= 1                => 10,
            >= 2 and <= 4       => 5,
            >= 5 and <= 9       => 0,
            _                   => -5
        };

        int securityDiscount = req.SecurityLevel switch
        {
            SecurityLevel.None   => 0,
            SecurityLevel.Basic  => 5,
            SecurityLevel.Medium => 10,
            SecurityLevel.High   => 20,
            _                    => 0
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
            FloodZone.A    => 1.0,
            FloodZone.B    => 0.6,
            FloodZone.C    => 0.3,
            FloodZone.None => 0.0,
            _              => 0.0
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

Dodać dwa bloki do istniejącego `Program.cs`. Nie modyfikować istniejącego endpointu `/risk-score`.

```csharp
// 1. Dodać using na początku pliku:
using SampleRiskApi.Housing;

// 2. Dodać konfigurację JSON (jeśli nie istnieje) — obsługa enum jako string:
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
        return Results.BadRequest(new { error = "Validation failed", fields = errors });

    var pointBased  = PropertyScoreAlgorithm.Evaluate(req);
    var weightBased = LocationWeightAlgorithm.Evaluate(req);
    var ruleBased   = SpecialCaseRuleAlgorithm.Evaluate(req);
    var recommended = HousingRiskRecommender.Recommend(
        pointBased.Classification,
        weightBased.Classification,
        ruleBased.Classification);

    return Results.Ok(new HousingEvaluationResponse(
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

Kluczowe przypadki testowe:

| ID | age | floor | total | sec | claims | Oczekiwany score | Klasa |
|----|-----|-------|-------|-----|--------|-----------------|-------|
| T1-01 | 35 | 3 | 10 | medium | 1 | 35 | medium |
| T1-02 | 55 | 0 | 5 | none | 3 | 105 | critical |
| T1-03 | 5 | 12 | 20 | high | 0 | −25 | low |
| T1-05 | 35 | 0 | 5 | none | 0 | 30 | medium (próg) |
| T1-07 | 55 | 2 | 5 | none | 1 | 60 | high (próg) |
| T1-10 | 0 | 0 | 1 | basic | 0 | 5 | low |

---

#### Krok 9 — `Housing/LocationWeightAlgorithmTests.cs` (CREATE)

Pokrywa T2-01 do T2-07. Weryfikuje wyniki numeryczne i klasyfikacje dla wszystkich kombinacji stref.

Kluczowe przypadki:

| ID | flood | fire | theft | density | Score | Klasa |
|----|-------|------|-------|---------|-------|-------|
| T2-01 | B | low | high | urban | 0.67 | high |
| T2-02 | none | low | low | rural | 0.07 | low |
| T2-03 | A | high | high | urban | 0.97 | critical |
| T2-05 | B | low | low | rural | 0.25 | medium (próg) |

---

#### Krok 10 — `Housing/SpecialCaseRuleAlgorithmTests.cs` (CREATE)

Pokrywa T3-01 do T3-08. Kluczowy przypadek graniczny: `insuredSumPLN = 500 000` → `low` (warunek `> 500 000`, nie `>=`); `insuredSumPLN = 500 001` → `medium`.

---

#### Krok 11 — `Housing/HousingRiskRecommenderTests.cs` (CREATE)

Pokrywa TR-01 do TR-05 oraz trzy testy rationale (wszystkie zgodne, critical, rozbieżność).

| ID | ALG-1 | ALG-2 | ALG-3 | Rekomendacja |
|----|-------|-------|-------|-------------|
| TR-01 | medium | high | medium | high |
| TR-02 | low | low | low | low |
| TR-03 | low | medium | high | high |
| TR-04 | critical | low | low | critical |
| TR-05 | medium | medium | medium | medium |

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
  classification: HousingRiskClass; triggeredRules: string[]; blockedRules: string[];
}
export interface AlgorithmsResult {
  pointBased: PointBasedResult; weightBased: WeightBasedResult; ruleBased: RuleBasedResult;
}
export interface RecommendedResult { classification: HousingRiskClass; rationale: string; }
export interface HousingEvaluationResponse {
  algorithms: AlgorithmsResult; recommended: RecommendedResult;
}
```

Typ `HousingRiskClass` jest oddzielny od istniejącego `RiskClass` — nie zawiera klasy `regulated` (domena PDLC, nie mieszkalnictwo). Nie modyfikować `risk-summary.ts`.

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

---

#### Krok 14 — `src/app/housing/housing-risk.service.test.ts` (CREATE)

Dwa testy: weryfikacja URL endpointu + metody POST, oraz niezmodyfikowane przekazanie ciała requestu. Używa `provideHttpClientTesting()` i `HttpTestingController`.

---

#### Krok 15 — `src/app/housing/housing-risk.component.ts` (CREATE)

Standalone component z Angular Signals. Sygnały wejściowe formularza (nie `FormGroup`), sygnały wyjściowe (`result`, `isLoading`, `errorMessage`). Template inline z:
- Formularzem (13 pól wejściowych)
- Trzema kartami algorytmów (ALG-1, ALG-2, ALG-3)
- Wyróżnioną kartą rekomendacji

Badge klasy ryzyka — kolory OKLCH zgodne z design systemem:

| Klasa | Hue | Tło | Border | Tekst |
|-------|-----|-----|--------|-------|
| low | 145 | oklch(95% 0.16 145) | oklch(80% 0.16 145) | oklch(60% 0.16 145) |
| medium | 75 | oklch(95% 0.16 75) | oklch(80% 0.16 75) | oklch(60% 0.16 75) |
| high | 38 | oklch(95% 0.16 38) | oklch(80% 0.16 38) | oklch(60% 0.16 38) |
| critical | 18 | oklch(95% 0.16 18) | oklch(80% 0.16 18) | oklch(60% 0.16 18) |

Obsługa błędów HTTP:
- `400` → `"Błąd walidacji: {fields}"`
- `status 0` → `"Nie można połączyć się z API."`
- `5xx` → `"Błąd serwera. Spróbuj ponownie."`

---

#### Krok 16 — `src/app/housing/housing-risk.component.test.ts` (CREATE)

Cztery testy: renderowanie bez błędów, wyświetlenie kart po poprawnej odpowiedzi API, komunikat błędu przy 400, komunikat przy błędzie sieci (status 0).

---

#### Krok 17 — `src/main.ts` (MODIFY)

```typescript
// Przed zmianą:
bootstrapApplication(AppComponent, { providers: [] });

// Po zmianie:
import { provideHttpClient } from '@angular/common/http';
bootstrapApplication(AppComponent, { providers: [provideHttpClient()] });
```

---

#### Krok 18 — `src/app/app.component.ts` (MODIFY)

```typescript
// Dodać do imports komponentu:
import { HousingRiskComponent } from './housing/housing-risk.component';

// W tablicy imports dekoratora:
imports: [...istniejące, HousingRiskComponent],

// W template — dodać po istniejącej sekcji:
<app-housing-risk></app-housing-risk>
```

---

#### Krok 19 — `sample-app/docs/housing-risk-algorithms.md` (CREATE)

Dokument musi zawierać:
1. Przegląd — cel trzech algorytmów i porównanie perspektyw
2. ALG-1: Punktowy — formuła, tablice mapowań, przykład (age=35, floor=3, sec=medium, claims=1 → score=35 → medium)
3. ALG-2: Wagowy — formuła z wagami, tablice stref, uzasadnienie wag, przykład (B, low, high, urban → 0.67 → high)
4. ALG-3: Regułowy — definicje reguł, pseudokod, przykład (missingInspections=true, sum=450 000 → medium)
5. Logika rekomendacji — zasada max(), przypadki rationale, przykład rozbieżności
6. Kompletny request/response JSON
7. Instrukcja uruchomienia (`dotnet run` + `npm start`)

---

## Plan Testów

### Stack .NET — `dotnet-api-tests/`

| Plik testowy | Przypadki | Narzędzie |
|---|---|---|
| `PropertyScoreAlgorithmTests.cs` | 9 (T1-01 do T1-10) | xUnit |
| `LocationWeightAlgorithmTests.cs` | 7 (T2-01 do T2-07) | xUnit |
| `SpecialCaseRuleAlgorithmTests.cs` | 8 (T3-01 do T3-08) | xUnit |
| `HousingRiskRecommenderTests.cs` | 8 (TR-01–05 + 3 rationale) | xUnit |
| **Łącznie** | **32** | `dotnet test sample-app/dotnet-api-tests/` |

Każdy test weryfikuje konkretny wynik liczbowy, nie tylko typ zwracanego obiektu. Każdy próg klasyfikacyjny i każda reguła binarna z wartością graniczną mają własny przypadek testowy.

Walidacja API (testy manualne lub opcjonalne testy integracyjne):

| ID | Dane | Oczekiwany status |
|----|------|------------------|
| TV-01 | `floodZone: "X"` | 400 |
| TV-02 | `buildingAge: -1` | 400 |
| TV-03 | `floor: 5, totalFloors: 3` | 400 |
| TV-04 | `claimsLast5Years: -1` | 400 |
| TV-05 | kompletne poprawne dane | 200 OK |
| TV-06 | `POST /risk-score` (istniejący) | 200 OK — brak regresji |

### Stack Angular / Vitest

| Plik testowy | Przypadki | Narzędzie |
|---|---|---|
| `housing-risk.service.test.ts` | 2 | Vitest + HttpTestingController |
| `housing-risk.component.test.ts` | 4 | Vitest + Angular TestBed |
| **Łącznie** | **6** | `npm test` w `angular-frontend/` |

---

## Plan Dokumentacji

**Plik docelowy:** `sample-app/docs/housing-risk-algorithms.md`

Coding worker pisze dokumentację jako ostatni krok (krok 19), gdy implementacja i testy są ukończone. Dokument nie może być wygenerowany przed implementacją — przykłady obliczeniowe muszą być zweryfikowane przez testy.

---

## Plan Rollback

Wszystkie zmiany są addytywne — rollback nie wymaga migracji schematu ani koordynacji z innymi zespołami.

| Sytuacja | Działanie |
|----------|-----------|
| Błąd w algorytmie po merge | Revert commit dla pliku `Housing/XxxAlgorithm.cs` |
| Błąd integracji frontendu | Usunięcie `<app-housing-risk>` z template i importu w `app.component.ts` |
| Błąd endpointu w `Program.cs` | Usunięcie bloku `app.MapPost("/api/risk/housing/evaluate", ...)` |
| Pełny rollback | `git revert` lub zamknięcie PR bez merge — `main` niezmieniony |

Istniejące endpointy i typy nie są modyfikowane — rollback Housing nie dotyka `/risk-score` ani `RiskClass`.

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
  → dodać: JsonStringEnumConverter (jeśli brak)
  → dodać: app.MapPost("/api/risk/housing/evaluate", ...)
  → NIE modyfikować: istniejącego endpointu /risk-score

sample-app/angular-frontend/src/main.ts
  → dodać: import { provideHttpClient } from '@angular/common/http';
  → dodać: provideHttpClient() do tablicy providers

sample-app/angular-frontend/src/app/app.component.ts
  → dodać: import HousingRiskComponent
  → dodać: HousingRiskComponent do tablicy imports
  → dodać: <app-housing-risk> w template
```

### Warunki ukończenia

- [ ] `dotnet build sample-app/dotnet-api/` — zero błędów kompilacji
- [ ] `dotnet test sample-app/dotnet-api-tests/` — wszystkie 32 testy zielone
- [ ] `npm test` w `sample-app/angular-frontend/` — wszystkie 6 testów Vitest zielone
- [ ] `npm start` w `sample-app/angular-frontend/` — aplikacja uruchamia się bez błędów w konsoli
- [ ] Ręczne wypełnienie formularza w przeglądarce + weryfikacja czterech kart (ALG-1, ALG-2, ALG-3, Rekomendacja)
- [ ] `POST /risk-score` nadal zwraca `200 OK` — brak regresji
- [ ] `sample-app/docs/housing-risk-algorithms.md` zawiera wszystkie wymagane sekcje

### Ograniczenia

Coding worker **nie może**:
- Modyfikować plików poza listą powyżej
- Zmieniać wag algorytmu wagowego (flood=0.30, fire=0.20, theft=0.35, density=0.15)
- Dodawać klasy `regulated` do `HousingRiskClass`
- Mergować PR do `main` — wymagany code review (CP-3)

### Warunki zatrzymania (zgłosić blokadę)

1. `sample-app/dotnet-api/SampleRiskApi.csproj` nie istnieje lub ma inną nazwę — zaktualizować `<ProjectReference>` w pliku `.csproj` testów.
2. `src/main.ts` używa `bootstrapModule` zamiast `bootstrapApplication` — wymagana inna ścieżka integracji `HttpClient`.
3. `provideHttpClient()` już istnieje w `main.ts` — pominąć krok 17, nie duplikować.
4. Backend używa .NET 6 — zaktualizować składnię `Results.BadRequest` i `Results.Ok`.

---

## Checkpointy Ludzkie

| # | Moment | Wymagane działanie | Uzasadnienie |
|---|--------|--------------------|--------------|
| CP-3 | Przed merge do `main` | Code review PR — weryfikacja formuł, testów, zgodności z design.md | Gwarancja poprawności algorytmów przed wejściem do `main` |

CP-1 (kształt API) i CP-2 (podział zadań) zostały spełnione przez zatwierdzenie artefaktów `40-architecture.md` i niniejszego `50-plan.md`.

---

## Następne polecenie

```text
/approve ai-coding
```