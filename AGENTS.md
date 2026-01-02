# oc-intent-layer

## Purpose & Scope

Tooling to bootstrap, manage, and maintain intent layer hierarchies for OpenCode.

**Owns**: Skills and commands for intent node capture, chunking, refresh, and validation.

**Does NOT own**: OpenCode core, AGENTS.md loading/discovery (that's OpenCode itself), or intent layer theory (see references).

## Entry Points & Contracts

Skills (invoke via `@skill-name`):
- `@intent-chunk` — Analyze codebase, calculate token budgets, output leaf-first capture order
- `@intent-capture` — Interactive SME interview for single directory, generate AGENTS.md

Commands (invoke via `/command`):
- `/intent-init` — Full bootstrap: chunk analysis + capture all nodes + install pre-push hook
- `/intent-capture [path]` — Capture single node
- `/intent-sync` — Update nodes affected by recent code changes

**Invariants**:
- Capture order is always leaf-first (children before parents)
- Parent nodes read child AGENTS.md, never child code (fractal compression)
- Open Questions resolve via LCA lifting during parent capture
- Generated nodes target 1-3k tokens from 20-64k source

## Dependencies

- OpenCode CLI with skill/command support
- Git (for pre-push hook, change detection)
- Target codebase must be a git repository

## Usage Patterns

Bootstrap a new project:
```
/intent-init
```

Capture single node after understanding area:
```
/intent-capture ./services/payment/
```

Sync after code changes (or when pre-push hook warns):
```
/intent-sync
```

## Anti-Patterns

- Capturing parent before children — breaks fractal compression
- Skipping interview for complex areas — misses tribal knowledge
- Documenting lateral deps in nodes — ancestors expose via downlinks
- Huge root nodes (15k+) — decompose hierarchically instead

## Downlinks

- .opencode/skill/intent-chunk/SKILL.md — chunking logic
- .opencode/skill/intent-capture/SKILL.md — interview + generation
- .opencode/command/intent-init.md — bootstrap orchestration
- .opencode/command/intent-capture.md — single node command
- .opencode/command/intent-sync.md — maintenance command

## Outlinks

- PLAN.md — full implementation plan with phases
- opencode-guide.md — OpenCode primitives reference
- intent-layer-guide.md — Intent layer theory reference
- https://www.intent-systems.com/learn/intent-layer — canonical source

## Patterns & Pitfalls

- **Interview first, generate second**: Agent describes observations, SME corrects. Correcting is faster than explaining from scratch.
- **Easy areas first**: Capture simple modules before complex ones. Context compounds.
- **LCA placement**: Shared facts go in shallowest ancestor that covers all consumers. Prevents duplication and drift.
- **Token sweet spot**: 20-64k source tokens compress well. Smaller = poor ratio. Larger = split into children.

