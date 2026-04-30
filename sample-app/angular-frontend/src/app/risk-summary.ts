export type RiskClass = 'low' | 'medium' | 'high' | 'regulated';

export interface RiskSummary {
  readonly title: string;
  readonly score: number;
  readonly riskClass: RiskClass;
}

export function classifyRisk(score: number): RiskClass {
  if (score >= 14) {
    return 'regulated';
  }

  if (score >= 10) {
    return 'high';
  }

  if (score >= 6) {
    return 'medium';
  }

  return 'low';
}

