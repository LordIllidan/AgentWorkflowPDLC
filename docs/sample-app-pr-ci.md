# Sample app — CI na pull request

## Cel

Workflow GitHub Actions uruchamia się przy PR-ach, które zmieniają kod w `sample-app/dotnet-api` albo `sample-app/angular-frontend`, żeby na GitHubie wykonać podstawową weryfikację (build, testy jednostkowe frontu) zamiast polegać wyłącznie na lokalnych workerach PDLC.

## Plik

- `.github/workflows/sample-app-ci.yml` — workflow **Sample app CI**

## Zachowanie

- Trigger: `pull_request` z filtrem ścieżek (tylko zmiany w katalogach sample app albo w samym pliku workflow).
- Job **changes** używa `dorny/paths-filter`, żeby uruchomić tylko te joby, które dotyczą faktycznie zmienionych aplikacji.
- **dotnet-api:** `dotnet restore`, `dotnet build` (Release) na `ubuntu-latest`, SDK 8.0.x. W projekcie nie ma osobnego projektu testów — brak kroku `dotnet test`.
- **angular-frontend:** `npm install`, `npm run build`, `npm run test` (Vitest). W `package.json` nie ma skryptu `lint` ani targetu `lint` w `angular.json` — osobny krok lintera nie jest uruchamiany, dopóki nie zostanie dodany w aplikacji.

## Uwagi

- Zmiany wyłącznie w `sample-app/java-api` ten workflow nie obejmuje (świadomie: zakres zadania BE/FE jak w issue dotyczącym stacku .NET + Angular).
- Osobnych „testów architektury” (ArchUnit, depcruise itd.) w sample app nie skonfigurowano — workflow nie udaje ich obecności.

