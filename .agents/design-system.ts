import { AgentDefinition } from "./types/agent-definition"

const definition: AgentDefinition = {
  id: "design-system",
  version: "1.0.0",
  displayName: "Design System Specialist",
  spawnerPrompt:
    "Spawn this agent for any UI, visual, or design token work. " +
    "Handles token changes, component styling, Tailwind 4 theme, and design-to-code alignment. " +
    "Always reads docs/DESIGN.md before making any visual decision.",
  model: "anthropic/claude-sonnet-4.6",
  outputMode: "last_message",
  includeMessageHistory: true,

  toolNames: [
    "read_files",
    "write_file",
    "code_search",
    "run_terminal_command",
    "spawn_agents",
    "end_turn",
  ],
  spawnableAgents: ["codebuff/reviewer@0.0.1"],

  inputSchema: {
    prompt: {
      type: "string",
      description: "UI change, design token update, or visual decision to make",
    },
  },

  systemPrompt: `You are the design system specialist for the family-events monorepo.

DESIGN SYSTEM RULES (never deviate):

1. Always read docs/DESIGN.md before any visual or UI decision. It is the source of truth.
   - Mockup reference: docs/design/mocks/design-preview.html
   - Design direction: sunlit civic bulletin board aesthetic
   - Palette: light primary, green + coral + civic-blue + kid-yellow
   - Fonts: Fraunces (display) + DM Sans (body) + Newsreader (editorial) + Geist Mono (code)

2. Token source of truth: packages/design-system/tokens/tokens.json
   - NEVER hand-edit generated files:
     * apps/web/src/styles/tokens.generated.css
     * apps/ios/Packages/FEDesignSystem/Sources/.../Generated/Tokens.swift
     * packages/design-system/src/generated/*
   - To change tokens: edit tokens/tokens.json, then run:
     pnpm --filter @family-events/design-system build

3. Web styling: Tailwind 4 with @theme CSS custom properties (consumed from tokens.generated.css)
4. Mobile-first v2 primitives: apps/web/src/components/v2/ (page.tsx, stack.tsx, toolbar.tsx, responsive-card.tsx, filter-bar.tsx, touch-target.tsx)
5. Safe-area and viewport-fit=cover are wired — use env(safe-area-inset-*) for mobile edges`,

  instructionsPrompt:
    "First read docs/DESIGN.md to understand the design direction. " +
    "Then read the relevant token files or component files. " +
    "Make changes that align with the design spec. " +
    "If tokens change, remind the user to run: pnpm --filter @family-events/design-system build",

  stepPrompt: "Continue the design task. Use end_turn when complete.",

  handleSteps: function* () {
    // Always read the design spec first
    yield {
      toolName: "read_files",
      input: {
        paths: ["docs/DESIGN.md"],
      },
    }

    // Also load the token source
    yield {
      toolName: "read_files",
      input: {
        paths: ["packages/design-system/tokens/tokens.json"],
      },
    }

    // Let the LLM handle the design task
    yield "STEP_ALL"
  },
}

export default definition
