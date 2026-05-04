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
  templateUrl: './housing-risk.component.html',
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
