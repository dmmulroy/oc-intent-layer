# oc-intent-layer

## Purpose & Scope

Tooling to bootstrap, manage, and maintain intent layer hierarchies for OpenCode.

**Owns**: Skills and commands for intent node capture, chunking, refresh, and validation.

**Does NOT own**: OpenCode core, AGENTS.md loading/discovery (that's OpenCode itself), or intent layer theory (see references).

## Entry Points & Contracts

**Installation:**
```bash
curl -fsSL https://raw.githubusercontent.com/dmmulroy/oc-intent-layer/main/install.sh | bash
```
Only installs `/intent-init` command. Other components install on first run.

**Commands (invoke via `/command`):**
- `/intent-init` — Full bootstrap: dependency setup + chunk analysis + discovery pass + consolidated interview + install pre-push hook
- `/intent-capture [path]` — Capture/update single node (installed by /intent-init)
- `/intent-sync` — Update nodes affected by recent code changes (installed by /intent-init)

**Skills (invoke via `@skill-name`):**
- `@intent-chunk` — Analyze codebase, calculate token budgets (requires tiktoken), output leaf-first capture order
- `@intent-capture` — Generate AGENTS.md - supports discovery mode (agentic) and interactive mode (SME interview)

**Invariants**:
- Token counting MUST TRY tiktoken first (node, then python) before estimation fallback
- Capture order is always leaf-first (children before parents)
- Parent nodes read child AGENTS.md, never child code (fractal compression)
- Open Questions resolve via LCA lifting during parent capture
- Generated nodes target 1-3k tokens from 20-64k source
- Node count based on actual token counts, not arbitrary boundaries
- **Maximum leaf coverage**: No leaf intent node may cover >100k source tokens
- **Recursive until optimal**: Directories >64k tokens MUST be recursively decomposed until all leaves reach 20k-64k range
- **Validation required**: Capture plan must pass token compliance checks before presenting to user
- **Downlink URLs**: MUST always end in `AGENTS.md` (e.g., `./child/AGENTS.md`), NEVER directory path
- **Downlinks only for nodes with AGENTS.md**: Items merged into parent (<10k tokens) go in "Inlined (Below Threshold)" section, NOT Downlinks table

## Dependencies

- OpenCode CLI with skill/command support
- Git (for pre-push hook, change detection)
- **tiktoken** (required for accurate token counting):
  - Node.js: `npm install -g tiktoken` (preferred)
  - Python: `pip3 install tiktoken` (fallback)
- Target codebase must be a git repository

## Usage Patterns

Bootstrap a new project:
```
/intent-init
```
This will:
1. Install dependencies (skills, commands, tiktoken if needed)
2. Analyze codebase with accurate token counts
3. Run discovery pass (generate all drafts without user interaction)
4. Run consolidated interview (all questions in one session)
5. Write all intent nodes
6. Install pre-push hook

Capture single node after understanding area:
```
/intent-capture ./services/payment/
```

Sync after code changes (or when pre-push hook warns):
```
/intent-sync
```

## Anti-Patterns

- **Using estimation instead of tiktoken** — leads to wrong node boundaries
- **Creating too many small nodes** — merge if <10k tokens
- **Capturing parent before children** — breaks fractal compression
- **Skipping interview for complex areas** — misses tribal knowledge
- **Documenting lateral deps in nodes** — ancestors expose via downlinks
- **Huge root nodes (15k+)** — decompose hierarchically instead
- **Treating large packages as single nodes** — a 2M token package needs ~40 internal nodes, not 1. Always recurse until reaching 20k-64k range.
- **Using package count as node count** — 36 packages in a monorepo doesn't mean 36 nodes. Token mass determines node count, not manifest count.
- **Downlinks to directories instead of AGENTS.md** — Always link to `./child/AGENTS.md`, never `./child/`
- **Listing merged items as downlinks** — Items merged into parent (<10k tokens) go in "Inlined (Below Threshold)" section, NOT in Downlinks table

## Downlinks

- .opencode/skill/intent-chunk/SKILL.md — chunking logic, token counting, node heuristics
- .opencode/skill/intent-capture/SKILL.md — discovery mode + interview + generation
- .opencode/command/intent-init.md — bootstrap orchestration, two-pass architecture
- .opencode/command/intent-capture.md — single node command wrapper
- .opencode/command/intent-sync.md — sync nodes after code changes, leaf-first diff analysis

## Outlinks

- opencode-guide.md — OpenCode primitives reference
- intent-layer-guide.md — Intent layer theory reference
- https://www.intent-systems.com/learn/intent-layer — canonical source

## Patterns & Pitfalls

- **Two-pass architecture**: Discovery pass generates all drafts without user interaction, then consolidated interview asks only genuinely unclear questions. Reduces interruptions and improves question quality.
- **Try tiktoken first**: The agent MUST actually attempt Node.js tiktoken and python tiktoken before falling back to bytes/4 estimation. Estimation has 20%+ error which can cause wrong node boundary decisions.
- **Node count heuristics** (sanity check: `expected_leaves ≈ total_tokens / 50k`):
  - <20k tokens: 1 node (root only)
  - 20k-64k: 1-2 nodes
  - 64k-200k: 2-4 leaves
  - 200k-500k: 4-10 leaves
  - 500k-2M: 10-40 leaves
  - 2M-10M: 40-200 leaves
  - >10M: 200+ leaves
  - Merge candidates <10k tokens into parent
- **Interview first, generate second**: Agent describes observations, SME corrects. Correcting is faster than explaining from scratch.
- **Easy areas first**: Capture simple modules before complex ones. Context compounds.
- **LCA placement**: Shared facts go in shallowest ancestor that covers all consumers. Prevents duplication and drift.
- **Legacy AGENTS.md handling**: Audit existing files before capture. Classify as intent nodes (skip) vs legacy (extract & replace). Never silently skip—legacy files often contain valuable tribal knowledge.
- **Lazy installation**: Only /intent-init is installed initially. Skills and other commands install on first run. This keeps initial setup fast.
- **Root Open Questions**: If questions remain unresolved at root, they represent true unknowns in the codebase. Document as-is or create follow-up tasks to investigate with domain experts.
