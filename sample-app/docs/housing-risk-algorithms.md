# Algorytmy analizy ryzyka mieszkalnictwa

Trzy niezależne algorytmy oceniają ryzyko z różnych perspektyw. Każdy zwraca klasę ryzyka (`low | medium | high | critical`). Rekomendacja końcowa to maksimum z trzech wyników (zasada ostrożności).

---

## ALG-1: PropertyScoreAlgorithm — punktowy

Sumuje kary i bonusy przypisane cechom fizycznym nieruchomości.

### Formuła

```
score = agePenalty(buildingAge)
      + floorFactor(floor)
      − securityDiscount(securityLevel)
      + claimsPenalty(claimsLast5Years)
```

### Tablice składowych

| Składowa | Warunek | Wartość |
|---|---|---|
| `agePenalty` | wiek < 10 lat | 0 |
| | 10–30 lat | +10 |
| | 31–50 lat | +20 |
| | > 50 lat | +35 |
| `floorFactor` | piętro ≤ 1 | +10 |
| | piętro 2–4 | +5 |
| | piętro 5–9 | 0 |
| | piętro ≥ 10 | −5 |
| `securityDiscount` | `none` | 0 |
| | `basic` | −5 |
| | `medium` | −10 |
| | `high` | −20 |
| `claimsPenalty` | 0 szkód | 0 |
| | 1 szkoda | +20 |
| | 2 szkody | +40 |
| | ≥ 3 szkody | +60 |

### Klasyfikacja

| Score | Klasa |
|---|---|
| < 30 (w tym ujemne) | `low` |
| 30–59 | `medium` |
| 60–89 | `high` |
| ≥ 90 | `critical` |

### Przykład

Dane: wiek=35, piętro=3, pięter=10, zabezpieczenia=medium, szkody=1.

```
agePenalty(35)           = 20
floorFactor(3)           = 5
securityDiscount(medium) = 10
claimsPenalty(1)         = 20

score = 20 + 5 − 10 + 20 = 35  →  medium
```

---

## ALG-2: LocationWeightAlgorithm — wagowy

Ważona suma znormalizowanych wskaźników zagrożeń lokalizacyjnych. Wynik 0.0–1.0.

### Formuła i wagi

```
score = 0.30 × flood_score(floodZone)
      + 0.20 × fire_score(fireRiskZone)
      + 0.35 × theft_score(theftRiskZone)
      + 0.15 × density_score(buildingDensity)
```

| Wymiar | Waga | Uzasadnienie |
|---|---|---|
| Powódź | 0.30 | Najwyższe szkody jednostkowe; mitygacja poza kontrolą właściciela (Swiss Re natcat) |
| Pożar | 0.20 | Wysokie szkody; częściowo pokryte przez zabezpieczenia (ALG-1) |
| Kradzież | 0.35 | Najwyższa częstotliwość szkód w PL wg KGP |
| Gęstość zabudowy | 0.15 | Korelat kradzieży i pożaru |

### Mapowania stref

| Parametr | Wartość | Score |
|---|---|---|
| `floodZone` | `A` | 1.0 |
| | `B` | 0.6 |
| | `C` | 0.3 |
| | `none` | 0.0 |
| `fireRiskZone` / `theftRiskZone` | `high` | 1.0 |
| | `medium` | 0.5 |
| | `low` | 0.1 |
| `buildingDensity` | `urban` | 0.8 |
| | `suburban` | 0.4 |
| | `rural` | 0.1 |

### Klasyfikacja

| Score | Klasa |
|---|---|
| < 0.25 | `low` |
| 0.25–0.499 | `medium` |
| 0.50–0.749 | `high` |
| ≥ 0.75 | `critical` |

### Przykład

Dane: `floodZone=B`, `fireRiskZone=low`, `theftRiskZone=high`, `buildingDensity=urban`.

```
flood:   0.30 × 0.6 = 0.18
fire:    0.20 × 0.1 = 0.02
theft:   0.35 × 1.0 = 0.35
density: 0.15 × 0.8 = 0.12

score = 0.67  →  high
```

---

## ALG-3: SpecialCaseRuleAlgorithm — regułowy

Cztery reguły binarne. Każda wyzwolona reguła wymusza minimalny poziom ryzyka. Wynik = maksimum z wymuszonych minimów.

### Reguły

| ID | Warunek | Minimalny poziom | Uzasadnienie |
|---|---|---|---|
| `VACANT_PROPERTY` | `isVacant = true` | `high` | Brak nadzoru; wyższe ryzyko wandalizmu i pożaru |
| `WOODEN_STRUCTURE` | `isWoodenStructure = true` | `high` | Wyższy współczynnik rozprzestrzeniania ognia (EN 13501-1) |
| `MISSING_INSPECTIONS` | `missingInspections = true` | `medium` | Nieznany stan instalacji elektrycznej/gazowej |
| `HIGH_INSURED_SUM` | `insuredSumPLN > 500 000` | `medium` | Wysoka ekspozycja finansowa |

**Uwaga:** Warunek `HIGH_INSURED_SUM` jest ścisły (`>`). Wartość dokładnie 500 000 PLN **nie wyzwala** reguły.

### Pseudokod

```
level = 'low'
triggered = []

if isVacant:           triggered += ['VACANT_PROPERTY'];     level = max(level, 'high')
if isWoodenStructure:  triggered += ['WOODEN_STRUCTURE'];    level = max(level, 'high')
if missingInspections: triggered += ['MISSING_INSPECTIONS']; level = max(level, 'medium')
if insuredSumPLN > 500000: triggered += ['HIGH_INSURED_SUM']; level = max(level, 'medium')

return { classification: level, triggeredRules: triggered, blockedRules: ALL - triggered }

Porządek: low < medium < high < critical
```

### Przykład

Dane: `isVacant=false`, `isWoodenStructure=false`, `missingInspections=true`, `insuredSumPLN=450 000`.

```
VACANT_PROPERTY:     false           →  nie wyzwolona
WOODEN_STRUCTURE:    false           →  nie wyzwolona
MISSING_INSPECTIONS: true            →  wyzwolona → minimum: medium
HIGH_INSURED_SUM:    450 000 ≤ 500 000 → nie wyzwolona

triggered = [MISSING_INSPECTIONS]
classification = medium
```

---

## Logika rekomendacji

```
recommended = max(ALG-1, ALG-2, ALG-3)   // porządek: low < medium < high < critical
```

| Sytuacja | Tekst rationale |
|---|---|
| Którykolwiek zwraca `critical` | `"Algorytm {punktowy/wagowy/regułowy} wskazuje ryzyko krytyczne."` |
| Wszystkie trzy równe | `"Wszystkie algorytmy zgodne: {klasa}."` |
| Dwa lub więcej wskazuje max | `"Dwa lub więcej algorytmów wskazuje: {klasa}."` |
| Wszystkie różne | `"Rozbieżność algorytmów. Przyjęto najwyższy wynik: {klasa}."` |

### Przykład

ALG-1 = `medium`, ALG-2 = `high`, ALG-3 = `medium` → recommended = `high`.
Rationale: `"Dwa lub więcej algorytmów wskazuje: high."`

---

## API

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

Dozwolone wartości: `securityLevel`: `none|basic|medium|high` · `floodZone`: `A|B|C|none` · `fireRiskZone`/`theftRiskZone`: `high|medium|low` · `buildingDensity`: `urban|suburban|rural`.

### Response `200 OK`

```json
{
  "algorithms": {
    "pointBased": {
      "score": 35,
      "classification": "medium",
      "breakdown": { "agePenalty": 20, "floorFactor": 5, "securityDiscount": 10, "claimsPenalty": 20 }
    },
    "weightBased": {
      "score": 0.67,
      "classification": "high",
      "breakdown": { "flood": 0.18, "fire": 0.02, "theft": 0.35, "density": 0.12 }
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

## Uruchomienie

```bash
# Backend (.NET 8)
cd sample-app/dotnet-api
dotnet run
# → http://localhost:8080

# Frontend (Angular 20)
cd sample-app/angular-frontend
npm install
npm start
# → http://localhost:4200

# Testy backendu
dotnet test sample-app/dotnet-api-tests/

# Testy frontendu
cd sample-app/angular-frontend
npm test
```
