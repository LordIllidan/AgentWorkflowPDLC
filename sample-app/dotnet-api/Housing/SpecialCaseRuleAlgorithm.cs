namespace SampleRiskApi.Housing;

public static class SpecialCaseRuleAlgorithm
{
    private static readonly string[] AllRules =
        ["VACANT_PROPERTY", "WOODEN_STRUCTURE", "MISSING_INSPECTIONS", "HIGH_INSURED_SUM"];

    public static RuleBasedResult Evaluate(HousingEvaluationRequest req)
    {
        var triggered = new List<string>();
        var level     = HousingRiskLevel.Low;

        if (req.SpecialFlags.IsVacant)
        {
            triggered.Add("VACANT_PROPERTY");
            if (level < HousingRiskLevel.High) level = HousingRiskLevel.High;
        }
        if (req.SpecialFlags.IsWoodenStructure)
        {
            triggered.Add("WOODEN_STRUCTURE");
            if (level < HousingRiskLevel.High) level = HousingRiskLevel.High;
        }
        if (req.SpecialFlags.MissingInspections)
        {
            triggered.Add("MISSING_INSPECTIONS");
            if (level < HousingRiskLevel.Medium) level = HousingRiskLevel.Medium;
        }
        if (req.SpecialFlags.InsuredSumPLN > 500_000)
        {
            triggered.Add("HIGH_INSURED_SUM");
            if (level < HousingRiskLevel.Medium) level = HousingRiskLevel.Medium;
        }

        var blocked = AllRules.Except(triggered).ToArray();
        return new RuleBasedResult(level, [.. triggered], blocked);
    }
}
