namespace SampleRiskApi.Housing;

public static class LocationWeightAlgorithm
{
    private const double WFlood   = 0.30;
    private const double WFire    = 0.20;
    private const double WTheft   = 0.35;
    private const double WDensity = 0.15;

    public static WeightBasedResult Evaluate(HousingEvaluationRequest req)
    {
        double floodScore = req.Location.FloodZone switch
        {
            FloodZone.A    => 1.0,
            FloodZone.B    => 0.6,
            FloodZone.C    => 0.3,
            FloodZone.None => 0.0,
            _              => 0.0
        };

        double fireScore = req.Location.FireRiskZone switch
        {
            RiskZone.High   => 1.0,
            RiskZone.Medium => 0.5,
            RiskZone.Low    => 0.1,
            _               => 0.0
        };

        double theftScore = req.Location.TheftRiskZone switch
        {
            RiskZone.High   => 1.0,
            RiskZone.Medium => 0.5,
            RiskZone.Low    => 0.1,
            _               => 0.0
        };

        double densityScore = req.Location.BuildingDensity switch
        {
            BuildingDensity.Urban    => 0.8,
            BuildingDensity.Suburban => 0.4,
            BuildingDensity.Rural    => 0.1,
            _                        => 0.0
        };

        double flood   = Math.Round(WFlood   * floodScore,   4);
        double fire    = Math.Round(WFire    * fireScore,    4);
        double theft   = Math.Round(WTheft   * theftScore,   4);
        double density = Math.Round(WDensity * densityScore, 4);
        double total   = Math.Round(flood + fire + theft + density, 2);

        var classification = total switch
        {
            < 0.25              => HousingRiskLevel.Low,
            >= 0.25 and < 0.50  => HousingRiskLevel.Medium,
            >= 0.50 and < 0.75  => HousingRiskLevel.High,
            _                   => HousingRiskLevel.Critical
        };

        return new WeightBasedResult(
            total,
            classification,
            new WeightBasedBreakdown(
                Math.Round(flood,   2),
                Math.Round(fire,    2),
                Math.Round(theft,   2),
                Math.Round(density, 2)));
    }
}
