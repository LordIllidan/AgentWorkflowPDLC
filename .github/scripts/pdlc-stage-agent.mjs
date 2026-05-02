import { readFile } from "node:fs/promises";
import path from "node:path";

const stages = {
  research: {
    command: "/pdlc research",
    marker: "<!-- pdlc-stage-research -->",
    title: "PDLC Research Agent",
    agentId: "research-agent",
    nextCommand: "/pdlc analyze",
  },
  analyze: {
    command: "/pdlc analyze",
    marker: "<!-- pdlc-stage-analysis -->",
    title: "PDLC Analyst Agent",
    agentId: "analyst-agent",
    nextCommand: "/pdlc risk",
  },
  risk: {
    command: "/pdlc risk",
    marker: "<!-- pdlc-stage-risk -->",
    title: "PDLC Autonomy Risk Agent",
    agentId: "risk-agent",
    nextCommand: "/pdlc architecture",
  },
  architecture: {
    command: "/pdlc architecture",
    marker: "<!-- pdlc-stage-architecture -->",
    title: "PDLC Architect Agent",
    agentId: "architect-agent",
    nextCommand: "/pdlc plan",
  },
  plan: {
    command: "/pdlc plan",
    marker: "<!-- pdlc-stage-plan -->",
    title: "PDLC Planner Agent",
    agentId: "planner-agent",
    nextCommand: "/approve ai-coding",
  },
};

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function extractSection(body, title) {
  const pattern = new RegExp(`^### ${title}\\s*\\n(?<content>[\\s\\S]*?)(?=\\n### |\\n## |$)`, "m");
  const match = body.match(pattern);
  return match?.groups?.content?.trim() || "Not provided.";
}

function detectStage(commentBody) {
  const normalized = commentBody.trim().toLowerCase();
  return Object.entries(stages).find(([, stage]) => normalized.startsWith(stage.command))?.[0];
}

function summarizePriorArtifacts(comments, currentStage) {
  const currentMarker = stages[currentStage].marker;
  const artifactComments = comments
    .filter((comment) => comment.body?.includes("<!-- pdlc-stage-") || comment.body?.includes("<!-- pdlc-agent-analysis -->"))
    .filter((comment) => !comment.body?.includes(currentMarker))
    .map((comment) => {
      const heading = comment.body.match(/^## (?<title>.+)$/m)?.groups?.title ?? "PDLC artifact";
      return `- ${heading} by ${comment.user?.login ?? "unknown"} at ${comment.created_at}`;
    });

  return artifactComments.length > 0 ? artifactComments.join("\n") : "- No prior stage artifacts found.";
}

async function readAgentConfig(agentId) {
  const configDir = process.env.PDLC_AGENT_CONFIG_DIR || ".pdlc-agent-config";
  const manifestPath = path.join(configDir, "agents", "manifest.json");
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  const agent = manifest.agents.find((entry) => entry.id === agentId);

  if (!agent) {
    throw new Error(`Agent '${agentId}' was not found in ${manifestPath}.`);
  }

  const prompt = await readFile(path.join(configDir, agent.promptPath), "utf8");
  return { manifestVersion: manifest.version, agent, prompt };
}

function riskRecommendation(issue) {
  const text = `${issue.title ?? ""}\n${issue.body ?? ""}`.toLowerCase();
  const highRiskTerms = ["auth", "token", "secret", "payment", "production", "security", "permission", "mcp", "regulated"];
  const mediumRiskTerms = ["api", "database", "migration", "architecture", "workflow", "ci", "deployment"];

  if (highRiskTerms.some((term) => text.includes(term))) {
    return {
      className: "high",
      autonomy: "agent-with-human-review",
      gates: "Architecture, Security, QA, Documentation, manual PR approval.",
    };
  }

  if (mediumRiskTerms.some((term) => text.includes(term))) {
    return {
      className: "medium",
      autonomy: "agent-with-human-review",
      gates: "Architecture, QA, Documentation, manual PR approval.",
    };
  }

  return {
    className: "low",
    autonomy: "agent-autonomous",
    gates: "QA, Documentation, manual PR approval.",
  };
}

function renderStageBody(stageKey, issue, priorArtifacts, agentConfig) {
  const body = issue.body ?? "";
  const businessContext = extractSection(body, "Business context");
  const systems = extractSection(body, "Repositories and systems");
  const criteria = extractSection(body, "Initial acceptance criteria");
  const risk = riskRecommendation(issue);
  const stage = stages[stageKey];

  const header = `${stage.marker}
## ${stage.title}

Issue: #${issue.number} ${issue.title}

Agent config:
- id: \`${agentConfig.agent.id}\`
- prompt: \`${agentConfig.agent.promptPath}\`
- manifest version: \`${agentConfig.manifestVersion}\`
- prompt loaded: \`${agentConfig.prompt.length} chars\`

Prior PDLC artifacts:
${priorArtifacts}
`;

  if (stageKey === "research") {
    return `${header}
### Research brief

Ten etap zbiera kontekst przed analizą biznesową. Kierunek opiera się na wcześniejszym researchu PDLC: GitHub-native agent workflow, MCP gateway, risk gates, quality/security gates, traceability, release monitoring i manual PR approval.

### Patterns to consider

- Issue jako główne źródło pracy i audytu.
- Komendy komentarzy jako jawne bramki przejścia między agentami.
- Osobne artefakty dla researchu, analizy, ryzyka, architektury i planu.
- PR jako finalny punkt akceptacji kodu i dokumentacji.

### Candidate direction

${businessContext}

### Open questions for analyst

- Jaki jest minimalny zakres pierwszego PR?
- Które kryteria akceptacji muszą być potwierdzone automatycznie w CI?
- Czy zmiana dotyka uprawnień, danych wrażliwych albo integracji MCP?

Next command:

\`\`\`text
${stage.nextCommand}
\`\`\``;
  }

  if (stageKey === "analyze") {
    return `${header}
### Business summary

${businessContext}

### User stories

- Jako użytkownik procesu PDLC chcę, aby issue było rozbijane na jawne etapy agentowe, żeby każdy artefakt był widoczny i audytowalny w GitHubie.
- Jako reviewer chcę widzieć acceptance criteria i zakres przed kodowaniem, żeby PR był oceniany względem ustalonego celu.

### Acceptance criteria

${criteria}

### Scope

In scope:
- analiza issue,
- historyjki i kryteria akceptacji,
- przekazanie kontekstu do risk i architecture.

Out of scope:
- kodowanie bez zatwierdzonego planu,
- merge bez PR review.

Next command:

\`\`\`text
${stage.nextCommand}
\`\`\``;
  }

  if (stageKey === "risk") {
    return `${header}
### Risk class

\`${risk.className}\`

### Autonomy recommendation

\`${risk.autonomy}\`

### Reasoning

Ocena uwzględnia zakres issue, systemy, testowalność, potencjalny blast radius oraz wpływ na bezpieczeństwo i wdrożenie.

### Required gates

${risk.gates}

### Stop conditions

- Brak jasnych acceptance criteria.
- Zmiana wymaga sekretów lub uprawnień niedostępnych w workerze.
- CI lub testy nie potwierdzają zachowania.
- Reviewer uzna, że zmiana wymaga ręcznej implementacji przez developera.

Next command:

\`\`\`text
${stage.nextCommand}
\`\`\``;
  }

  if (stageKey === "architecture") {
    return `${header}
### Architecture summary

Zmiana powinna przejść przez GitHub-native pipeline, gdzie każdy etap zostawia komentarz-artefakt na issue, a finalny PR zawiera kod, testy i dokumentację wynikającą z tych artefaktów.

### Affected areas

${systems}

### Contracts

- Issue comments are stage artifacts marked with HTML markers.
- Coding workers must read prior PDLC artifacts before implementation.
- PR remains the final human approval point.

### ADR decision

ADR jest wymagany, jeżeli zmiana wprowadza nowy komponent workflow, nową integrację MCP, nowe uprawnienia albo zmianę bramek ryzyka. Dla prostych zmian aplikacyjnych wystarczy artifact architekta na issue.

### Verification strategy

- GitHub workflow syntax check.
- Script syntax check.
- PR CI and manual review.

Next command:

\`\`\`text
${stage.nextCommand}
\`\`\``;
  }

  return `${header}
### Implementation scope

Plan powinien bazować na artefaktach research, analysis, risk i architecture. Coding worker może działać dopiero po zaakceptowaniu planu przez człowieka.

### Ordered tasks

1. Zaktualizować kod w minimalnym zakresie wynikającym z acceptance criteria.
2. Dodać lub zaktualizować testy dla zmienionego zachowania.
3. Zaktualizować dokumentację funkcji w \`docs\`.
4. Uruchomić odpowiednie build/test commands.
5. Utworzyć PR z linkiem do issue i artefaktów PDLC.

### Likely change areas

${systems}

### Verification plan

- .NET: \`dotnet build\` i \`dotnet test\`, jeżeli dotyczy.
- Java: \`mvn test\`, jeżeli dotyczy.
- Angular: \`npm run build\` i testy, jeżeli dotyczy.
- GitHub: PR review, CI, release monitor po merge.

### Handoff

Autonomy recommendation: \`${risk.autonomy}\`

Next command:

\`\`\`text
${stage.nextCommand}
\`\`\``;
}

async function githubRequest(pathname, options = {}) {
  const repository = requireEnv("GITHUB_REPOSITORY");
  const token = requireEnv("GITHUB_TOKEN");
  const url = new URL(`https://api.github.com/repos/${repository}${pathname}`);

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

async function upsertStageComment(issueNumber, marker, body) {
  const comments = await githubRequest(`/issues/${issueNumber}/comments?per_page=100`);
  const existing = comments.find((comment) => comment.body?.includes(marker));

  if (existing) {
    await githubRequest(`/issues/comments/${existing.id}`, {
      method: "PATCH",
      body: JSON.stringify({ body }),
    });
    return;
  }

  await githubRequest(`/issues/${issueNumber}/comments`, {
    method: "POST",
    body: JSON.stringify({ body }),
  });
}

async function main() {
  const event = JSON.parse(await readFile(requireEnv("GITHUB_EVENT_PATH"), "utf8"));
  const issue = event.issue;
  const comment = event.comment;

  if (!issue || issue.pull_request || !comment) {
    console.log("No normal issue comment event to process.");
    return;
  }

  const stageKey = detectStage(comment.body ?? "");
  if (!stageKey) {
    console.log("No supported /pdlc stage command found.");
    return;
  }

  const comments = await githubRequest(`/issues/${issue.number}/comments?per_page=100`);
  const agentConfig = await readAgentConfig(stages[stageKey].agentId);
  const priorArtifacts = summarizePriorArtifacts(comments, stageKey);
  const body = renderStageBody(stageKey, issue, priorArtifacts, agentConfig);

  await upsertStageComment(issue.number, stages[stageKey].marker, body);
  console.log(`Updated ${stageKey} artifact for issue #${issue.number}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
