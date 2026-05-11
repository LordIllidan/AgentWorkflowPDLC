# PDLC Research Agent

Issue: #22 [PDLC] Generowanie rpaortów
Branch: agent/pdlc-issue-22-pdlc-generowanie-rpaort-w
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25688982471
Agent: research-agent
Model: sonnet
Autonomy mode: semi-auto

## Agent Output

Status: READY

---

# Artefakt Badań — Issue #22: Generowanie raportów sprzedanych polis

**Etap:** Research (10)
**Agent:** research-agent
**Data:** 2026-05-11
**Issue:** #22 — [PDLC] Generowanie rpaortów
**Repozytorium:** AgentWorkflowPDLC

---

## Streszczenie wykonawcze

Zadanie polega na wygenerowaniu raportu z listy sprzedanych polis pobierając dane z tabeli `Polisy`. Repozytorium `AgentWorkflowPDLC` jest środowiskiem demonstracyjnym pipeline'u PDLC — brak w nim istniejącej warstwy danych ubezpieczeniowych. Tabela `Polisy` musi zostać zaprojektowana i zasiana od zera.

Zakres badań obejmuje: (1) projekt schematu tabeli `Polisy` zgodny z RODO, (2) trzy rodziny rozwiązań technicznych generowania raportu, (3) mapowanie pól wejście/wyjście, (4) rekomendację dopasowaną do stack'u repozytorium (.NET + minimalna infrastruktura).

Kluczowe ustalenia:
- Tabela `Polisy` nie istnieje w repo — do implementacji od zera.
- Żaden istniejący endpoint API nie obsługuje raportowania.
- Stack repo: C#/.NET (workflow runner), brak frontendu dedykowanego raportom.
- Dane ubezpieczeniowych zawierają PII — projekt musi uwzględniać minimalizację danych w warstwie wyjściowej.
- „Sprzedana polisa" wymaga definicji statusu — proponowany status `Aktywna` lub `Wystawiona`.

---

## Założenia domenowe

| # | Założenie | Źródło | Ryzyko jeśli błędne |
|---|-----------|--------|---------------------|
| 1 | Tabela `Polisy` dotyczy polis majątkowych/życiowych w systemie demo, nie produkcji | Analiza repo — brak migracji DB | Niskie — środowisko demo |
| 2 | „Sprzedana polisa" = rekord z kolumną `Status IN ('Aktywna', 'Wystawiona')` | Standardowa terminologia ubezpieczeniowa | Średnie — status może mieć inną nazwę |
| 3 | Raport jest generowany na żądanie (pull), nie w harmonogramie push | Brak istniejącego schedulera w repo | Niskie — łatwa zmiana architektury |
| 4 | Zakres dat raportu jest parametrem wejściowym użytkownika | Wzorzec raportowania sprzedaży | Niskie |
| 5 | Raport nie modyfikuje danych — tylko odczyt | Natura raportu sprzedaży | Pewne |
| 6 | PESEL i inne dane jednoznacznie identyfikujące nie trafiają do wyjścia raportu | Zasada minimalizacji RODO Art. 5 ust. 1 lit. c | **Wysokie** — naruszenie RODO |
| 7 | Dostęp do raportu wymaga roli autoryzowanej (Manager / Underwriter) | Wzorzec z `insurance-x` role system | Średnie — repo demo może nie mieć auth |
| 8 | Waluta: PLN, format kwot: ###.### zł (IBM Plex Mono w UI) | Design spec repozytorium | Niskie |

---

## Proponowany schemat tabeli `Polisy`

```sql
CREATE TABLE Polisy (
    Id            INTEGER PRIMARY KEY AUTOINCREMENT,
    NumerPolisy   TEXT    NOT NULL UNIQUE,          -- np. POL-2024-000123
    Status        TEXT    NOT NULL DEFAULT 'Robocza', -- Robocza | Wystawiona | Aktywna | Wygasła | Anulowana
    TypPolisy     TEXT    NOT NULL,                 -- Majątkowa | Życiowa | Komunikacyjna | OC
    DataWystawienia DATE  NOT NULL,
    DataRozpoczecia DATE  NOT NULL,
    DataWygasniecia DATE  NOT NULL,
    SkladkaRoczna REAL    NOT NULL,                 -- PLN, brutto
    SumaUbezpieczenia REAL NOT NULL,               -- PLN
    -- PII minimalne — tylko do wewnętrznego powiązania, nie wychodzi w raporcie
    KlientId      INTEGER NOT NULL REFERENCES Klienci(Id),
    AgentId       INTEGER NOT NULL REFERENCES Agenci(Id),
    DataUtworzenia DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    DataModyfikacji DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indeks wydajnościowy dla raportów datowych
CREATE INDEX idx_polisy_status_data ON Polisy(Status, DataWystawienia);
CREATE INDEX idx_polisy_agent ON Polisy(AgentId, DataWystawienia);
```

Tabele pomocnicze (minimalne — seed tylko):

```sql
CREATE TABLE Klienci (
    Id       INTEGER PRIMARY KEY AUTOINCREMENT,
    Initials TEXT NOT NULL  -- np. "J.K." — nie pełne dane PII w demo
);

CREATE TABLE Agenci (
    Id    INTEGER PRIMARY KEY AUTOINCREMENT,
    Imie  TEXT NOT NULL,
    Nazwisko TEXT NOT NULL
);
```

---

## Rodziny rozwiązań — trzy kandydaty

### Rodzina A: JSON API + Tabela webowa (React/Angular)

**Opis:** Endpoint REST zwraca dane w formacie JSON; frontend renderuje tabelę z filtrowaniem i paginacją.

**Pseudokod — endpoint .NET Minimal API:**

```csharp
// GET /api/reports/polisy?od=2024-01-01&do=2024-12-31&status=Aktywna
app.MapGet("/api/reports/polisy", async (
    [FromQuery] DateOnly od,
    [FromQuery] DateOnly do,
    [FromQuery] string? status,
    PoliciesDbContext db) =>
{
    var query = db.Polisy
        .Where(p => p.DataWystawienia >= od && p.DataWystawienia <= do);

    if (status != null)
        query = query.Where(p => p.Status == status);

    var result = await query
        .OrderByDescending(p => p.DataWystawienia)
        .Select(p => new PolicjaRaportDto   // NIGDY SELECT * — jawne pola
        {
            NumerPolisy     = p.NumerPolisy,
            Status          = p.Status,
            TypPolisy       = p.TypPolisy,
            DataWystawienia = p.DataWystawienia,
            SkladkaRoczna   = p.SkladkaRoczna,
            Agent           = $"{p.Agent.Imie} {p.Agent.Nazwisko}"
            // KlientId NIE trafia do DTO
        })
        .ToListAsync();

    return Results.Ok(new {
        Wiersze       = result,
        Łącznie       = result.Count,
        SumaSkladek   = result.Sum(r => r.SkladkaRoczna),
        WygenerowanoO = DateTime.UtcNow
    });
});
```

**Dane wejściowe:**
- `od` (DateOnly, wymagane)
- `do` (DateOnly, wymagane)
- `status` (string, opcjonalne, default: wszystkie sprzedane = `Wystawiona,Aktywna`)
- `agentId` (int, opcjonalne — filtr po agencie)

**Dane wyjściowe:**
```json
{
  "wiersze": [
    {
      "numerPolisy": "POL-2024-000123",
      "status": "Aktywna",
      "typPolisy": "Majątkowa",
      "dataWystawienia": "2024-03-15",
      "skladkaRoczna": 1850.00,
      "agent": "Anna Kowalska"
    }
  ],
  "łącznie": 47,
  "sumaSkladek": 86450.00,
  "wygenerowanoO": "2026-05-11T10:30:00Z"
}
```

**Zalety:** Live data, filtrowalne, paginowalne. **Wady:** Wymaga frontendu.

---

### Rodzina B: Eksport CSV / XLSX

**Opis:** Endpoint zwraca plik do pobrania — CSV lub XLSX. Zero zależności frontendowych.

**Pseudokod — CSV endpoint .NET:**

```csharp
// GET /api/reports/polisy/csv?od=2024-01-01&do=2024-12-31
app.MapGet("/api/reports/polisy/csv", async (
    [FromQuery] DateOnly od,
    [FromQuery] DateOnly do,
    PoliciesDbContext db) =>
{
    var rows = await db.Polisy
        .Where(p => p.DataWystawienia >= od && p.DataWystawienia <= do
                 && (p.Status == "Aktywna" || p.Status == "Wystawiona"))
        .OrderBy(p => p.DataWystawienia)
        .Select(p => new PolicjaRaportDto { /* jak wyżej */ })
        .ToListAsync();

    var csv = new StringBuilder();
    csv.AppendLine("NumerPolisy;Status;Typ;DataWystawienia;SkladkaRoczna;Agent");

    foreach (var r in rows)
        csv.AppendLine($"{r.NumerPolisy};{r.Status};{r.TypPolisy};" +
                       $"{r.DataWystawienia:yyyy-MM-dd};{r.SkladkaRoczna:F2};{r.Agent}");

    var bytes = Encoding.UTF8.GetPreamble()  // BOM dla Excel
               .Concat(Encoding.UTF8.GetBytes(csv.ToString()))
               .ToArray();

    return Results.File(bytes, "text/csv",
        $"raport-polisy-{od:yyyyMMdd}-{do:yyyyMMdd}.csv");
});
```

**Formuła agregacji w wyjściowym pliku:**

```
SumaSkladek   = SUM(SkladkaRoczna)
LiczbaPolis   = COUNT(NumerPolisy)
SredniaScladka = SumaSkladek / LiczbaPolis
```

**Dane wejściowe:** `od`, `do`, opcjonalnie `format=csv|xlsx`

**Dane wyjściowe:** Plik do pobrania z nagłówkami kolumn i wierszem podsumowania.

**Zalety:** Działa bez frontendu, importowalny do Excel. **Wady:** Brak live view, statyczny snapshot.

---

### Rodzina C: PDF Raport (generowany serverside)

**Opis:** Endpoint generuje plik PDF ze sformatowanym raportem — logo, tabela, podsumowanie, stopka.

**Pseudokod — PDF z QuestPDF (.NET):**

```csharp
// GET /api/reports/polisy/pdf?od=2024-01-01&do=2024-12-31
app.MapGet("/api/reports/polisy/pdf", async (
    [FromQuery] DateOnly od,
    [FromQuery] DateOnly do,
    PoliciesDbContext db) =>
{
    var rows = await PobierzDaneRaportu(db, od, do);  // jak wcześniej

    var document = Document.Create(container =>
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(2, Unit.Centimetre);

            page.Header().Text($"Raport sprzedanych polis {od:dd.MM.yyyy}–{do:dd.MM.yyyy}")
                         .FontSize(16).Bold();

            page.Content().Table(table =>
            {
                table.ColumnsDefinition(cols => {
                    cols.RelativeColumn(2);  // NumerPolisy
                    cols.RelativeColumn(1);  // Status
                    cols.RelativeColumn(1);  // Typ
                    cols.RelativeColumn(1);  // Data
                    cols.RelativeColumn(1);  // Składka
                    cols.RelativeColumn(2);  // Agent
                });

                // Nagłówek
                foreach (var h in new[] {"Nr polisy","Status","Typ","Data","Składka PLN","Agent"})
                    table.Header().Cell().Text(h).Bold();

                // Wiersze danych
                foreach (var r in rows)
                {
                    table.Cell().Text(r.NumerPolisy);
                    table.Cell().Text(r.Status);
                    // ... pozostałe kolumny
                }

                // Wiersz podsumowania
                table.Footer().Cell().ColumnSpan(4).Text("SUMA:");
                table.Footer().Cell().Text($"{rows.Sum(r => r.SkladkaRoczna):N2} zł");
            });

            page.Footer().Text($"Wygenerowano: {DateTime.Now:dd.MM.yyyy HH:mm}  |  Strona {page.CurrentPageNumber}");
        });
    });

    var pdfBytes = document.GeneratePdf();
    return Results.File(pdfBytes, "application/pdf",
        $"raport-polisy-{od:yyyyMMdd}-{do:yyyyMMdd}.pdf");
});
```

**Pakiet:** `QuestPDF` (licencja MIT dla projektów open-source / Community dla demo).

**Dane wejściowe:** `od`, `do`, opcjonalnie `agentId`, `grupujPo=typ|agent`

**Dane wyjściowe:** Plik PDF gotowy do druku/archiwizacji, z tabelą i sumami.

**Zalety:** Prezentacyjny, archiwalny, niezależny od frontendu. **Wady:** Zależność zewnętrzna (QuestPDF), wolniejsze generowanie przy dużych zbiorach.

---

## Mapowanie danych wejście / wyjście

### Dane wejściowe (wszystkie rodziny)

| Parametr | Typ | Wymagany | Opis |
|----------|-----|----------|------|
| `od` | DateOnly | Tak | Początek zakresu dat wystawienia |
| `do` | DateOnly | Tak | Koniec zakresu dat wystawienia |
| `status` | string[] | Nie | Domyślnie `["Aktywna","Wystawiona"]` |
| `agentId` | int | Nie | Filtrowanie po konkretnym agencie |
| `typPolisy` | string | Nie | Filtrowanie po typie polisy |
| `format` | enum | Nie | `json|csv|xlsx|pdf` — dla rodziny B/C |

### Dane wyjściowe — DTO raportu

| Pole | Typ | Źródło | Uwagi RODO |
|------|-----|--------|------------|
| `NumerPolisy` | string | `Polisy.NumerPolisy` | Bezpieczne — pseudonimizacja |
| `Status` | string | `Polisy.Status` | Bezpieczne |
| `TypPolisy` | string | `Polisy.TypPolisy` | Bezpieczne |
| `DataWystawienia` | DateOnly | `Polisy.DataWystawienia` | Bezpieczne |
| `SkladkaRoczna` | decimal | `Polisy.SkladkaRoczna` | Bezpieczne — kwota bez kontekstu PII |
| `SumaUbezpieczenia` | decimal | `Polisy.SumaUbezpieczenia` | Bezpieczne |
| `Agent` | string | `Agenci.Imie + Nazwisko` | Dane pracownicze — nie PII klienta |
| ~~`KlientId`~~ | ~~int~~ | ~~wykluczone~~ | **Nie eksportować** |
| ~~`PESEL`~~ | ~~string~~ | ~~wykluczone~~ | **Absolutnie nie eksportować** |

### Mapowanie statusów na klasę raportu

| Status DB | Klasa raportowa | Wliczany do sprzedaży |
|-----------|-----------------|----------------------|
| `Robocza` | Draft | Nie |
| `Wystawiona` | Sprzedana | **Tak** |
| `Aktywna` | Sprzedana + Aktywna | **Tak** |
| `Wygasła` | Archiwum | Nie (chyba że raport historyczny) |
| `Anulowana` | Anulowana | Nie |

---

## Przypadki brzegowe

| # | Przypadek | Oczekiwane zachowanie |
|---|-----------|----------------------|
| 1 | Zakres dat `od > do` | HTTP 400 + komunikat walidacji |
| 2 | Brak polis w zakresie | HTTP 200 + pusta lista, sumy = 0 |
| 3 | `od` i `do` to ten sam dzień | Działa — raport dzienny |
| 4 | Zakres > 2 lata | HTTP 400 — limit zakresu dla wydajności |
| 5 | Polisa z `SkladkaRoczna = 0` | Wliczana, suma poprawna |
| 6 | Agent usunięty (FK = NULL) | Agent wyświetlany jako `(nieznany)` |
| 7 | CSV eksport — średnik w nazwie agenta | Pole otoczone cudzysłowem RFC 4180 |
| 8 | PDF > 500 wierszy | Paginacja automatyczna QuestPDF |
| 9 | Równoczesne żądania raportu | Stateless endpoint — bezpieczne |

---

## Dane seedowe do testów

```csharp
// Seed w DbContext.OnModelCreating lub migracji
modelBuilder.Entity<Polisa>().HasData(
    new Polisa { Id=1, NumerPolisy="POL-2024-000001", Status="Aktywna",
                 TypPolisy="Majątkowa", DataWystawienia=new DateOnly(2024,1,15),
                 DataRozpoczecia=new DateOnly(2024,2,1), DataWygasniecia=new DateOnly(2025,1,31),
                 SkladkaRoczna=2400m, SumaUbezpieczenia=500000m, KlientId=1, AgentId=1 },
    new Polisa { Id=2, NumerPolisy="POL-2024-000002", Status="Wystawiona",
                 TypPolisy="Komunikacyjna", DataWystawienia=new DateOnly(2024,3,10),
                 DataRozpoczecia=new DateOnly(2024,3,10), DataWygasniecia=new DateOnly(2025,3,9),
                 SkladkaRoczna=1850m, SumaUbezpieczenia=80000m, KlientId=2, AgentId=1 },
    new Polisa { Id=3, NumerPolisy="POL-2024-000003", Status="Anulowana",
                 TypPolisy="Życiowa", DataWystawienia=new DateOnly(2024,4,5),
                 DataRozpoczecia=new DateOnly(2024,4,5), DataWygasniecia=new DateOnly(2034,4,4),
                 SkladkaRoczna=3600m, SumaUbezpieczenia=200000m, KlientId=3, AgentId=2 }
);
```

---

## Referencje rynkowe i architektoniczne

| Źródło | Zastosowanie |
|--------|-------------|
| RODO Art. 5 ust. 1 lit. c — minimalizacja danych | Zasada projektowania DTO — tylko niezbędne pola |
| RFC 4180 — format CSV | Escaping pól z przecinkami/średnikami |
| QuestPDF Community License | Generowanie PDF w projektach open-source |
| .NET Minimal API docs — `Results.File()` | Streaming pliku z endpointu |
| EF Core — `Select()` projection | Zapobieganie `SELECT *` na poziomie ORM |
| OWASP ASVS 4.0 — V8 Data Protection | Kontrola ekspozycji PII w raportach |

---

## Struktura plików do implementacji

```
AgentWorkflowPDLC/
├── Migrations/
│   └── YYYYMMDD_AddPolisyTable.cs
├── Models/
│   ├── Polisa.cs
│   ├── Klient.cs
│   └── Agent.cs
├── Dtos/
│   └── PolicjaRaportDto.cs
├── Endpoints/
│   └── ReportsEndpoints.cs        ← MapGet x3 (json/csv/pdf)
├── Services/
│   └── PoliciesReportService.cs   ← logika zapytań, walidacja zakresu dat
└── Seed/
    └── PolicySeedData.cs
```

---

## Rekomendacja dla tego repozytorium

**Zalecana rodzina: B (CSV eksport) jako MVP, z opcją rozszerzenia do A (JSON API).**

Uzasadnienie:
1. Repozytorium jest środowiskiem demo PDLC — brak istniejącego frontendu raportowego.
2. CSV działa natychmiast bez UI — weryfikowalny w Excel przez każdą rolę.
3. Zero nowych zależności NuGet — `StringBuilder` + `Results.File()` to czysty .NET.
4. JSON API jako wariant B2 można dodać tym samym endpointem (`Accept: application/json` vs `text/csv`).
5. PDF (rodzina C) — odłożyć na sprint 2 jeśli pojawi się wymaganie archiwizacji.

**Nie rekomenduje się QuestPDF w sprint 1** — dodaje zależność zewnętrzną bez pewności że PDF jest wymagany.

---

## Następna komenda

```text
/pdlc analyze
```