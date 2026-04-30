var builder = WebApplication.CreateBuilder(args);
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
        >= 14 => "regulated",
        >= 10 => "high",
        >= 6 => "medium",
        _ => "low"
    };

    return Results.Json(new RiskResponse(score, riskClass));
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

