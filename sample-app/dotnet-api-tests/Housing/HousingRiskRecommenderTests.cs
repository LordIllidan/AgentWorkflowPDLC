using SampleRiskApi.Housing;
using Xunit;

namespace SampleRiskApiTests.Housing;

public class HousingRiskRecommenderTests
{
    private static readonly HousingRiskLevel Low      = HousingRiskLevel.Low;
    private static readonly HousingRiskLevel Medium   = HousingRiskLevel.Medium;
    private static readonly HousingRiskLevel High     = HousingRiskLevel.High;
    private static readonly HousingRiskLevel Critical = HousingRiskLevel.Critical;

    [Fact]
    public void TR_01_OneHigherThanOthers_Returns_High_Divergence()
    {
        // Only 1 of 3 returns High — triggers "Rozbieżność" not "Dwa lub więcej"
        var result = HousingRiskRecommender.Recommend(Medium, High, Medium);
        Assert.Equal(High, result.Classification);
        Assert.Contains("Rozbieżność", result.Rationale);
    }

    [Fact]
    public void TR_02_AllLow_Returns_Low_AllAgree()
    {
        var result = HousingRiskRecommender.Recommend(Low, Low, Low);
        Assert.Equal(Low, result.Classification);
        Assert.Contains("Wszystkie algorytmy zgodne", result.Rationale);
        Assert.Contains("low", result.Rationale);
    }

    [Fact]
    public void TR_03_AllDifferent_Returns_Highest()
    {
        var result = HousingRiskRecommender.Recommend(Low, Medium, High);
        Assert.Equal(High, result.Classification);
        Assert.Contains("Rozbieżność", result.Rationale);
    }

    [Fact]
    public void TR_04_PointBasedCritical_Returns_Critical_Rationale()
    {
        var result = HousingRiskRecommender.Recommend(Critical, Low, Low);
        Assert.Equal(Critical, result.Classification);
        Assert.Contains("punktowy", result.Rationale);
        Assert.Contains("krytyczne", result.Rationale);
    }

    [Fact]
    public void TR_05_AllMedium_Returns_Medium_AllAgree()
    {
        var result = HousingRiskRecommender.Recommend(Medium, Medium, Medium);
        Assert.Equal(Medium, result.Classification);
        Assert.Contains("Wszystkie algorytmy zgodne", result.Rationale);
    }

    [Fact]
    public void TR_06_WeightBasedCritical_Returns_Critical_Rationale()
    {
        var result = HousingRiskRecommender.Recommend(Low, Critical, Low);
        Assert.Equal(Critical, result.Classification);
        Assert.Contains("wagowy", result.Rationale);
    }

    [Fact]
    public void TR_07_TwoCritical_Returns_Critical_PointBased_First()
    {
        var result = HousingRiskRecommender.Recommend(Critical, Critical, Low);
        Assert.Equal(Critical, result.Classification);
        Assert.Contains("punktowy", result.Rationale);
    }

    [Fact]
    public void TR_08_OneHigher_Returns_Divergence_Rationale()
    {
        var result = HousingRiskRecommender.Recommend(Low, Medium, Low);
        Assert.Equal(Medium, result.Classification);
        Assert.Contains("Rozbieżność", result.Rationale);
    }
}
