# PDLC Research Agent

Issue: #24 [PDLC] Formularz dla zgłsozenia  szkody do polisy X
Branch: agent/pdlc-issue-24-pdlc-formularz-dla-zg-sozenia-szkody-do-polisy-x
Run: https://github.com/LordIllidan/AgentWorkflowPDLC/actions/runs/25689829200
Agent: research-agent
Model: sonnet
Autonomy mode: semi-auto

## Agent Output

Status: READY

# Research Agent — Issue #24
## Formularz zgłoszenia szkody do polisy mieszkaniowej X

---

## Streszczenie wykonawcze

Funkcjonalność polega na udostępnieniu publicznego formularza (dostępnego bez logowania), przez który klient podaje numer polisy mieszkaniowej, swoje dane, preferowaną formę kontaktu i opis szkody. Zgłoszenie trafia do bazy danych, a następnie wiadomość z podstawowymi informacjami o szkodzie jest wysyłana na wspólny kanał Teams lub Slack widoczny dla agentów. Jeśli żaden agent nie „przyjmie" zgłoszenia w ciągu 1 godziny, system generuje przypomnienie; po 2 godzinach niepodjęcia eskalacja trafia do managera.

Architektura obejmuje trzy niezależne obszary:

1. **Frontend** — Angular 20, standalone components (insurance-x), nowa leniwie ładowana trasa `/claims/new`.
2. **Backend** — .NET (localhost:5125), nowy endpoint REST `POST /api/claims`, background job do monitorowania stanu zgłoszeń (`IHostedService` lub Hangfire).
3. **Integracje** — outbound webhook do Teams (Adaptive Card) i/lub Slack (Block Kit); wspólna abstrakcja `INotificationChannel`.

Badanie opiera się na kontekście repozytorium (CLAUDE.md, pliki projektu) i wiedzy domeny ubezpieczeń mieszkaniowych. Założenia nieweryfikowalne oznaczono jawnie w tabeli poniżej.

---

## Założenia domeny i ograniczenia

| # | Założenie | Podstawa | Weryfikacja wymagana |
|---|-----------|----------|----------------------|
| A1 | Formularz dostępny **bez uwierzytelnienia** — klient zna tylko numer polisy | Opis issue | Tak — czy numer polisy wystarczy do identyfikacji, czy potrzebny dodatkowy PIN/PESEL? |
| A2 | „Agenci" = użytkownicy insurance-x z rolą `coordinator` lub dedykowaną rolą `agent` (nie zdefiniowana wprost w issue) | CLAUDE.md: role coordinator | Tak — które role widzą kanał i mogą przyjąć zgłoszenie |
| A3 | „Wspólny kanał na Teams lub Slack" — jedno z dwóch, nie oba jednocześnie; wybór przez zmienną środowiskową | Wzorzec integracji | Tak — czy wymagana obsługa obu jednocześnie? |
| A4 | „Przyjęcie" zgłoszenia przez agenta = kliknięcie przycisku w UI lub akcji w karcie Teams/Slack; zmiana statusu w bazie na `IN_PROGRESS` | Standardowy wzorzec kolejkowania | Tak — czy akcja przyjęcia jest w UI aplikacji czy bezpośrednio w Teams/Slack? |
| A5 | Progi 1h i 2h liczone od `createdAt` w bazie, nie od wysłania wiadomości na kanał | Logika biznesowa | Tak |
| A6 | Manager — pojedyncza osoba lub rola; powiadomienie przez kanał managera lub DM | Issue nie precyzuje | Tak — jak zidentyfikować managera (rola w systemie, stała konfiguracja?) |
| A7 | Backend .NET ma dostęp do bazy danych (EF Core lub Dapper) i background processing | CLAUDE.md: .NET backend :5125 | Tak — czy Hangfire/Quartz już skonfigurowany, czy trzeba dodać? |
| A8 | Dane osobowe podlegają RODO; podstawa prawna: **wykonanie umowy** (polisa, art. 6(1)(b)) lub **uzasadniony interes** (art. 6(1)(f)) | Standard RODO | **OBOWIĄZKOWA weryfikacja przez DPO przed implementacją** |

---

## Rodziny rozwiązań

### Rodzina 1 — Prosta kolejka z polling job (rekomendowana dla MVP)

**Opis:** Backend .NET zapisuje zgłoszenie, wysyła webhook do Teams/Slack, uruchamia jednorazowy `IHostedService` z pętlą pollingu co 5 minut sprawdzającą nowe/stare zgłoszenia. Bez zewnętrznych zależności.

**Pseudokod logiki eskalacji:**

```
every 5 minutes:
  claims = db.Claims
    .Where(c => c.Status == PENDING AND c.IsDeleted == false)
    .ToList()

  foreach claim in claims:
    age = now - claim.CreatedAt

    if age >= 2h AND claim.ManagerNotifiedAt IS NULL:
      send_manager_notification(claim)
      claim.ManagerNotifiedAt = now

    else if age >= 1h AND claim.ReminderSentAt IS NULL:
      send_reminder_to_channel(claim)
      claim.ReminderSentAt = now

  db.SaveChanges()
```

**Dane wejściowe dla joba:** tabela `Claims`, kolumny `Status`, `CreatedAt`, `ReminderSentAt`, `ManagerNotifiedAt`, `AssignedAt`.

**Dane wyjściowe:** aktualizacja `ReminderSentAt` / `ManagerNotifiedAt` w DB; wywołanie `INotificationChannel.SendReminderAsync()` / `INotificationChannel.NotifyManagerAsync()`.

**Mapping klas ryzyka eskalacji:**

| Stan zgłoszenia | Wiek | Akcja |
|-----------------|------|-------|
| `PENDING` | 0–59 min | brak akcji |
| `PENDING` | 60–119 min | wyślij przypomnienie do kanału |
| `PENDING` | ≥ 120 min | wyślij notyfikację do managera |
| `IN_PROGRESS` / `CLOSED` | dowolny | pomiń |

**Zalety:** prosta implementacja, bez zewnętrznych zależności, pełna testowalność przez mockowanie `TimeProvider`.
**Wady:** opóźnienie do 5 minut od progu; nieefektywny przy dużym wolumenie (>1000 zgłoszeń/dobę).

---

### Rodzina 2 — Scheduled jobs z Hangfire

**Opis:** Hangfire (lub Quartz.NET) jako biblioteka background jobs z własną tabelą w DB. Job `CheckClaimEscalationsJob` uruchamiany co minutę, idempotentny dzięki `[DisableConcurrentExecution]`.

**Pseudokod (C#-level):**

```csharp
[DisableConcurrentExecution(timeoutInSeconds: 60)]
public class CheckClaimEscalationsJob
{
    public async Task ExecuteAsync(CancellationToken ct)
    {
        var now = _timeProvider.GetUtcNow();
        var pendingClaims = await _db.Claims
            .Where(c => c.Status == ClaimStatus.Pending && !c.IsDeleted)
            .ToListAsync(ct);

        foreach (var claim in pendingClaims)
        {
            var age = now - claim.CreatedAt;

            if (age >= TimeSpan.FromHours(2) && claim.ManagerNotifiedAt is null)
                await _notifier.NotifyManagerAsync(claim, ct);

            else if (age >= TimeSpan.FromHours(1) && claim.ReminderSentAt is null)
                await _notifier.SendChannelReminderAsync(claim, ct);
        }

        await _db.SaveChangesAsync(ct);
    }
}
```

**Dane wejściowe:** indeks `idx_claims_status_created` na `(Status, CreatedAt) WHERE IsDeleted = FALSE`.

**Dane wyjściowe:** Hangfire dashboard z historią wykonań; retry log przy błędach webhook; aktualizacja DB jak wyżej.

**Mapping klas ryzyka:** identyczny jak Rodzina 1, ale precyzja do minuty.

**Zalety:** wbudowany retry, dashboard UI, historia jobów, precyzja do minuty.
**Wady:** dodatkowa zależność NuGet, wymaga tabeli `HangfireJobs` w DB, konfiguracja storage.
**Kiedy:** jeśli Hangfire już w projekcie lub planowane inne background jobs.

---

### Rodzina 3 — Event-driven z Outbox Pattern

**Opis:** Zapis zgłoszenia + zdarzenie `ClaimSubmitted` do tabeli outbox w jednej transakcji. Osobny worker przetwarza outbox i wysyła do Teams/Slack. Eskalacje jako zaplanowane zdarzenia (`ClaimReminderDue`, `ClaimManagerAlertDue`) z `ScheduledAt`.

**Schemat outbox:**

```sql
CREATE TABLE OutboxMessages (
    Id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    Type        VARCHAR(100) NOT NULL,
    Payload     JSONB        NOT NULL,
    ScheduledAt TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ProcessedAt TIMESTAMPTZ,
    Error       TEXT,
    RetryCount  INT          NOT NULL DEFAULT 0
);

-- Przy zapisie zgłoszenia (1 transakcja):
INSERT INTO Claims (...) VALUES (...);
INSERT INTO OutboxMessages (Type, Payload, ScheduledAt)
  VALUES ('ClaimSubmitted',   '{"claimId": "..."}', NOW()),
         ('ClaimReminderDue', '{"claimId": "..."}', NOW() + INTERVAL '1 hour'),
         ('ClaimManagerAlert','{"claimId": "..."}', NOW() + INTERVAL '2 hours');
```

**Dane wejściowe:** tabela `OutboxMessages` filtrowana `WHERE ProcessedAt IS NULL AND ScheduledAt <= NOW()`.

**Dane wyjściowe:** wiadomości na kanał Teams/Slack; `ProcessedAt` zaktualizowany po sukcesie; `Error` + `RetryCount` przy niepowodzeniu. Gwarancja at-least-once delivery.

**Mapping klas ryzyka:** zdarzenia zaplanowane z góry; brak pollingu tabeli `Claims` — skalowalne.

**Zalety:** gwarancja dostarczenia przy awarii serwera, skalowalne, separacja odpowiedzialności.
**Wady:** złożona implementacja, wymaga dedykowanego workera outbox, migracja dwóch tabel.
**Kiedy:** architektura event-driven już przyjęta w projekcie lub wymagana wysoka niezawodność.

---

## Model danych wejściowych i wyjściowych

### Dane wejściowe formularza (frontend → API)

```typescript
interface ClaimSubmitRequest {
  policyNumber:           string;  // format: "POL-YYYY-XXXXXX", walidacja regex
  firstName:              string;  // max 100 znaków
  lastName:               string;  // max 100 znaków
  contactPhone?:          string;  // opcjonalne, format E.164 lub lokalny PL
  contactEmail?:          string;  // opcjonalne, RFC 5322
  preferredContactMethod: 'phone' | 'email';
  damageDescription:      string;  // min 20, max 2000 znaków
  damageDate?:            string;  // ISO 8601, opcjonalne
  consentGiven:           boolean; // RODO — checkbox obowiązkowy
}
```

**Walidacje backendu (poza frontendem):**
- `policyNumber` musi pasować do formatu; opcjonalna weryfikacja w `PolicyDB` w tle (bez ujawniania wyniku)
- `preferredContactMethod = 'phone'` wymaga `contactPhone`; `'email'` wymaga `contactEmail`
- `consentGiven = false` → HTTP 422 `{ error: "CONSENT_REQUIRED" }`

### Schemat bazy danych

```sql
CREATE TABLE Claims (
    Id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    PolicyNumber      VARCHAR(50)  NOT NULL,
    FirstName         VARCHAR(100) NOT NULL,
    LastName          VARCHAR(100) NOT NULL,
    ContactPhone      VARCHAR(30),
    ContactEmail      VARCHAR(254),
    PreferredContact  VARCHAR(10)  NOT NULL CHECK (PreferredContact IN ('phone','email')),
    DamageDescription TEXT         NOT NULL,
    DamageDate        DATE,
    ConsentGiven      BOOLEAN      NOT NULL DEFAULT FALSE,
    Status            VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                                   CHECK (Status IN ('PENDING','IN_PROGRESS','CLOSED','CANCELLED')),
    CreatedAt         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    AssignedTo        VARCHAR(100),
    AssignedAt        TIMESTAMPTZ,
    ReminderSentAt    TIMESTAMPTZ,
    ManagerNotifiedAt TIMESTAMPTZ,
    ChannelMessageId  VARCHAR(200),  -- ID wiadomości w Teams/Slack (do aktualizacji karty)
    PolicyVerified    BOOLEAN      NOT NULL DEFAULT FALSE,
    IsDeleted         BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_claims_status_created
    ON Claims (Status, CreatedAt)
    WHERE IsDeleted = FALSE;
```

### Odpowiedź API po zapisie

```typescript
interface ClaimSubmitResponse {
  claimId:         string;  // UUID
  referenceNumber: string;  // "ZGL-2026-00042"
  message:         string;  // "Zgłoszenie przyjęte. Numer referencyjny: ZGL-2026-00042"
}
```

> Ujednolicona odpowiedź `201` niezależnie od istnienia polisy — zapobiega enumeracji polis (OWASP API3).

### Format powiadomienia Teams (Adaptive Card v1.5)

```json
{
  "type": "AdaptiveCard",
  "version": "1.5",
  "body": [
    { "type": "TextBlock", "text": "Nowe zgłoszenie szkody", "weight": "Bolder", "size": "Medium" },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Nr ref.",      "value": "ZGL-2026-00042" },
        { "title": "Nr polisy",    "value": "POL-2024-XXXXXX" },
        { "title": "Kontakt",      "value": "telefon" },
        { "title": "Zgłoszono",    "value": "2026-05-11 14:32 UTC" },
        { "title": "Opis (skrót)", "value": "Zalanie łazienki — pęknięta rura..." }
      ]
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "Przyjmij zgłoszenie",
      "url": "https://insurance-x.internal/claims/ZGL-2026-00042/assign"
    }
  ]
}
```

> Karta **nie zawiera** imienia/nazwiska klienta — minimalizacja PII zgodna z art. 5(1)(c) RODO.

### Format powiadomienia Slack (Block Kit)

```json
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Nowe zgłoszenie szkody*\nNr ref: `ZGL-2026-00042` | Polisa: `POL-2024-XXXXXX`\nKontakt: telefon | Zgłoszono: 2026-05-11 14:32 UTC\n> Zalanie łazienki — pęknięta rura..."
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": { "type": "plain_text", "text": "Przyjmij zgłoszenie" },
          "url": "https://insurance-x.internal/claims/ZGL-2026-00042/assign",
          "style": "primary"
        }
      ]
    }
  ]
}
```

---

## Przepływ systemu

```
Klient              Frontend (Angular)       Backend (.NET)         Kanał (Teams/Slack)
  |                        |                       |                       |
  |-- wypełnia formularz ->|                       |                       |
  |                        |-- POST /api/claims -->|                       |
  |                        |                       |-- walidacja           |
  |                        |                       |-- zapis do DB         |
  |                        |                       |-- webhook ----------->|
  |                        |<-- 201 {claimId} -----|                       |
  |<-- "Przyjęto ZGL-..." -|                       |                       |
  |                                                |                       |
  |                                    [t+1h, Status=PENDING]              |
  |                                                |-- REMINDER ---------->|
  |                                                |                       |
  |                                    [t+2h, Status=PENDING]              |
  |                                                |-- ESKALACJA MANAGER ->|
  |                                                                         |
                         Agent klika "Przyjmij" (UI lub karta)
  |                        |-- PATCH /api/claims/{id}/assign -->|           |
  |                        |                       |-- Status=IN_PROGRESS   |
  |                        |                       |-- aktualizuj kartę --> |
```

---

## Ograniczenia repozytorium i technologiczne

### Frontend (insurance-x — Angular 20)

- Formularz jako **standalone component** w nowej leniwo ładowanej trasie `/claims/new` bez `authGuard` — trasa publiczna.
- Walidacja przez Angular `ReactiveFormsModule`: `Validators.required`, `Validators.email`, custom `policyNumberValidator`.
- Stan formularza: Angular Signals (`signal`, `computed`) — bez RxJS `BehaviorSubject`.
- Proxy `/api` → `http://localhost:5125` już skonfigurowany — bez zmian w proxy.
- Design: IBM Plex Sans 14px dla pól, IBM Plex Mono dla nr referencyjnego, `navy-800` dla przycisku submit, `shadow-sm` dla karty formularza, border-radius max `radius-xl` (16px).

### Backend (.NET)

Nowe endpointy:
- `POST /api/claims` — przyjęcie zgłoszenia (publiczny)
- `PATCH /api/claims/{id}/assign` — przyjęcie przez agenta (auth wymagane)
- `GET /api/claims/{id}` — podgląd szczegółów (auth wymagane)

Wymagania implementacyjne:
- `TimeProvider` (.NET 8+) jako abstrakcja czasu — warunek konieczny dla testowalności logiki 1h/2h
- `IHttpClientFactory` z named client `"NotificationChannel"`, timeout 5s, retry 2x (Polly)
- EF Core migracja: nowa tabela `Claims`

### Bezpieczeństwo formularza publicznego

| Zagrożenie | Mitigacja |
|------------|-----------|
| Brute-force po nr polisy | Rate limiting: 10 req/IP/godzinę na `POST /api/claims` (ASP.NET Core `RateLimiter`) |
| Spam / fałszywe zgłoszenia | reCAPTCHA v3 lub hCaptcha (token w żądaniu) — opcjonalne na MVP |
| Enumeracja polis | Stała odpowiedź `201` niezależnie od istnienia polisy |
| XSS | Angular sanitizuje domyślnie; EF Core parametryzowane zapytania |
| PII w logach | `[SensitiveData]` attribute lub maska dla `FirstName`, `LastName`, `ContactPhone`, `ContactEmail` |

---

## Przypadki brzegowe i przypadki testowe

| ID | Scenariusz | Oczekiwany wynik |
|----|-----------|------------------|
| E01 | Agent przyjmuje po 59 min | Brak przypomnienia, brak eskalacji |
| E02 | Agent przyjmuje po 61 min (przypomnienie wysłane) | Status `IN_PROGRESS`, brak kolejnych powiadomień; karta Teams zaktualizowana |
| E03 | Dwóch agentów klika "Przyjmij" jednocześnie | EF Core rowversion — drugi dostaje HTTP 409; zgłoszenie przypisane do pierwszego |
| E04 | Webhook Teams niedostępny | Retry 2x, log błędu; zgłoszenie zapisane — nie rollbackować transakcji DB |
| E05 | Agent przyjmuje po 1h59min; job odpala się 2 min później | Job widzi `AssignedAt != null`, pomija eskalację managera |
| E06 | 11 zgłoszeń z jednego IP w ciągu godziny | HTTP 429 na 11. próbie |
| E07 | `policyNumber` nieistniejący w PolicyDB | HTTP 201 (nie ujawniamy); zapis z `PolicyVerified=false` |
| E08 | `consentGiven = false` | HTTP 422 `{ error: "CONSENT_REQUIRED" }` |
| E09 | Job odpala się dwa razy równolegle (restart serwera) | Idempotentność przez `ReminderSentAt IS NULL`; opcjonalnie `SELECT FOR UPDATE` |
| E10 | Zgłoszenie otwarte >24h bez podjęcia | Niezdefiniowane w issue — do doprecyzowania w Requirements |

---

## Rekomendacja dla repozytorium

**Wariant MVP (zalecany):**

1. **Frontend:** nowy standalone component `ClaimFormComponent` w `insurance-x/src/app/features/claims/` z trasą `/claims/new` bez auth guard. Formularz reaktywny Angular z inline walidacją.

2. **Backend:** nowy `ClaimsController` w istniejącym projekcie .NET. Persist przez EF Core (nowa migracja). Background job jako `IHostedService` polling co 5 minut — bez Hangfire na MVP.

3. **Integracja:** `INotificationChannel` z implementacjami `TeamsNotificationChannel` i `SlackNotificationChannel`; wybór przez `NOTIFICATION_CHANNEL_TYPE` env var.

4. **Bezpieczeństwo:** `RateLimiter` middleware ASP.NET Core (.NET 7+), enumeracja polis zablokowana przez jednolitą odpowiedź 201, minimalizacja PII w kartach Teams/Slack.

**Uzasadnienie polling over Hangfire:** Hangfire wymaga storage i konfiguracji. `IHostedService` wystarczy przy małym wolumenie; opóźnienie do 5 minut akceptowalne dla procesu obsługi szkód. Hangfire rekomendowany gdy projekt już go zawiera lub wymagany dashboard retry.

**Pliki do stworzenia / zmodyfikowania:**

```
insurance-x/src/app/features/claims/
├── claims.routes.ts
├── claim-form/
│   ├── claim-form.component.ts
│   ├── claim-form.component.html
│   └── claim-form.component.spec.ts
└── services/
    └── claims.service.ts

[Backend .NET]
Controllers/ClaimsController.cs
Models/Claim.cs
Services/ClaimsEscalationService.cs        ← IHostedService polling
Services/Notifications/INotificationChannel.cs
Services/Notifications/TeamsNotificationChannel.cs
Services/Notifications/SlackNotificationChannel.cs
Migrations/XXXX_AddClaimsTable.cs
```

---

## Następne polecenie

```
/pdlc analyze
```