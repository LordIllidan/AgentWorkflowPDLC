import { appendFile, readFile } from "node:fs/promises";

const stageCommands = [
  "/pdlc research",
  "/pdlc analyze",
  "/pdlc risk",
  "/pdlc architecture",
  "/pdlc plan",
];

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function isPullRequestIssue(issue) {
  return Boolean(issue?.pull_request);
}

function startsWithAny(value, prefixes) {
  const normalized = (value ?? "").trim().toLowerCase();
  return prefixes.some((prefix) => normalized.startsWith(prefix));
}

function containsCommand(value, command) {
  return (value ?? "").toLowerCase().includes(command);
}

function routeEvent(eventName, event) {
  const route = {
    status: false,
    analysis: false,
    stage: false,
    deterministicCoding: false,
    localCoding: false,
    reviewFix: false,
    reason: "No route matched.",
  };

  if (eventName === "repository_dispatch" && event.action === "pdlc_issue_created") {
    route.analysis = true;
    route.reason = "Research-created issue dispatch should run analysis.";
    return route;
  }

  if (eventName === "issues") {
    if (isPullRequestIssue(event.issue)) {
      route.reason = "Issue event belongs to a pull request.";
      return route;
    }

    route.status = true;
    route.analysis = true;
    route.reason = "Normal issue lifecycle event should refresh status and analysis.";
    return route;
  }

  if (eventName === "issue_comment") {
    const body = event.comment?.body ?? "";

    if (isPullRequestIssue(event.issue)) {
      if (containsCommand(body, "/fix-review")) {
        route.reviewFix = true;
        route.reason = "PR comment requested review fix.";
      } else {
        route.reason = "PR comment did not request review fix.";
      }
      return route;
    }

    if (startsWithAny(body, stageCommands)) {
      route.stage = true;
      route.reason = "Issue comment requested a PDLC stage agent.";
      return route;
    }

    if (body.trim().toLowerCase().startsWith("/approve ai-coding")) {
      route.localCoding = true;
      route.reason = "Issue comment approved local Claude Code implementation.";
      return route;
    }

    if (body.trim().toLowerCase().startsWith("/approve analysis")) {
      route.deterministicCoding = true;
      route.reason = "Issue comment approved deterministic coding.";
      return route;
    }

    route.reason = "Issue comment did not match a PDLC command.";
    return route;
  }

  if (eventName === "pull_request_review_comment") {
    if (containsCommand(event.comment?.body, "/fix-review")) {
      route.reviewFix = true;
      route.reason = "Inline PR review comment requested review fix.";
    } else {
      route.reason = "Inline PR review comment did not request review fix.";
    }
    return route;
  }

  if (eventName === "pull_request_review") {
    if (containsCommand(event.review?.body, "/fix-review")) {
      route.reviewFix = true;
      route.reason = "PR review requested review fix.";
    } else {
      route.reason = "PR review did not request review fix.";
    }
    return route;
  }

  return route;
}

async function writeOutput(name, value) {
  const outputPath = requireEnv("GITHUB_OUTPUT");
  await appendFile(outputPath, `${name}=${value}\n`);
}

async function main() {
  const eventName = requireEnv("GITHUB_EVENT_NAME");
  const event = JSON.parse(await readFile(requireEnv("GITHUB_EVENT_PATH"), "utf8"));
  const route = routeEvent(eventName, event);

  for (const [key, value] of Object.entries(route)) {
    await writeOutput(key, String(value));
  }

  console.log(JSON.stringify({ eventName, route }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
