import { readFile } from "node:fs/promises";

const analysisMarker = "<!-- pdlc-agent-analysis -->";

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function hasLabel(issue, name) {
  return issue.labels?.some((label) => label.name === name) ?? false;
}

function hasPdlcChecklist(issue) {
  const body = issue.body ?? "";
  return body.includes("Manual approval gates") || body.includes("Intake approved");
}

function extractSection(body, title) {
  const pattern = new RegExp(`^### ${title}\\s*\\n(?<content>[\\s\\S]*?)(?=\\n### |\\n## |$)`, "m");
  const match = body.match(pattern);
  return match?.groups?.content?.trim() || "Not provided.";
}

function renderAnalysis(issue) {
  const body = issue.body ?? "";
  const businessContext = extractSection(body, "Business context");
  const repositories = extractSection(body, "Repositories and systems");
  const acceptanceCriteria = extractSection(body, "Initial acceptance criteria");
  const initialRisk = extractSection(body, "Initial risk guess");

  return `${analysisMarker}
## Agent Analysis

Issue: #${issue.number} ${issue.title}

### Business summary

${businessContext}

### Initial risk

${initialRisk}

### Repositories and systems

${repositories}

### Proposed split

| Part | Goal | Output |
|---|---|---|
| 1. Product scope | Clarify business value and acceptance criteria | refined user story, exclusions, acceptance checklist |
| 2. Architecture impact | Identify services, contracts, data, and operational impact | lightweight ADR or "not required" note |
| 3. Implementation | Prepare branch-level coding work | code change, tests, PR |
| 4. Verification | Check CI, tests, review, security, and docs | PR evidence and unresolved risk list |
| 5. Release monitoring | Watch post-merge signal and create follow-up issues on failure | monitoring comment or incident issue |

### Acceptance criteria seen by the agent

${acceptanceCriteria}

### Next human action

Review this analysis. If it is acceptable, add a comment:

\`\`\`text
/approve analysis
\`\`\`

The coding agent will then create a branch, generate PDLC artifacts, update the sample app documentation, and open a pull request.`;
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
    const responseBody = await response.text();
    throw new Error(`GitHub API failed: ${response.status} ${responseBody}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

async function upsertAnalysisComment(issue, body) {
  const comments = await githubRequest(`/issues/${issue.number}/comments?per_page=100`);
  const existing = comments.find((comment) => comment.body?.includes(analysisMarker));

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
  const event = JSON.parse(await readFile(requireEnv("GITHUB_EVENT_PATH"), "utf8"));
  const issue = event.issue;

  if (!issue || issue.pull_request) {
    console.log("No issue payload to analyze.");
    return;
  }

  if (!hasLabel(issue, "pdlc") && !hasLabel(issue, "agent-workflow") && !hasPdlcChecklist(issue)) {
    console.log("Issue is not marked as a PDLC agent workflow issue.");
    return;
  }

  await upsertAnalysisComment(issue, renderAnalysis(issue));
  console.log(`Updated agent analysis for issue #${issue.number}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
