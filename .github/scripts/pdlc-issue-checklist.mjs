import { readFile } from "node:fs/promises";

const statusMarker = "<!-- pdlc-status -->";

const stages = [
  {
    key: "intake",
    label: "Intake approved",
    agent: "Intake Agent",
    nextAction: "Prepare or review the task brief, assumptions, and missing information.",
  },
  {
    key: "risk",
    label: "Risk classification approved",
    agent: "Risk Classifier Agent",
    nextAction: "Prepare or review the risk card, required gates, and approvers.",
  },
  {
    key: "requirements",
    label: "Requirements approved",
    agent: "Product Agent",
    nextAction: "Prepare or review user stories, acceptance criteria, and out-of-scope.",
  },
  {
    key: "architecture",
    label: "Architecture approved or not required",
    agent: "Architecture Agent",
    nextAction: "Prepare or review ADR, architecture impact, and rollback notes.",
  },
  {
    key: "planning",
    label: "Planning approved",
    agent: "Planning Agent",
    nextAction: "Prepare or review implementation steps, tests, verification, and stop conditions.",
  },
  {
    key: "coding",
    label: "Coding ready for PR",
    agent: "Coding Agent",
    nextAction: "Implement the approved plan in a branch and open a draft PR.",
  },
  {
    key: "review",
    label: "Review approved",
    agent: "Review Agent",
    nextAction: "Review the PR for defects, regressions, and requirement alignment.",
  },
  {
    key: "qa",
    label: "QA approved",
    agent: "QA Agent",
    nextAction: "Run or review tests and attach QA evidence.",
  },
  {
    key: "security",
    label: "Security approved",
    agent: "Security Agent",
    nextAction: "Run or review security checks, exceptions, and access-control impact.",
  },
  {
    key: "docs",
    label: "Documentation approved",
    agent: "Docs Agent",
    nextAction: "Prepare or review feature documentation, ADR updates, and PR summary.",
  },
  {
    key: "release",
    label: "Release readiness approved",
    agent: "Release Agent",
    nextAction: "Prepare or review release readiness, rollback, SBOM, and monitoring checks.",
  },
];

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function normalize(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function isChecked(body, label) {
  const pattern = new RegExp(`^- \\[[xX]\\] ${normalize(label)}\\s*$`, "m");
  return pattern.test(body);
}

function readStageState(body) {
  return stages.map((stage) => ({
    ...stage,
    approved: isChecked(body, stage.label),
  }));
}

function renderStatus(issue, stageState) {
  const completed = stageState.filter((stage) => stage.approved);
  const nextStage = stageState.find((stage) => !stage.approved);
  const complete = !nextStage;
  const progress = `${completed.length}/${stageState.length}`;

  const rows = stageState
    .map((stage) => {
      const status = stage.approved ? "approved" : "pending";
      return `| ${stage.label} | ${stage.agent} | ${status} |`;
    })
    .join("\n");

  const nextSection = complete
    ? "All manual PDLC gates are approved. The issue is ready for final human closure or release tracking."
    : `Next required stage: **${nextStage.label}**.\n\nSuggested owner: **${nextStage.agent}**.\n\nNext action: ${nextStage.nextAction}`;

  return `${statusMarker}
## PDLC Status

Issue: #${issue.number} ${issue.title}

Progress: **${progress}**

${nextSection}

| Gate | Agent | Status |
|---|---|---|
${rows}

This comment is maintained by GitHub Actions. Manual approval still happens only by editing the issue checklist.`;
}

async function githubRequest(path, options = {}) {
  const repository = requireEnv("GITHUB_REPOSITORY");
  const token = requireEnv("GITHUB_TOKEN");
  const url = new URL(`https://api.github.com/repos/${repository}${path}`);

  const response = await fetch(url, {
    ...options,
    headers: {
      accept: "application/vnd.github+json",
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      "x-github-api-version": "2022-11-28",
      ...(options.headers ?? {}),
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GitHub API failed: ${response.status} ${body}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

async function upsertStatusComment(issue, body) {
  const comments = await githubRequest(`/issues/${issue.number}/comments?per_page=100`);
  const existing = comments.find((comment) => comment.body?.includes(statusMarker));

  if (existing) {
    await githubRequest(`/issues/comments/${existing.id}`, {
      method: "PATCH",
      body: JSON.stringify({ body }),
    });
    return;
  }

  await githubRequest(`/issues/${issue.number}/comments`, {
    method: "POST",
    body: JSON.stringify({ body }),
  });
}

async function main() {
  const eventPath = requireEnv("GITHUB_EVENT_PATH");
  const event = JSON.parse(await readFile(eventPath, "utf8"));
  const issue = event.issue;

  if (!issue || issue.pull_request) {
    console.log("No issue payload to process.");
    return;
  }

  const body = issue.body ?? "";
  const stageState = readStageState(body);
  const hasAnyKnownGate = stageState.some((stage) => body.includes(stage.label));

  if (!hasAnyKnownGate) {
    console.log("Issue does not contain PDLC checklist gates.");
    return;
  }

  const status = renderStatus(issue, stageState);
  await upsertStatusComment(issue, status);
  console.log(`Updated PDLC status for issue #${issue.number}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

