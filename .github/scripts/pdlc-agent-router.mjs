import { appendFile, readFile } from "node:fs/promises";

const stageCommands = [
  "/pdlc research",
  "/pdlc analyze",
  "/pdlc risk",
  "/pdlc architecture",
  "/pdlc plan",
];

function getPdlcCommandFromPush(event) {
  const message = event.head_commit?.message ?? "";
  const issueMatch = message.match(/(?:issue|#)\s*#?(\d+)/i);
  const commandMatch = message.match(/\/pdlc\s+(?:research|analyze|risk|architecture|plan)|\/approve\s+ai-coding/i);

  if (!issueMatch || !commandMatch) {
    return null;
  }

  return {
    issueNumber: issueMatch[1],
    command: commandMatch[0],
  };
}

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
    riskAssessment: false,
    stage: false,
    localCoding: false,
    reviewFix: false,
    issueNumber: "",
    reason: "No route matched.",
  };

  if (eventName === "repository_dispatch" && event.action === "pdlc_issue_created") {
    route.riskAssessment = true;
    route.issueNumber = event.client_payload?.issue_number ?? "";
    route.reason = "Research-created issue dispatch should run autonomy risk assessment.";
    return route;
  }

  if (eventName === "repository_dispatch" && event.action === "pdlc_stage_command") {
    const command = event.client_payload?.command ?? "";
    route.issueNumber = event.client_payload?.issue_number ?? "";
    if (startsWithAny(command, stageCommands)) {
      route.stage = true;
      route.reason = "Repository dispatch requested a PDLC stage agent.";
      return route;
    }

    if (command.trim().toLowerCase().startsWith("/approve ai-coding")) {
      route.localCoding = true;
      route.reason = "Repository dispatch approved local Claude Code implementation.";
      return route;
    }

    route.reason = "Repository dispatch did not contain a supported PDLC command.";
    return route;
  }

  if (eventName === "workflow_dispatch") {
    const command = event.inputs?.command ?? "";
    route.issueNumber = event.inputs?.issue_number ?? "";
    if (startsWithAny(command, stageCommands)) {
      route.stage = true;
      route.reason = "Workflow dispatch requested a PDLC stage agent.";
      return route;
    }

    if (command.trim().toLowerCase().startsWith("/approve ai-coding")) {
      route.localCoding = true;
      route.reason = "Workflow dispatch approved local Claude Code implementation.";
      return route;
    }

    route.reason = "Workflow dispatch did not contain a supported PDLC command.";
    return route;
  }

  if (eventName === "push") {
    const pdlcCommand = getPdlcCommandFromPush(event);
    if (!pdlcCommand) {
      route.reason = "Push did not contain a supported PDLC command format.";
      return route;
    }

    route.issueNumber = pdlcCommand.issueNumber;

    if (startsWithAny(pdlcCommand.command, stageCommands)) {
      route.stage = true;
      route.reason = "Push commit message requested a PDLC stage agent.";
      return route;
    }

    if (pdlcCommand.command.trim().toLowerCase().startsWith("/approve ai-coding")) {
      route.localCoding = true;
      route.reason = "Push commit message approved local Claude Code implementation.";
      return route;
    }

    return route;
  }

  if (eventName === "issues") {
    if (isPullRequestIssue(event.issue)) {
      route.reason = "Issue event belongs to a pull request.";
      return route;
    }

    route.issueNumber = event.issue?.number ?? "";
    if (event.action === "opened") {
      route.riskAssessment = true;
      route.reason = "New issue should refresh status and run autonomy risk assessment.";
      return route;
    }

    route.reason = "Issue lifecycle event did not require an AI agent.";
    return route;
  }

  if (eventName === "issue_comment") {
    const body = event.comment?.body ?? "";
    route.issueNumber = event.issue?.number ?? "";

    if (isPullRequestIssue(event.issue)) {
      if (containsCommand(body, "/fix-review")) {
        route.reviewFix = true;
        route.reason = "PR comment requested review fix.";
      } else {
        route.reason = "PR comment did not request review fix.";
      }
      return route;
    }

    if (startsWithAny(body, stageCommands) || body.trim().toLowerCase().startsWith("/pdlc answer")) {
      route.stage = true;
      route.reason = "Issue comment requested a PDLC stage agent.";
      return route;
    }

    if (body.trim().toLowerCase().startsWith("/approve ai-coding")) {
      route.localCoding = true;
      route.reason = "Issue comment approved local Claude Code implementation.";
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
