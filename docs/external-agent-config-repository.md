# External Agent Configuration Repository

## Goal

The PDLC workers can now fetch agent definitions from a separate configuration repository before running Claude Code. This keeps base prompts, specialist agent rules, skill notes, and MCP templates outside the application repository.

Default configuration repository:

```text
LordIllidan/AgentWorkflowPDLC-AgentConfig
```

## Runtime Flow

```text
GitHub issue or PR comment
  -> self-hosted Windows runner
  -> worker script clones AgentWorkflowPDLC-AgentConfig
  -> worker reads agents/manifest.json and agent prompts
  -> worker injects configuration into the Claude Code prompt
  -> Claude Code selects matching specialists and edits the repository
```

## Worker Variables

| Variable | Default | Meaning |
|---|---:|---|
| `PDLC_AGENT_CONFIG_REPO` | `LordIllidan/AgentWorkflowPDLC-AgentConfig` | GitHub repository containing agent configuration. |
| `PDLC_AGENT_CONFIG_REF` | `main` | Branch, tag, or commit to check out before reading configuration. |

Pin `PDLC_AGENT_CONFIG_REF` to a tag or commit when reproducibility matters.

## Included Configuration

The first configuration repository version includes:

- research agent,
- analyst agent,
- autonomy risk agent,
- architect agent,
- planner agent,
- Angular agent,
- Java agent,
- .NET agent,
- review-fix agent,
- security agent,
- worker startup policy,
- MCP configuration example without secrets.

Stage agents are used by `.github/workflows/pdlc-stage-agents.yml` for issue comments. The workflow runs on the self-hosted Windows runner and calls local Claude Code with the selected agent prompt:

```text
/pdlc research
/pdlc analyze
/pdlc risk
/pdlc architecture
/pdlc plan
```

## Safety Rules

- Do not store secrets in the config repository.
- Store only templates, prompt text, policy metadata, and non-sensitive tool descriptions.
- Use repository variables or runner-local secure files for real MCP tokens and URLs.
- Keep manual PR approval enabled even when workers use external prompts.
