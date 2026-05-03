namespace SampleRiskApi.Housing;

public static class PropertyScoreAlgorithm
{
    public static PointBasedResult Evaluate(HousingEvaluationRequest req)
    {
        int agePenalty = req.BuildingAge switch
        {
            < 10                  => 0,
            >= 10 and <= 30       => 10,
            >= 31 and <= 50       => 20,
            _                     => 35
        };

        int floorFactor = req.Floor switch
        {
            <= 1                  => 10,
            >= 2 and <= 4         => 5,
            >= 5 and <= 9         => 0,
            _                     => -5
        };

        int securityDiscount = req.SecurityLevel switch
        {
            SecurityLevel.None    => 0,
            SecurityLevel.Basic   => 5,
            SecurityLevel.Medium  => 10,
            SecurityLevel.High    => 20,
            _                     => 0
        };

        int claimsPenalty = req.ClaimsLast5Years switch
        {
            0   => 0,
            1   => 20,
            2   => 40,
            _   => 60
        };

        int score = agePenalty + floorFactor - securityDiscount + claimsPenalty;

        var classification = score switch
        {
            < 30              => HousingRiskLevel.Low,
            >= 30 and < 60    => HousingRiskLevel.Medium,
            >= 60 and < 90    => HousingRiskLevel.High,
            _                 => HousingRiskLevel.Critical
        };

        return new PointBasedResult(
            score,
            classification,
            new PointBasedBreakdown(agePenalty, floorFactor, securityDiscount, claimsPenalty));
    }
}
