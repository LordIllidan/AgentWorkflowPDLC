using SampleRiskApi.Housing;
using Xunit;

namespace SampleRiskApiTests.Housing;

public class SpecialCaseRuleAlgorithmTests
{
    private static HousingEvaluationRequest Build(
        bool isVacant, bool isWoodenStructure, bool missingInspections, int insuredSumPLN)
        => new(0, 0, 1, SecurityLevel.None, 0,
            new LocationData(FloodZone.None, RiskZone.Low, RiskZone.Low, BuildingDensity.Rural),
            new SpecialFlagsData(isVacant, isWoodenStructure, missingInspections, insuredSumPLN));

    [Fact]
    public void T3_01_NoRules_Returns_Low()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(false, false, false, 300_000));
        Assert.Equal(HousingRiskLevel.Low, result.Classification);
        Assert.Empty(result.TriggeredRules);
        Assert.Equal(4, result.BlockedRules.Length);
    }

    [Fact]
    public void T3_02_MissingInspections_Returns_Medium()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(false, false, true, 300_000));
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
        Assert.Contains("MISSING_INSPECTIONS", result.TriggeredRules);
        Assert.Single(result.TriggeredRules);
    }

    [Fact]
    public void T3_03_HighInsuredSum_Over500k_Returns_Medium()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(false, false, false, 500_001));
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
        Assert.Contains("HIGH_INSURED_SUM", result.TriggeredRules);
    }

    [Fact]
    public void T3_04_InsuredSumExactly500k_Does_Not_Trigger()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(false, false, false, 500_000));
        Assert.Equal(HousingRiskLevel.Low, result.Classification);
        Assert.Empty(result.TriggeredRules);
    }

    [Fact]
    public void T3_05_Vacant_Returns_High()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(true, false, false, 0));
        Assert.Equal(HousingRiskLevel.High, result.Classification);
        Assert.Contains("VACANT_PROPERTY", result.TriggeredRules);
    }

    [Fact]
    public void T3_06_WoodenStructure_Returns_High()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(false, true, false, 0));
        Assert.Equal(HousingRiskLevel.High, result.Classification);
        Assert.Contains("WOODEN_STRUCTURE", result.TriggeredRules);
    }

    [Fact]
    public void T3_07_AllRules_Returns_High()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(true, true, true, 600_000));
        Assert.Equal(HousingRiskLevel.High, result.Classification);
        Assert.Equal(4, result.TriggeredRules.Length);
        Assert.Empty(result.BlockedRules);
    }

    [Fact]
    public void T3_08_MissingAndHighSum_Returns_Medium()
    {
        var result = SpecialCaseRuleAlgorithm.Evaluate(Build(false, false, true, 500_001));
        Assert.Equal(HousingRiskLevel.Medium, result.Classification);
        Assert.Contains("MISSING_INSPECTIONS", result.TriggeredRules);
        Assert.Contains("HIGH_INSURED_SUM", result.TriggeredRules);
        Assert.Equal(2, result.TriggeredRules.Length);
    }
}
