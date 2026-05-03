export type HousingRiskClass = 'low' | 'medium' | 'high' | 'critical';
export type SecurityLevel    = 'none' | 'basic' | 'medium' | 'high';
export type FloodZone        = 'A' | 'B' | 'C' | 'none';
export type RiskZoneLevel    = 'high' | 'medium' | 'low';
export type BuildingDensity  = 'urban' | 'suburban' | 'rural';

export interface HousingLocationData {
  floodZone:       FloodZone;
  fireRiskZone:    RiskZoneLevel;
  theftRiskZone:   RiskZoneLevel;
  buildingDensity: BuildingDensity;
}

export interface HousingSpecialFlags {
  isVacant:           boolean;
  isWoodenStructure:  boolean;
  missingInspections: boolean;
  insuredSumPLN:      number;
}

export interface HousingEvaluationRequest {
  buildingAge:      number;
  floor:            number;
  totalFloors:      number;
  securityLevel:    SecurityLevel;
  claimsLast5Years: number;
  location:         HousingLocationData;
  specialFlags:     HousingSpecialFlags;
}

export interface PointBasedBreakdown {
  agePenalty:      number;
  floorFactor:     number;
  securityDiscount: number;
  claimsPenalty:   number;
}

export interface WeightBasedBreakdown {
  flood:   number;
  fire:    number;
  theft:   number;
  density: number;
}

export interface PointBasedResult {
  score:          number;
  classification: HousingRiskClass;
  breakdown:      PointBasedBreakdown;
}

export interface WeightBasedResult {
  score:          number;
  classification: HousingRiskClass;
  breakdown:      WeightBasedBreakdown;
}

export interface RuleBasedResult {
  classification: HousingRiskClass;
  triggeredRules: string[];
  blockedRules:   string[];
}

export interface AlgorithmsResult {
  pointBased:  PointBasedResult;
  weightBased: WeightBasedResult;
  ruleBased:   RuleBasedResult;
}

export interface RecommendedResult {
  classification: HousingRiskClass;
  rationale:      string;
}

export interface HousingEvaluationResponse {
  algorithms:  AlgorithmsResult;
  recommended: RecommendedResult;
}
