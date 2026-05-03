using SampleRiskApi.Housing;
using Xunit;

namespace SampleRiskApiTests.Housing;

public class PropertyScoreAlgorithmTests
{
    private static HousingEvaluationRequest Build(
        int buildingAge = 0, int floor = 0, int totalFloors = 1,
        SecurityLevel securityLevel = SecurityLevel.None,
        int claimsLast5Years = 0)
        => new(buildingAge, floor, totalFloors, securityLevel, claimsLast5Years,
            new LocationData(FloodZone.None, RiskZone.Low, RiskZone.Low, BuildingDensity.Rural),
            new SpecialFlagsData(false, false, false, 0));

    [Fact]
    public void T1_01_StandardCase_Returns_Medium()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(35, 3, 10, SecurityLevel.Medium, 1));
        // 20 + 5 - 10 + 20 = 35
        Assert.Equal(35, result.Score);
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
        Assert.Equal(20, result.Breakdown.AgePenalty);
        Assert.Equal(5, result.Breakdown.FloorFactor);
        Assert.Equal(10, result.Breakdown.SecurityDiscount);
        Assert.Equal(20, result.Breakdown.ClaimsPenalty);
    }

    [Fact]
    public void T1_02_HighAgeAndClaims_Returns_Critical()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(55, 0, 5, SecurityLevel.None, 3));
        // 35 + 10 - 0 + 60 = 105
        Assert.Equal(105, result.Score);
        Assert.Equal(HousingRiskLevel.Critical, result.Classification);
    }

    [Fact]
    public void T1_03_NewBuildingHighFloor_Returns_Low_Negative()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(5, 12, 20, SecurityLevel.High, 0));
        // 0 + (-5) - 20 + 0 = -25
        Assert.Equal(-25, result.Score);
        Assert.Equal(HousingRiskLevel.Low, result.Classification);
    }

    [Fact]
    public void T1_04_ScoreBelow30_Returns_Low()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(35, 3, 10, SecurityLevel.None, 0));
        // 20 + 5 - 0 + 0 = 25
        Assert.Equal(25, result.Score);
        Assert.Equal(HousingRiskLevel.Low, result.Classification);
    }

    [Fact]
    public void T1_05_Score30_Returns_Medium_Boundary()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(35, 0, 5, SecurityLevel.None, 0));
        // 20 + 10 - 0 + 0 = 30
        Assert.Equal(30, result.Score);
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
    }

    [Fact]
    public void T1_06_ScoreIn30To60_Returns_Medium()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(55, 8, 10, SecurityLevel.None, 1));
        // 35 + 0 - 0 + 20 = 55
        Assert.Equal(55, result.Score);
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
    }

    [Fact]
    public void T1_07_Score60_Returns_High_Boundary()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(55, 0, 5, SecurityLevel.Basic, 1));
        // 35 + 10 - 5 + 20 = 60
        Assert.Equal(60, result.Score);
        Assert.Equal(HousingRiskLevel.High, result.Classification);
    }

    [Fact]
    public void T1_08_ScoreIn60To90_Returns_High()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(55, 0, 5, SecurityLevel.None, 2));
        // 35 + 10 - 0 + 40 = 85
        Assert.Equal(85, result.Score);
        Assert.Equal(HousingRiskLevel.High, result.Classification);
    }

    [Fact]
    public void T1_09_Score90_Returns_Critical_Boundary()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(55, 10, 10, SecurityLevel.None, 3));
        // 35 + (-5) - 0 + 60 = 90
        Assert.Equal(90, result.Score);
        Assert.Equal(HousingRiskLevel.Critical, result.Classification);
    }

    [Fact]
    public void T1_10_NewBuildingGroundFloor_Returns_Low()
    {
        var result = PropertyScoreAlgorithm.Evaluate(Build(0, 0, 1, SecurityLevel.Basic, 0));
        // 0 + 10 - 5 + 0 = 5
        Assert.Equal(5, result.Score);
        Assert.Equal(HousingRiskLevel.Low, result.Classification);
    }
}
