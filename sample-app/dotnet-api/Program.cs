using SampleRiskApi.Housing;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.ConfigureHttpJsonOptions(opts =>
    opts.SerializerOptions.Converters.Add(
        new JsonStringEnumConverter(System.Text.Json.JsonNamingPolicy.CamelCase)));

var app = builder.Build();

app.MapGet("/", () => Results.Json(new
{
    service = "sample-risk-dotnet-api",
    purpose = "Dummy backend for AgentWorkflowPDLC tests"
}));

app.MapPost("/risk-score", (RiskRequest request) =>
{
    var score = request.UserImpact + request.TechnicalComplexity + request.Data + request.Security + request.Reversibility + request.RequirementsUncertainty;
    var riskClass = score switch
    {
        >= 90 => "critical",
        >= 14 => "regulated",
        >= 10 => "high",
        >= 6 => "medium",
        _ => "low"
    };

    return Results.Json(new RiskResponse(score, riskClass));
});

app.MapPost("/api/risk/housing/evaluate", (HousingEvaluationRequest req) =>
{
    var errors = new Dictionary<string, string>();

    if (req.BuildingAge < 0)
        errors["buildingAge"] = "buildingAge must be >= 0";
    if (req.Floor < 0)
        errors["floor"] = "floor must be >= 0";
    if (req.TotalFloors < 1)
        errors["totalFloors"] = "totalFloors must be >= 1";
    if (req.Floor > req.TotalFloors)
        errors["floor"] = $"floor ({req.Floor}) cannot exceed totalFloors ({req.TotalFloors})";
    if (req.ClaimsLast5Years < 0)
        errors["claimsLast5Years"] = "claimsLast5Years must be >= 0";
    if (req.SpecialFlags.InsuredSumPLN < 0)
        errors["insuredSumPLN"] = "insuredSumPLN must be >= 0";

    if (errors.Count > 0)
        return Results.Json(new { error = "Validation failed", fields = errors }, statusCode: 400);

    var pointBased  = PropertyScoreAlgorithm.Evaluate(req);
    var weightBased = LocationWeightAlgorithm.Evaluate(req);
    var ruleBased   = SpecialCaseRuleAlgorithm.Evaluate(req);
    var recommended = HousingRiskRecommender.Recommend(
        pointBased.Classification,
        weightBased.Classification,
        ruleBased.Classification);

    return Results.Json(new HousingEvaluationResponse(
        new AlgorithmsResult(pointBased, weightBased, ruleBased),
        recommended));
});

app.Run();

public sealed record RiskRequest(
    int UserImpact,
    int TechnicalComplexity,
    int Data,
    int Security,
    int Reversibility,
    int RequirementsUncertainty);

public sealed record RiskResponse(int Score, string RiskClass);

