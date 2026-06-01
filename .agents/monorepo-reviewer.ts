import { AgentDefinition } from "./types/agent-definition"

const definition: AgentDefinition = {
  id: "monorepo-reviewer",
  version: "1.0.0",
  displayName: "Monorepo Reviewer",
  spawnerPrompt:
    "Spawn this agent to review current git changes for bugs, security risks, behavioral regressions, package-boundary violations, generated-file edits, missing tests, and verification gaps.",
  model: "anthropic/claude-sonnet-4.6",
  outputMode: "last_message",
  includeMessageHistory: true,
  reasoningOptions: {
    enabled: true,
    exclude: false,
    effort: "high",
  },

  toolNames: [
    "read_files",
    "code_search",
    "find_files",
    "run_terminal_command",
    "spawn_agents",
    "skill",
    "end_turn",
  ],
  spawnableAgents: ["codebuff/reviewer@0.0.1", "codebuff/thinker@0.0.1"],

  inputSchema: {
    prompt: {
      type: "string",
      description: "The change set or area to review",
    },
  },

  systemPrompt: `You are a strict, pragmatic code reviewer for the family-events monorepo.

Review priorities:
- Findings first, ordered by severity.
- Include file and line references when possible.
- Prioritize bugs, security issues, behavioral regressions, package-boundary violations, generated-file edits, and missing tests.
- Do not spend findings on subjective style unless it creates maintainability or correctness risk.
- If no findings exist, say so and list residual risks or unrun verification.

Repo-specific checks:
- packages/shared must remain framework-agnostic.
- apps/web must not instantiate Supabase clients outside apps/web/src/infrastructure/supabase/client.ts.
- iOS must remain consumer-only and respect package boundaries.
- Supabase SECURITY DEFINER RPCs require the private body plus public wrapper pattern.
- Generated token files must not be hand-edited.`,

  instructionsPrompt:
    "Review the current diff/status. Read AGENTS.md and relevant scoped instructions. Report only actionable findings, then open questions, then a short verification summary.",

  stepPrompt: "Continue reviewing. Use end_turn when complete.",

  handleSteps: function* () {
    yield {
      toolName: "read_files",
      input: {
        paths: ["AGENTS.md", "knowledge.md"],
      },
    }

    yield {
      toolName: "run_terminal_command",
      input: { command: "git status --porcelain" },
    }

    yield {
      toolName: "run_terminal_command",
      input: { command: "git diff --stat" },
    }

    yield {
      toolName: "run_terminal_command",
      input: { command: "git diff -- . :!pnpm-lock.yaml" },
    }

    yield "STEP_ALL"
  },
}

export default definition
