import { readFile } from "node:fs/promises";

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function findIssueNumber(pullRequest) {
  const text = `${pullRequest.title ?? ""}\n${pullRequest.body ?? ""}`;
  const match = text.match(/(?:Relates to|Closes|Fixes|Resolves)\s+#(?<number>\d+)/i);
  return match?.groups?.number ? Number.parseInt(match.groups.number, 10) : null;
}

function hasFailureSignal(pullRequest) {
  const labels = pullRequest.labels?.map((label) => label.name) ?? [];
  const text = `${pullRequest.title ?? ""}\n${pullRequest.body ?? ""}`.toLowerCase();

  return (
    process.env.FORCE_DEPLOYMENT_FAILURE === "true" ||
    labels.includes("simulate-deployment-failure") ||
    text.includes("[simulate-failure]")
  );
}

function renderFollowUpBody(pullRequest, sourceIssueNumber) {
  return `### Business context

Release monitor detected a deployment failure signal after PR #${pullRequest.number} was merged.

### Repositories and systems

- repo: ${process.env.GITHUB_REPOSITORY}
- source issue: #${sourceIssueNumber}
- source PR: #${pullRequest.number}

### Initial risk guess

high

### Initial acceptance criteria

- Given the deployment failure is confirmed
- When the follow-up issue is analyzed
- Then root cause, rollback, fix scope, and verification evidence are documented

### PDLC artifacts and links

- Intake:
- Risk card:
- Requirements:
- Architecture / ADR:
- Implementation plan:
- Pull request:
- Review:
- QA:
- Security:
- Documentation:
- Release:

### Manual approval gates

- [ ] Intake approved
- [ ] Risk classification approved
- [ ] Requirements approved
- [ ] Architecture approved or not required
- [ ] Planning approved
- [ ] Coding ready for PR
- [ ] Review approved
- [ ] QA approved
- [ ] Security approved
- [ ] Documentation approved
- [ ] Release readiness approved
`;
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

async function ensureLabel(name, color, description) {
  try {
    await githubRequest(`/labels/${encodeURIComponent(name)}`);
  } catch (error) {
    if (!String(error.message).includes("404")) {
      throw error;
    }

    await githubRequest("/labels", {
      method: "POST",
      body: JSON.stringify({ name, color, description }),
    });
  }
}

async function commentOnIssue(issueNumber, body) {
  await githubRequest(`/issues/${issueNumber}/comments`, {
    method: "POST",
    body: JSON.stringify({ body }),
  });
}

async function main() {
  const event = JSON.parse(await readFile(requireEnv("GITHUB_EVENT_PATH"), "utf8"));
  const pullRequest = event.pull_request;

  if (!pullRequest?.merged) {
    console.log("Pull request was not merged. Nothing to monitor.");
    return;
  }

  const sourceIssueNumber = findIssueNumber(pullRequest);
  if (!sourceIssueNumber) {
    console.log("No linked PDLC issue found in PR body.");
    return;
  }

  const failure = hasFailureSignal(pullRequest);
  const monitorBody = `## Release monitoring result

PR #${pullRequest.number} was merged and release monitoring ran.

Deployment signal: **${failure ? "failure detected" : "healthy"}**.

${failure ? "A follow-up issue will be created." : "No follow-up issue was created."}`;

  await commentOnIssue(sourceIssueNumber, monitorBody);

  if (!failure) {
    console.log(`Recorded healthy deployment signal for issue #${sourceIssueNumber}.`);
    return;
  }

  await ensureLabel("pdlc", "0E4A7B", "Product development lifecycle workflow");
  await ensureLabel("agent-workflow", "5319E7", "Issue handled by PDLC agents");
  await ensureLabel("deployment-failure", "B60205", "Deployment issue created by release monitoring");

  const followUp = await githubRequest("/issues", {
    method: "POST",
    body: JSON.stringify({
      title: `[PDLC Follow-up] Deployment failure after PR #${pullRequest.number}`,
      body: renderFollowUpBody(pullRequest, sourceIssueNumber),
      labels: ["pdlc", "agent-workflow", "deployment-failure"],
    }),
  });

  await commentOnIssue(
    sourceIssueNumber,
    `Follow-up issue created by release monitor: #${followUp.number} ${followUp.html_url}`,
  );

  console.log(`Created deployment follow-up issue #${followUp.number}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
