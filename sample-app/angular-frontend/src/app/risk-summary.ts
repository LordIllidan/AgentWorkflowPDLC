export type RiskClass = 'low' | 'medium' | 'high' | 'regulated' | 'critical';

export interface RiskSummary {
  readonly title: string;
  readonly score: number;
  readonly riskClass: RiskClass;
}

export function classifyRisk(score: number): RiskClass {
  switch (true) {
    case score >= 90: return 'critical' satisfies RiskClass;
    case score >= 14: return 'regulated' satisfies RiskClass;
    case score >= 10: return 'high' satisfies RiskClass;
    case score >= 6:  return 'medium' satisfies RiskClass;
    default:          return 'low' satisfies RiskClass;
  }
}

