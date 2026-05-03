import { Component, inject, signal, WritableSignal } from '@angular/core';
import { UpperCasePipe, DecimalPipe } from '@angular/common';
import { HousingRiskService } from './housing-risk.service';
import {
  HousingRiskClass,
  HousingEvaluationResponse,
  SecurityLevel,
  FloodZone,
  RiskZoneLevel,
  BuildingDensity,
} from './housing-risk.types';

@Component({
  selector: 'app-housing-risk',
  standalone: true,
  imports: [UpperCasePipe, DecimalPipe],
  template: `
    <section class="housing-section">
      <h2 class="section-title">Ocena ryzyka mieszkalnictwa</h2>

      <div class="form-grid">
        <fieldset class="form-group">
          <legend>Cechy nieruchomości</legend>
          <label>Wiek budynku (lata)
            <input type="number" min="0" [value]="buildingAge()" (input)="setNum(buildingAge, $event)">
          </label>
          <label>Piętro lokalu
            <input type="number" min="0" [value]="floor()" (input)="setNum(floor, $event)">
          </label>
          <label>Łączna liczba pięter
            <input type="number" min="1" [value]="totalFloors()" (input)="setNum(totalFloors, $event)">
          </label>
          <label>Poziom zabezpieczeń
            <select [value]="securityLevel()" (change)="setVal(securityLevel, $event)">
              <option value="none">Brak</option>
              <option value="basic">Podstawowy</option>
              <option value="medium">Średni</option>
              <option value="high">Wysoki</option>
            </select>
          </label>
          <label>Szkody w ostatnich 5 latach
            <input type="number" min="0" [value]="claimsLast5Years()" (input)="setNum(claimsLast5Years, $event)">
          </label>
        </fieldset>

        <fieldset class="form-group">
          <legend>Lokalizacja i ekspozycja</legend>
          <label>Strefa powodziowa
            <select [value]="floodZone()" (change)="setVal(floodZone, $event)">
              <option value="none">Brak</option>
              <option value="A">A — bezpośrednie zagrożenie</option>
              <option value="B">B — strefa pośrednia</option>
              <option value="C">C — strefa potencjalna</option>
            </select>
          </label>
          <label>Strefa ryzyka pożarowego
            <select [value]="fireRiskZone()" (change)="setVal(fireRiskZone, $event)">
              <option value="low">Niskie</option>
              <option value="medium">Średnie</option>
              <option value="high">Wysokie</option>
            </select>
          </label>
          <label>Strefa ryzyka kradzieży
            <select [value]="theftRiskZone()" (change)="setVal(theftRiskZone, $event)">
              <option value="low">Niskie</option>
              <option value="medium">Średnie</option>
              <option value="high">Wysokie</option>
            </select>
          </label>
          <label>Gęstość zabudowy
            <select [value]="buildingDensity()" (change)="setVal(buildingDensity, $event)">
              <option value="rural">Wiejska</option>
              <option value="suburban">Podmiejska</option>
              <option value="urban">Miejska</option>
            </select>
          </label>
        </fieldset>

        <fieldset class="form-group">
          <legend>Przypadki specjalne</legend>
          <label class="checkbox-label">
            <input type="checkbox" [checked]="isVacant()" (change)="setBool(isVacant, $event)">
            Lokal pustostan
          </label>
          <label class="checkbox-label">
            <input type="checkbox" [checked]="isWoodenStructure()" (change)="setBool(isWoodenStructure, $event)">
            Budynek drewniany
          </label>
          <label class="checkbox-label">
            <input type="checkbox" [checked]="missingInspections()" (change)="setBool(missingInspections, $event)">
            Brak przeglądów technicznych
          </label>
          <label>Suma ubezpieczenia (PLN)
            <input type="number" min="0" [value]="insuredSumPLN()" (input)="setNum(insuredSumPLN, $event)">
          </label>
        </fieldset>
      </div>

      <button class="evaluate-btn" (click)="evaluate()" [disabled]="isLoading()">
        {{ isLoading() ? 'Obliczanie...' : 'Oblicz ryzyko' }}
      </button>

      @if (errorMessage()) {
        <p class="error-msg">{{ errorMessage() }}</p>
      }

      @if (result(); as res) {
        <div class="results-grid">
          <div class="result-card">
            <p class="card-label">ALG-1 Punktowy</p>
            <p class="card-score">Wynik: <span class="mono">{{ res.algorithms.pointBased.score }}</span></p>
            <span class="badge" [style]="badgeStyle(res.algorithms.pointBased.classification)">
              {{ res.algorithms.pointBased.classification | uppercase }}
            </span>
            <div class="breakdown">
              <span>Wiek: {{ res.algorithms.pointBased.breakdown.agePenalty }}</span>
              <span>Piętro: {{ res.algorithms.pointBased.breakdown.floorFactor }}</span>
              <span>Zabezp.: −{{ res.algorithms.pointBased.breakdown.securityDiscount }}</span>
              <span>Szkody: {{ res.algorithms.pointBased.breakdown.claimsPenalty }}</span>
            </div>
          </div>

          <div class="result-card">
            <p class="card-label">ALG-2 Wagowy</p>
            <p class="card-score">Wynik: <span class="mono">{{ res.algorithms.weightBased.score | number:'1.2-2' }}</span></p>
            <span class="badge" [style]="badgeStyle(res.algorithms.weightBased.classification)">
              {{ res.algorithms.weightBased.classification | uppercase }}
            </span>
            <div class="breakdown">
              <span>Powódź: {{ res.algorithms.weightBased.breakdown.flood | number:'1.2-2' }}</span>
              <span>Pożar: {{ res.algorithms.weightBased.breakdown.fire | number:'1.2-2' }}</span>
              <span>Kradzież: {{ res.algorithms.weightBased.breakdown.theft | number:'1.2-2' }}</span>
              <span>Gęstość: {{ res.algorithms.weightBased.breakdown.density | number:'1.2-2' }}</span>
            </div>
          </div>

          <div class="result-card">
            <p class="card-label">ALG-3 Regułowy</p>
            <span class="badge" [style]="badgeStyle(res.algorithms.ruleBased.classification)">
              {{ res.algorithms.ruleBased.classification | uppercase }}
            </span>
            @if (res.algorithms.ruleBased.triggeredRules.length > 0) {
              <div class="rules">
                <p class="rules-label">Wyzwolone reguły:</p>
                @for (rule of res.algorithms.ruleBased.triggeredRules; track rule) {
                  <span class="rule-tag">{{ rule }}</span>
                }
              </div>
            } @else {
              <p class="no-rules">Brak wyzwolonych reguł</p>
            }
          </div>

          <div class="result-card recommendation-card">
            <p class="card-label">★ Rekomendacja</p>
            <span class="badge badge-lg" [style]="badgeStyle(res.recommended.classification)">
              {{ res.recommended.classification | uppercase }}
            </span>
            <p class="rationale">{{ res.recommended.rationale }}</p>
          </div>
        </div>
      }
    </section>
  `,
  styles: [`
    .housing-section {
      font-family: "IBM Plex Sans", sans-serif;
      padding: 28px;
      background: oklch(97% 0.006 250);
      min-height: 100vh;
    }

    .section-title {
      font-size: 22px;
      font-weight: 700;
      margin: 0 0 20px;
      color: #172033;
    }

    .form-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 20px;
      margin-bottom: 20px;
    }

    fieldset.form-group {
      border: 1px solid #d9e1ef;
      border-radius: 12px;
      padding: 16px;
      background: white;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    legend {
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: #5a6a8a;
      padding: 0 4px;
    }

    label {
      display: flex;
      flex-direction: column;
      gap: 4px;
      font-size: 13px;
      font-weight: 500;
      color: #172033;
    }

    .checkbox-label {
      flex-direction: row;
      align-items: center;
      gap: 8px;
    }

    input[type="number"], select {
      border: 1px solid #b8c4d8;
      border-radius: 8px;
      padding: 8px 10px;
      font: inherit;
      font-size: 13px;
      max-width: 200px;
    }

    input[type="checkbox"] {
      width: 16px;
      height: 16px;
    }

    .evaluate-btn {
      background: oklch(35% 0.12 250);
      color: white;
      border: none;
      border-radius: 10px;
      padding: 12px 28px;
      font: inherit;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      margin-bottom: 20px;
    }

    .evaluate-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    .error-msg {
      color: oklch(50% 0.2 18);
      background: oklch(95% 0.05 18);
      border: 1px solid oklch(80% 0.1 18);
      border-radius: 8px;
      padding: 12px 16px;
      margin-bottom: 20px;
    }

    .results-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 16px;
    }

    .result-card {
      background: white;
      border: 1px solid #d9e1ef;
      border-radius: 12px;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .recommendation-card {
      border-color: oklch(70% 0.15 250);
      box-shadow: 0 2px 8px rgba(23, 32, 51, 0.08);
    }

    .card-label {
      margin: 0;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: #5a6a8a;
    }

    .card-score {
      margin: 0;
      font-size: 13px;
    }

    .mono {
      font-family: "IBM Plex Mono", monospace;
      font-weight: 600;
      font-size: 20px;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.05em;
      width: fit-content;
    }

    .badge::before {
      content: '';
      display: inline-block;
      width: 4px;
      height: 4px;
      border-radius: 50%;
      background: currentColor;
    }

    .badge-lg {
      font-size: 14px;
      padding: 6px 14px;
    }

    .breakdown {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      font-size: 11px;
      color: #5a6a8a;
    }

    .breakdown span {
      background: #f0f4fa;
      border-radius: 4px;
      padding: 2px 6px;
      font-family: "IBM Plex Mono", monospace;
    }

    .rules-label {
      margin: 0;
      font-size: 11px;
      font-weight: 600;
      color: #5a6a8a;
    }

    .rules {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .rule-tag {
      font-size: 11px;
      font-family: "IBM Plex Mono", monospace;
      background: #fff3e0;
      border: 1px solid #ffe0b2;
      border-radius: 4px;
      padding: 2px 6px;
      width: fit-content;
    }

    .no-rules {
      margin: 0;
      font-size: 12px;
      color: #5a6a8a;
      font-style: italic;
    }

    .rationale {
      margin: 0;
      font-size: 13px;
      color: #172033;
      line-height: 1.5;
    }
  `],
})
export class HousingRiskComponent {
  private readonly housingRiskService = inject(HousingRiskService);

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

  readonly result       = signal<HousingEvaluationResponse | null>(null);
  readonly isLoading    = signal(false);
  readonly errorMessage = signal<string | null>(null);

  protected setNum(sig: WritableSignal<number>, event: Event): void {
    sig.set(Number((event.target as HTMLInputElement).value));
  }

  protected setVal<T extends string>(sig: WritableSignal<T>, event: Event): void {
    sig.set((event.target as HTMLSelectElement).value as T);
  }

  protected setBool(sig: WritableSignal<boolean>, event: Event): void {
    sig.set((event.target as HTMLInputElement).checked);
  }

  protected badgeStyle(cls: HousingRiskClass): string {
    const hues: Record<HousingRiskClass, number> = { low: 145, medium: 75, high: 38, critical: 18 };
    const h = hues[cls];
    return `background: oklch(95% 0.16 ${h}); border: 1px solid oklch(80% 0.16 ${h}); color: oklch(45% 0.16 ${h});`;
  }

  evaluate(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);

    const req = {
      buildingAge:      this.buildingAge(),
      floor:            this.floor(),
      totalFloors:      this.totalFloors(),
      securityLevel:    this.securityLevel(),
      claimsLast5Years: this.claimsLast5Years(),
      location: {
        floodZone:       this.floodZone(),
        fireRiskZone:    this.fireRiskZone(),
        theftRiskZone:   this.theftRiskZone(),
        buildingDensity: this.buildingDensity(),
      },
      specialFlags: {
        isVacant:           this.isVacant(),
        isWoodenStructure:  this.isWoodenStructure(),
        missingInspections: this.missingInspections(),
        insuredSumPLN:      this.insuredSumPLN(),
      },
    };

    this.housingRiskService.evaluate(req).subscribe({
      next: (response) => {
        this.result.set(response);
        this.isLoading.set(false);
      },
      error: (err) => {
        this.isLoading.set(false);
        if (err.status === 400) {
          const fields = err.error?.fields ?? {};
          const msgs = Object.values(fields).join('; ');
          this.errorMessage.set(`Błąd walidacji: ${msgs}`);
        } else if (err.status === 0) {
          this.errorMessage.set('Nie można połączyć się z API.');
        } else {
          this.errorMessage.set('Błąd serwera. Spróbuj ponownie.');
        }
      },
    });
  }
}
