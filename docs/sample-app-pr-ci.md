# Sample app — CI na pull request

## Cel

Workflow GitHub Actions uruchamia się przy PR-ach, które zmieniają kod w `sample-app/dotnet-api` albo `sample-app/angular-frontend`, żeby na GitHubie wykonać podstawową weryfikację (build, testy jednostkowe frontu) zamiast polegać wyłącznie na lokalnych workerach PDLC.

## Plik

- `.github/workflows/sample-app-ci.yml` — workflow **Sample app CI**

## Zachowanie

- Trigger: `pull_request` z filtrem ścieżek (tylko zmiany w katalogach sample app albo w samym pliku workflow).
- Job **changes** używa `dorny/paths-filter`, żeby uruchomić tylko te joby, które dotyczą faktycznie zmienionych aplikacji.
- **dotnet-api:** `dotnet restore`, `dotnet build` (Release) na `ubuntu-latest`, SDK 8.0.x. W projekcie nie ma osobnego projektu testów — brak kroku `dotnet test`.
- **angular-frontend:** osobne kroki `npm install`, `npm run build`, `npm run test:ci` (Vitest). Przy `CI=true` włączane są reportery **default**, **github-actions** (adnotacje przy pliku/linii w UI Actions) oraz **JUnit** do pliku `reports/vitest-junit.xml`.
- Po każdym runie testów artefakt **`vitest-junit-<run_id>`** jest wgrywany (`if: always()`), także przy niepowodzeniu — można pobrać XML i zobaczyć pełną listę testów bez przewijania logu.
- Przy **failure** job dopisuje **Job summary** z podpowiedzią, który krok padł (install / build / test) i typowymi przyczynami (TestBed, `HttpClient` w testach).
- W `vitest.config.ts` ustawiono `pool: 'forks'` (osobne pliki spec w osobnych procesach). W `src/test-setup.ts` jest globalny `afterEach` z `getTestBed().resetTestingModule()`, żeby kolejne `beforeEach` + `configureTestingModule` w tym samym pliku nie wywalały się na „already been instantiated”.

## Uwagi

- Zmiany wyłącznie w `sample-app/java-api` ten workflow nie obejmuje (świadomie: zakres zadania BE/FE jak w issue dotyczącym stacku .NET + Angular).
- Osobnych „testów architektury” (ArchUnit, depcruise itd.) w sample app nie skonfigurowano — workflow nie udaje ich obecności.

