import { Component, computed, signal } from '@angular/core';
import { classifyRisk, RiskSummary } from './risk-summary';
import { HousingRiskComponent } from './housing/housing-risk.component';

@Component({
  selector: 'pdlc-root',
  standalone: true,
  imports: [HousingRiskComponent],
  templateUrl: './app.component.html',
  styles: [`
    :host {
      display: block;
      min-height: 100vh;
      font-family: "IBM Plex Sans", sans-serif;
      background: #f5f7fb;
      color: #172033;
    }

    .shell {
      display: grid;
      min-height: 100vh;
      place-items: center;
      padding: 24px;
    }

    .card {
      width: min(640px, 100%);
      border: 1px solid #d9e1ef;
      border-radius: 16px;
      background: white;
      padding: 32px;
      box-shadow: 0 12px 40px rgba(23, 32, 51, 0.08);
    }

    .eyebrow {
      margin: 0 0 8px;
      color: #3b5bdb;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    h1 {
      margin: 0 0 16px;
      font-size: 28px;
    }

    label {
      display: grid;
      gap: 8px;
      margin-top: 24px;
      font-weight: 600;
    }

    input {
      max-width: 160px;
      border: 1px solid #b8c4d8;
      border-radius: 10px;
      padding: 10px 12px;
      font: inherit;
    }

    .result {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: 24px;
      border-radius: 12px;
      background: #eef3ff;
      padding: 16px;
    }

    strong {
      font-family: "IBM Plex Mono", monospace;
      text-transform: uppercase;
    }
  `],
})
export class AppComponent {
  protected readonly score = signal(7);
  protected readonly summary = computed<RiskSummary>(() => ({
    title: 'PDLC sample task',
    score: this.score(),
    riskClass: classifyRisk(this.score()),
  }));

  protected setScore(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.score.set(Number(input.value));
  }
}

