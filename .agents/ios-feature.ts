import { AgentDefinition } from "./types/agent-definition"

const definition: AgentDefinition = {
  id: "ios-feature",
  version: "1.0.0",
  displayName: "iOS Feature Specialist",
  spawnerPrompt:
    "Spawn this agent for SwiftUI consumer iOS work in apps/ios, including package boundaries, XcodeGen project changes, Swift tests, and iOS verification.",
  model: "anthropic/claude-sonnet-4.6",
  outputMode: "last_message",
  includeMessageHistory: true,
  reasoningOptions: {
    enabled: true,
    exclude: false,
    effort: "medium",
  },

  toolNames: [
    "read_files",
    "write_file",
    "str_replace",
    "code_search",
    "find_files",
    "run_terminal_command",
    "spawn_agents",
    "skill",
    "end_turn",
  ],
  spawnableAgents: ["codebuff/reviewer@0.0.1", "codebuff/researcher@0.0.1"],

  inputSchema: {
    prompt: {
      type: "string",
      description: "The iOS feature, bugfix, or review task to perform under apps/ios",
    },
  },

  systemPrompt: `You are the iOS feature specialist for the family-events monorepo.

Critical iOS rules:
- Read AGENTS.md and apps/ios/AGENTS.md before changing iOS code.
- iOS is consumer-only unless the user explicitly approves otherwise.
- Admin endpoints stay blocked by endpoint policy tests.
- apps/ios/project.yml is the XcodeGen source of truth for project structure.
- FECore owns domain primitives and pure helpers.
- FEData owns Supabase adapters, DTOs, mappers, repositories, cache, and platform data services.
- FEAuth owns auth UI/session workflows and auth-specific Supabase calls.
- FEDesignSystem owns SwiftUI primitives and generated design tokens.
- Feature packages consume FECore, FEData contracts/fakes, and FEDesignSystem.
- Feature packages must not import Supabase, CoreLocation, WeatherKit, or SwiftData directly.
- Never hand-edit generated design token files.`,

  instructionsPrompt:
    "Load the root and iOS instructions first. Then inspect existing package patterns before editing. Make the smallest correct change, preserve unrelated dirty worktree changes, and recommend pnpm run verify:ios for iOS-only changes.",

  stepPrompt: "Continue the iOS task. Use end_turn when complete.",

  handleSteps: function* () {
    yield {
      toolName: "read_files",
      input: {
        paths: ["AGENTS.md", "apps/ios/AGENTS.md", "knowledge.md"],
      },
    }

    yield "STEP_ALL"
  },
}

export default definition
