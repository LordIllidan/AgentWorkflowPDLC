# PDLC Research Agent

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
Branch: agent/pdlc-issue-20-pdlc-doda-3-algorytmy-analizy-ryzyk-w-mieszkalni
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25271984901
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

Issue #20 wymaga dodania trzech niezależnych algorytmów oceny ryzyka mieszkalnictwa do aplikacji przykładowej `sample-app`. Każdy algorytm stosuje inną metodologię: scoring cech nieruchomości, ważona ocena ekspozycji lokalizacyjnej oraz klasyfikacja regułowa przypadków specjalnych. Backend to minimalne API .NET 8 w `sample-app/dotnet-api/`; frontend to aplikacja Angular 20 z komponentem standalone w `sample-app/angular-frontend/`. Istniejący endpoint `/risk-score` obsługuje ryzyko autonomii PDLC — nowe algorytmy mieszkalnictwa trafią do oddzielnego endpointu `POST /api/risk/housing/evaluate`. Wszystkie algorytmy są deterministyczne, formuły zamknięte, brak zewnętrznych API. Zakres jest dobrze ograniczony i gotowy do etapu analyze.

---

## Ustalenia dot. Repozytorium

| Element | Stan |
|---------|------|
| Backend | `sample-app/dotnet-api/` — .NET 8 minimal API, jeden plik `Program.cs`, jeden endpoint `/risk-score` |
| Frontend | `sample-app/angular-frontend/` — Angular 20 standalone, jeden komponent `AppComponent`, Signals |
| Testy | Vitest + `@angular/core/testing` TestBed (nie Karma/Jasmine) |
| Klasy ryzyka (istniejące) | `low \| medium \| high \| regulated \| critical` |
| Klasy ryzyka (mieszkalnictwo) | `low \| medium \| high \| critical` — brak `regulated` (ta klasa jest domeną PDLC) |
| Proxy API | Brak proxy w Angular; .NET API uruchamiane oddzielnie (Dockerfile wskazuje port 8080) |
| `insurance-x/` | Nie istnieje w tym repozytorium — CLAUDE.md opisuje inne środowisko |

**Implikacja architektoniczna:** Nowy endpoint housing musi być dodany do `Program.cs` w `sample-app/dotnet-api/`. Frontend wywołuje API przez `HttpClient` lub przez mockowany serwis.

---

## Założenia Domenowe — Ryzyko Mieszkalnictwa

### Kontekst ubezpieczeniowy

Ocena ryzyka mieszkalnictwa w ubezpieczeniach majątkowych opiera się na trzech filarach:

1. **Cechy nieruchomości** — wiek, konstrukcja, piętro, zabezpieczenia, historia szkód. Stabilne i mierzalne przy zawarciu umowy.
2. **Lokalizacja i ekspozycja** — strefy zagrożeń (powódź, pożar, kradzież), gęstość zabudowy. Zależą od danych zewnętrznych (GUS, IMGW, mapy zagrożeń).
3. **Przypadki specjalne** — niejednorodne warunki, które nie mieszczą się w formułach ciągłych (pustostany, budynki drewniane, brak przeglądów).

### Założenia przyjęte w tej implementacji

- Dane wejściowe dostarczone przez użytkownika — brak integracji z zewnętrznymi rejestrami w tej fazie.
- Waluta: PLN. Próg wysokiej sumy ubezpieczenia: 500 000 PLN.
- Klasy ryzyka: `low | medium | high | critical`. Klasa `regulated` nie jest stosowana w kontekście mieszkalnictwa.
- Wyniki deterministyczne — te same dane wejściowe zawsze dają ten sam wynik.
- Rekomendacja końcowa pochodzi z logiki agregacji (zasada ostrożności: `max`), nie z ML ani głosowania.

---

## Algorytm 1: Punktowy — `PropertyScoreAlgorithm`

### Metodologia

Sumowanie punktów karnych i bonusowych za cechy fizyczne nieruchomości. Wynik to liczba całkowita bez jednostki; klasyfikowana progami liczbowymi.

### Dane wejściowe

| Pole | Typ | Opis |
|------|-----|------|
| `buildingAge` | `int` | Wiek budynku w latach (0 = nowy) |
| `floor` | `int` | Kondygnacja lokalu (0 = parter) |
| `totalFloors` | `int` | Łączna liczba kondygnacji budynku |
| `securityLevel` | `string` | Poziom zabezpieczeń: `none \| basic \| medium \| high` |
| `claimsLast5Years` | `int` | Liczba zgłoszonych szkód w ostatnich 5 latach |

### Formuła

```
score = age_penalty(buildingAge)
      + floor_factor(floor, totalFloors)
      - security_discount(securityLevel)
      + claims_penalty(claimsLast5Years)
```

### Mapowania składowych

| Składowa | Warunek | Punkty |
|----------|---------|--------|
| `age_penalty` | wiek < 10 lat | 0 |
| | 10–30 lat | 10 |
| | 31–50 lat | 20 |
| | > 50 lat | 35 |
| `floor_factor` | parter lub 1. piętro (floor ≤ 1) | 10 |
| | 2.–4. piętro | 5 |
| | 5.–9. piętro | 0 |
| | 10. piętro i wyżej | −5 |
| `security_discount` | brak (`none`) | 0 |
| | podstawowe (`basic`) | 5 |
| | średnie (`medium`) | 10 |
| | zaawansowane (`high`) | 20 |
| `claims_penalty` | 0 szkód | 0 |
| | 1 szkoda | 20 |
| | 2 szkody | 40 |
| | 3 szkody i więcej | 60 |

### Dane wyjściowe i mapowanie na klasę ryzyka

| Score | Klasa ryzyka |
|-------|-------------|
| < 30 | `low` |
| 30–59 | `medium` |
| 60–89 | `high` |
| ≥ 90 | `critical` |

Odpowiedź zawiera: `score` (int), `classification` (HousingRiskClass), `breakdown` (wartości każdej składowej).

### Przykład obliczeniowy

Dane: wiek 35 lat, 3. piętro w 10-piętrowym budynku, zabezpieczenia `medium`, 1 szkoda w 5 latach.

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

Ważona suma znormalizowanych wskaźników zagrożeń lokalizacyjnych. Wynik to liczba zmiennoprzecinkowa 0.0–1.0; klasyfikowana progami.

### Dane wejściowe

| Pole | Typ | Opis |
|------|-----|------|
| `floodZone` | `string` | Strefa powodziowa: `A \| B \| C \| none` |
| `fireRiskZone` | `string` | Strefa zagrożenia pożarowego: `high \| medium \| low` |
| `theftRiskZone` | `string` | Strefa zagrożenia kradzieżowego: `high \| medium \| low` |
| `buildingDensity` | `string` | Gęstość zabudowy: `urban \| suburban \| rural` |

### Formuła

```
score = 0.30 * flood_score(floodZone)
      + 0.20 * fire_score(fireRiskZone)
      + 0.35 * theft_score(theftRiskZone)
      + 0.15 * density_score(buildingDensity)
```

### Uzasadnienie wag

| Wymiar | Waga | Uzasadnienie |
|--------|------|--------------|
| Powódź | 0.30 | Najwyższe szkody jednostkowe; trudna do mitygacji przez właściciela |
| Pożar | 0.20 | Wysokie szkody, ale częściowo zależne od zabezpieczeń (pokryte w Alg. 1) |
| Kradzież | 0.35 | Najwyższa częstotliwość szkód w ubezpieczeniach mieszkaniowych w Polsce |
| Gęstość zabudowy | 0.15 | Koreluje z kradzieżą i pożarem, ale pośrednio |

### Mapowania stref na wartości 0.0–1.0

| Parametr | Wartość | Score |
|----------|---------|-------|
| `floodZone` | `A` | 1.0 |
| | `B` | 0.6 |
| | `C` | 0.3 |
| | `none` | 0.0 |
| `fireRiskZone` | `high` | 1.0 |
| | `medium` | 0.5 |
| | `low` | 0.1 |
| `theftRiskZone` | `high` | 1.0 |
| | `medium` | 0.5 |
| | `low` | 0.1 |
| `buildingDensity` | `urban` | 0.8 |
| | `suburban` | 0.4 |
| | `rural` | 0.1 |

### Dane wyjściowe i mapowanie na klasę ryzyka

| Score | Klasa ryzyka |
|-------|-------------|
| < 0.25 | `low` |
| 0.25–0.49 | `medium` |
| 0.50–0.74 | `high` |
| ≥ 0.75 | `critical` |

Odpowiedź zawiera: `score` (float, 2 miejsca po przecinku), `classification` (HousingRiskClass), `breakdown` (wkład każdego czynnika po przemnożeniu przez wagę).

### Przykład obliczeniowy

Dane: `floodZone=B`, `fireRiskZone=low`, `theftRiskZone=high`, `buildingDensity=urban`.

```
flood:   0.30 * 0.6 = 0.180
fire:    0.20 * 0.1 = 0.020
theft:   0.35 * 1.0 = 0.350
density: 0.15 * 0.8 = 0.120

score = 0.670  →  high
```

---

## Algorytm 3: Regułowy — `SpecialCaseRuleAlgorithm`

### Metodologia

Zestaw reguł binarnych. Każda reguła, jeśli wyzwolona, wymusza minimalny poziom ryzyka. Wynik końcowy to maksimum spośród wszystkich wyzwolonych reguł. Brak wyzwolonych reguł → `low`.

### Dane wejściowe

| Pole | Typ | Opis |
|------|-----|------|
| `isVacant` | `bool` | Lokal pustostan (niezamieszkały ≥ 60 dni) |
| `isWoodenStructure` | `bool` | Budynek drewniany lub szkielet drewniany |
| `missingInspections` | `bool` | Brak wymaganego przeglądu technicznego |
| `insuredSumPLN` | `int` | Suma ubezpieczenia w PLN |

### Definicje reguł

| ID reguły | Warunek wyzwolenia | Minimalny poziom | Uzasadnienie |
|-----------|-------------------|------------------|--------------|
| `VACANT_PROPERTY` | `isVacant = true` | `high` | Pustostan — brak bieżącej kontroli, wyższe ryzyko wandalizmu i pożaru |
| `WOODEN_STRUCTURE` | `isWoodenStructure = true` | `high` | Drewno — wyższy wskaźnik rozprzestrzeniania ognia wg EN 13501 |
| `MISSING_INSPECTIONS` | `missingInspections = true` | `medium` | Brak przeglądu = nieznany stan techniczny instalacji |
| `HIGH_INSURED_SUM` | `insuredSumPLN > 500 000` | `medium` | Wysoka ekspozycja finansowa wymaga co najmniej średniego priorytetu weryfikacji |

### Pseudokod

```
function evaluate(input):
  triggered = []
  maxLevel = 'low'

  if input.isVacant:
    triggered.add('VACANT_PROPERTY')
    maxLevel = max(maxLevel, 'high')

  if input.isWoodenStructure:
    triggered.add('WOODEN_STRUCTURE')
    maxLevel = max(maxLevel, 'high')

  if input.missingInspections:
    triggered.add('MISSING_INSPECTIONS')
    maxLevel = max(maxLevel, 'medium')

  if input.insuredSumPLN > 500_000:
    triggered.add('HIGH_INSURED_SUM')
    maxLevel = max(maxLevel, 'medium')

  return { classification: maxLevel, triggeredRules: triggered }

Porządek klas: low < medium < high < critical
```

### Dane wyjściowe

`classification` (HousingRiskClass), `triggeredRules` (lista nazw wyzwolonych reguł), `blockedRules` (lista reguł niewyzwolonych — przydatna do wyjaśnienia wyniku).

### Przykład obliczeniowy

Dane: `isVacant=false`, `isWoodenStructure=false`, `missingInspections=true`, `insuredSumPLN=450000`.

```
VACANT_PROPERTY:     false           →  nie wyzwolona
WOODEN_STRUCTURE:    false           →  nie wyzwolona
MISSING_INSPECTIONS: true            →  wyzwolona, minimum: medium
HIGH_INSURED_SUM:    450000 ≤ 500000 →  nie wyzwolona

triggered = [MISSING_INSPECTIONS]
wynik     = medium
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

**Walidacja wejść:** `buildingAge` ≥ 0; `floor` ≥ 0 i ≤ `totalFloors`; `claimsLast5Years` ≥ 0; `insuredSumPLN` ≥ 0. Nieznane wartości enum → `400 Bad Request`.

### Response

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
    "rationale": "Algorytm wagowy wskazuje wysokie ryzyko kradzieży w strefie miejskiej (0.670). Algorytm regułowy sygnalizuje brak przeglądów technicznych."
  }
}
```

---

## Logika Rekomendacji

```
klasyfikacja_numeryczna: low=1, medium=2, high=3, critical=4

recommended = max(pointBased.classification,
                  weightBased.classification,
                  ruleBased.classification)

rationale:
  jeśli wszystkie trzy równe    → "Wszystkie algorytmy zgodne: {klasa}."
  jeśli dwa zgodne, jeden niższy → "Dwa algorytmy wskazują {klasa}."
  jeśli wszystkie różne          → "Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."
  jeśli critical w jakimkolwiek  → zawsze zwracaj critical z wyjaśnieniem który algorytm
```

---

## Przypadki Brzegowe i Scenariusze Testowe

### Algorytm 1 — progi graniczne

| Scenariusz | Oczekiwany score | Oczekiwana klasa |
|------------|-----------------|-----------------|
| Stary budynek, parter, brak ochrony, 3+ szkody | 35+10+0+60=105 | `critical` |
| score=59 | 59 | `medium` |
| score=60 | 60 | `high` |
| Nowy budynek, wysoko, max ochrona, brak szkód | 0+(−5)−20+0=−25 | `low` (ujemne < 30) |
| floor > totalFloors | użyć floor = totalFloors | prawidłowe odliczenie |

### Algorytm 2 — wartości brzegowe

| Scenariusz | Oczekiwany score | Klasa |
|------------|-----------------|-------|
| Wszystko minimalne | 0×0.30+0.1×0.20+0.1×0.35+0.1×0.15=0.07 | `low` |
| Wszystko maksymalne | 1.0×0.30+1.0×0.20+1.0×0.35+0.8×0.15=0.97 | `critical` |
| Dokładnie 0.25 | 0.25 | `medium` (≥0.25) |
| Dokładnie 0.50 | 0.50 | `high` (≥0.50) |

### Algorytm 3 — przypadki graniczne

| Scenariusz | Wynik |
|------------|-------|
| Żadna reguła nie wyzwolona | `low` |
| `insuredSumPLN = 500 000` (dokładnie) | nie wyzwolona (warunek: > 500 000) |
| `insuredSumPLN = 500 001` | `medium` — wyzwolona |
| Obie reguły high wyzwolone jednocześnie | `high` |

---

## Referencje Rynkowe i Architektoniczne

| Obszar | Podejście | Zastosowanie |
|--------|-----------|-------------|
| Taryfikacja ubezpieczeń majątkowych | Addytywne modele punktowe (PZU, Warta, ERGO Hestia) | Alg. 1 — uproszczony GLM bez regresji |
| Ryzyko lokalizacyjne (ISOK, IMGW-PIB) | Strefy powodziowe A/B/C | Mapowanie `floodZone` w Alg. 2 |
| EN 13501-1 | Klasyfikacja ognioodporności materiałów | Uzasadnienie reguły `WOODEN_STRUCTURE` w Alg. 3 |
| KGP Statystyki Policji | Wskaźniki kradzieży per region | Uzasadnienie wagi 0.35 dla `theftRiskZone` |
| ISO 31000:2018 | Standard zarządzania ryzykiem | Trójpoziomowy model identyfikacja–ocena–klasyfikacja |
| Swiss Re natcat | Dominacja ryzyka powodziowego w Polsce | Uzasadnienie wagi 0.30 dla `floodZone` |
| Zasada ostrożności (reasekuracja) | `recommended = max()` | Logika agregacji — zawsze najwyższy wynik |

---

## Rekomendacja dla Repozytorium

**Backend** (`sample-app/dotnet-api/`): Dodać endpoint `POST /api/risk/housing/evaluate` do `Program.cs`. Logikę algorytmów wydzielić do osobnych klas w katalogu `Housing/`. Nie modyfikować istniejącego `/risk-score`.

**Frontend** (`sample-app/angular-frontend/`): Nowy standalone component `HousingRiskComponent`. Osobny serwis `HousingRiskService`. Nowy typ `HousingRiskClass = 'low' | 'medium' | 'high' | 'critical'` w `housing-risk.types.ts` — nie rozszerzać istniejącego `RiskClass` (inna domena).

**Testy**: Vitest dla frontendu; xUnit dla backendu .NET. Każda tabela mapowania i każdy próg klasyfikacyjny musi mieć dedykowany test case.

**Kolejność implementacji**: Backend (modele → algorytmy → endpoint → testy) → Frontend (typy → serwis → testy → komponent → testy) → Dokumentacja.

---

## Następne Polecenie

```
/pdlc analyze
```