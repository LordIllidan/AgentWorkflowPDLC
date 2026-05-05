namespace SampleRiskApi.Housing;

public static class HousingRiskRecommender
{
    public static RecommendedResult Recommend(
        HousingRiskLevel pointBased,
        HousingRiskLevel weightBased,
        HousingRiskLevel ruleBased)
    {
        var levels = new[] { pointBased, weightBased, ruleBased };
        var max    = levels.Max();

        string rationale;

        if (max == HousingRiskLevel.Critical)
        {
            var name = pointBased  == HousingRiskLevel.Critical ? "punktowy"
                     : weightBased == HousingRiskLevel.Critical ? "wagowy"
                     : "regułowy";
            rationale = $"Algorytm {name} wskazuje ryzyko krytyczne.";
        }
        else if (levels.Distinct().Count() == 1)
        {
            rationale = $"Wszystkie algorytmy zgodne: {FormatLevel(max)}.";
        }
        else if (levels.Count(l => l == max) >= 2)
        {
            rationale = $"Dwa lub więcej algorytmów wskazuje: {FormatLevel(max)}.";
        }
        else
        {
            rationale = $"Rozbieżność algorytmów. Przyjęto najwyższy wynik: {FormatLevel(max)}.";
        }

        return new RecommendedResult(max, rationale);
    }

    private static string FormatLevel(HousingRiskLevel level) => level.ToString().ToLowerInvariant();
}
