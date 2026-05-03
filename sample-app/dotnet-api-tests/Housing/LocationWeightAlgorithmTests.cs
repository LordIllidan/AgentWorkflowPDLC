using SampleRiskApi.Housing;
using Xunit;

namespace SampleRiskApiTests.Housing;

public class LocationWeightAlgorithmTests
{
    private static HousingEvaluationRequest Build(
        FloodZone floodZone, RiskZone fireRiskZone, RiskZone theftRiskZone, BuildingDensity density)
        => new(0, 0, 1, SecurityLevel.None, 0,
            new LocationData(floodZone, fireRiskZone, theftRiskZone, density),
            new SpecialFlagsData(false, false, false, 0));

    [Fact]
    public void T2_01_FloodB_FireLow_TheftHigh_Urban_Returns_High()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.B, RiskZone.Low, RiskZone.High, BuildingDensity.Urban));
        // 0.18 + 0.02 + 0.35 + 0.12 = 0.67
        Assert.Equal(0.67, result.Score, 2);
        Assert.Equal(HousingRiskLevel.High, result.Classification);
    }

    [Fact]
    public void T2_02_AllLow_Returns_Low()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.None, RiskZone.Low, RiskZone.Low, BuildingDensity.Rural));
        // 0 + 0.02 + 0.035 + 0.015 = 0.07
        Assert.Equal(0.07, result.Score, 2);
        Assert.Equal(HousingRiskLevel.Low, result.Classification);
    }

    [Fact]
    public void T2_03_AllHigh_Returns_Critical()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.A, RiskZone.High, RiskZone.High, BuildingDensity.Urban));
        // 0.30 + 0.20 + 0.35 + 0.12 = 0.97
        Assert.Equal(0.97, result.Score, 2);
        Assert.Equal(HousingRiskLevel.Critical, result.Classification);
    }

    [Fact]
    public void T2_04_Mixed_Returns_Medium()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.C, RiskZone.Medium, RiskZone.Medium, BuildingDensity.Suburban));
        // 0.09 + 0.10 + 0.175 + 0.06 ≈ 0.43
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
        Assert.True(result.Score >= 0.25 && result.Score < 0.50);
    }

    [Fact]
    public void T2_05_Score025_Returns_Medium_Boundary()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.B, RiskZone.Low, RiskZone.Low, BuildingDensity.Rural));
        // 0.18 + 0.02 + 0.035 + 0.015 = 0.25
        Assert.Equal(0.25, result.Score, 2);
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
    }

    [Fact]
    public void T2_06_ScoreAbove050_Returns_High()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.B, RiskZone.Low, RiskZone.High, BuildingDensity.Rural));
        // 0.18 + 0.02 + 0.35 + 0.015 = 0.565 → 0.57
        Assert.True(result.Score >= 0.50 && result.Score < 0.75);
        Assert.Equal(HousingRiskLevel.High, result.Classification);
    }

    [Fact]
    public void T2_07_ScoreAbove075_Returns_Critical()
    {
        var result = LocationWeightAlgorithm.Evaluate(
            Build(FloodZone.A, RiskZone.High, RiskZone.High, BuildingDensity.Rural));
        // 0.30 + 0.20 + 0.35 + 0.015 = 0.865 → 0.87
        Assert.True(result.Score >= 0.75);
        Assert.Equal(HousingRiskLevel.Critical, result.Classification);
    }
}
