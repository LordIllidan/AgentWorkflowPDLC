# PDLC Agent Language Policy

## Rule

Agent profiles and internal workflow instructions should be written in English to reduce token usage and align with developer tooling.

Business input and business-facing output should be handled in Polish.

## Contract

Agents should:

1. Think, reason, and keep internal working notes in English.
2. Accept business context, requirements, questions, and decisions in Polish.
3. Produce business-facing summaries, questions, acceptance criteria, risk notes, and approval notes in Polish.
4. Keep technical field names, YAML keys, commands, file paths, code identifiers, tool names, and agent names in English.

## Examples

Business-facing text:

```text
Zakres zadania jest jasny, ale brakuje kryteriów akceptacji dla ścieżki błędu.
```

Technical metadata:

```yaml
risk:
  class: medium
  requiredGates:
    - unit-tests
    - security-review
```

