namespace SampleRiskApi.Housing;

public enum HousingRiskLevel { Low, Medium, High, Critical }
public enum SecurityLevel    { None, Basic, Medium, High }
public enum FloodZone        { A, B, C, None }
public enum RiskZone         { High, Medium, Low }
public enum BuildingDensity  { Urban, Suburban, Rural }

public sealed record LocationData(
    FloodZone       FloodZone,
    RiskZone        FireRiskZone,
    RiskZone        TheftRiskZone,
    BuildingDensity BuildingDensity);

public sealed record SpecialFlagsData(
    bool IsVacant,
    bool IsWoodenStructure,
    bool MissingInspections,
    int  InsuredSumPLN);

public sealed record HousingEvaluationRequest(
    int              BuildingAge,
    int              Floor,
    int              TotalFloors,
    SecurityLevel    SecurityLevel,
    int              ClaimsLast5Years,
    LocationData     Location,
    SpecialFlagsData SpecialFlags);

public sealed record PointBasedBreakdown(
    int AgePenalty, int FloorFactor, int SecurityDiscount, int ClaimsPenalty);

public sealed record WeightBasedBreakdown(
    double Flood, double Fire, double Theft, double Density);

public sealed record PointBasedResult(
    int Score, HousingRiskLevel Classification, PointBasedBreakdown Breakdown);

public sealed record WeightBasedResult(
    double Score, HousingRiskLevel Classification, WeightBasedBreakdown Breakdown);

public sealed record RuleBasedResult(
    HousingRiskLevel Classification,
    string[]         TriggeredRules,
    string[]         BlockedRules);

public sealed record AlgorithmsResult(
    PointBasedResult  PointBased,
    WeightBasedResult WeightBased,
    RuleBasedResult   RuleBased);

public sealed record RecommendedResult(
    HousingRiskLevel Classification,
    string           Rationale);

public sealed record HousingEvaluationResponse(
    AlgorithmsResult  Algorithms,
    RecommendedResult Recommended);
