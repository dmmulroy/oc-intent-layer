# Intent Layer System for OpenCode — Implementation Plan

## Overview

Build tooling to bootstrap, manage, and leverage hierarchical AGENTS.md intent nodes using OpenCode primitives (skills, commands).

**Core concept**: Hierarchical context embedded in codebases. AI agents load pre-built architectural knowledge via T-shaped context loading instead of re-analyzing code from scratch.

**Key insight**: The ceiling on AI results isn't model intelligence—it's what the model sees before it acts.

---

## Why This Matters

Without intent layer, every agent starts from zero:

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT EXPLORING CODEBASE (NO INTENT LAYER)                 │
├─────────────────────────────────────────────────────────────┤
│  Query tokens                          ~500                 │
│  Exploration overhead (ls, grep)       ~15k                 │
│  Relevant code found                   ~10k                 │
│  Dead ends & noise                     ~15k+                │
│  ─────────────────────────────────────────────              │
│  TOTAL: 40k+ tokens consumed                                │
│  RESULT: Critical files missed, bugs not found              │
└─────────────────────────────────────────────────────────────┘
```

**Why noise actively hurts**: Transformers weight every token against every other token. Irrelevant context doesn't just waste budget—it drowns out signal.

With intent layer:

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT WITH INTENT LAYER                                    │
├─────────────────────────────────────────────────────────────┤
│  Intent Layer context                  ~16k                 │
│  Relevant code (targeted)              ~16k                 │
│  ─────────────────────────────────────────────              │
│  TOTAL: ~32k tokens                                         │
│  RESULT: Bug found—agent knew exactly where to look         │
└─────────────────────────────────────────────────────────────┘
```

**Two primary goals**:
1. **Compress context efficiently** — distill large code areas into minimum necessary tokens
2. **Surface hidden context** — capture architectural decisions, invariants, contracts that code alone cannot express

---

## Fractal Compression

Each layer compresses the layer below:

| Layer | Tokens | Compression |
|-------|--------|-------------|
| Raw code | 200k | — |
| Leaf node | 20k | 10:1 |
| Parent node | 2k | 10:1 |
| Root node | 500 | 4:1 |

**Total**: ~400:1 compression

Parents summarize child AGENTS.md—not raw code. This enables progressive disclosure at scale.

---

## Architecture

```
.opencode/
├── skill/
│   ├── intent-chunk/SKILL.md      # Analyze codebase → capture plan
│   └── intent-capture/SKILL.md    # Interactive capture w/ SME interview
└── command/
    ├── intent-init.md             # /intent-init — full bootstrap + hook
    ├── intent-capture.md          # /intent-capture [path] — single node
    └── intent-sync.md              # /intent-sync — update stale nodes
```

---

## Intent Node Structure

```markdown
# [Module Name]

## Purpose & Scope
[What this owns. What it explicitly doesn't.]
Example: "Owns: payment validation, amount formatting. Does NOT own: persistence, user identity."

## Entry Points & Contracts
- `function(input): output` — [description]
- Invariants: [constraints callers must respect]

## Dependencies
- [External system, library, env var requirement]

## Usage Patterns
[Canonical correct usage example]

## Anti-Patterns
❌ [Bad pattern] — [why]

## Downlinks
- ./child/AGENTS.md — [brief desc]

## Outlinks
- /docs/adr/NNN-decision.md — [why this matters]
- /docs/diagrams/flow.png — [visual reference]

## Patterns & Pitfalls
- [Gotcha]
- [Historical context]

---

## Open Questions
- ? [Unresolved — lift to LCA or future pass]

## Pending Tasks
- ○ [Refactor discovered during capture]
```

**Notes**:
- No upstream/lateral deps — ancestors auto-loaded by OpenCode
- Downlinks only — progressive disclosure to children
- Outlinks — external docs, ADRs, diagrams for deep dives
- Open Questions/Pending Tasks — temporary, resolve via LCA lifting
- Target: 1-3k tokens per node (from 20-64k source)

---

## Capture Process

### Phase 1: Chunking

```
1. Walk directory tree
2. Calculate token count per directory
3. Identify semantic boundaries:
   - Package manifests (package.json, go.mod, etc.)
   - Domain directories (services/, api/, lib/)
   - Code mass 20k-64k tokens (sweet spot)
4. Skip: node_modules, .git, dist, vendor, __pycache__
5. Output: leaf-first capture order
```

**Semantic boundaries exist where**:
- Responsibilities shift
- Contracts matter (invariants, APIs)
- Complexity warrants context

**Good boundaries**: domain boundaries, integration points, non-obvious invariants
**Bad boundaries**: arbitrary folder splits, single-file utilities, test dirs (unless complex)

**Capture order principle**: Easy areas first, hard areas last. Clarity compounds—understanding simple areas illuminates complex ones.

### Phase 2: Leaf-First Capture with SME Interview

For each node in order:

```
1. READ
   - Leaf: read code files
   - Parent: read child AGENTS.md only (fractal compression)

2. INTERVIEW (conversation-based)

   Agent FIRST describes observations:
   - "This appears to handle X..."
   - "I see Y calling Z, which suggests..."

   Then asks targeted questions:
   - "What triggers X?"
   - "Invariants not enforced by code?"
   - "Is Y deprecated?"
   - "Feature flags?"
   - "Historical landmines?"

   User: corrects misunderstandings, explains history, warns about landmines.

   Track in SHARED STATE (accumulates across chunks):
   - Open questions → resolve in later chunks
   - Cross-references → inform LCA decisions
   - Refactor opportunities → surface in Pending Tasks

   Agent discretion — scale interview depth with complexity.

3. GENERATE
   - Create AGENTS.md (1-3k tokens)
   - Add Open Questions if unresolved
   - Add Pending Tasks if refactors found

4. LCA RESOLUTION (parent nodes)
   - Read child Open Questions
   - Resolve what belongs at this level
   - Update children to remove resolved items

5. WRITE
   - Confirm with user
   - Write AGENTS.md
```

### Phase 3: Hook Installation

`/intent-init` installs pre-push hook that warns when pushing code changes without updating affected AGENTS.md files.

---

## Skill Definitions

### `intent-chunk`

```markdown
---
name: intent-chunk
description: Analyze codebase and generate capture plan
---

Analyze codebase for intent layer capture.

Target: $ARGUMENTS (default: project root)

## Process

1. Walk directory tree
2. Calculate token count per directory (code files only)
3. Identify semantic boundaries:
   - Package manifests (package.json, go.mod, Cargo.toml, pyproject.toml)
   - Domain directories (services/, api/, domain/, lib/, pkg/)
   - Significant code mass (20k-64k tokens ideal)
   - Where responsibilities shift, contracts matter, complexity warrants context
4. Skip: node_modules, .git, dist, build, vendor, __pycache__, .venv
5. Determine leaf-first capture order (easy areas first)

## Output

Show:
- Directory tree with token counts
- Proposed capture order (leaf → root)
- Total nodes to capture

Ask user to confirm plan before proceeding.
```

### `intent-capture`

```markdown
---
name: intent-capture
description: Interactively capture intent node for directory
---

Capture intent node for: $ARGUMENTS

## 1. Read

IF leaf (no child AGENTS.md):
  Read all code files in target directory.

IF parent (has child AGENTS.md):
  Read child AGENTS.md files ONLY — fractal compression.
  Note any Open Questions in children.

## 2. Interview

FIRST describe observations:
- "This appears to handle X..."
- "I see Y calling Z, which suggests..."

THEN ask clarifying questions based on analysis:
- "What triggers X?"
- "Any invariants enforced only by DB/external system?"
- "Is Y deprecated?"
- "Feature flags or conditional paths?"
- "Historical context / landmines?"

Scale interview depth with complexity — skip for trivial modules.
Wait for answers. Iterate until aligned.

Track in shared state:
- Open questions for later chunks
- Cross-references for LCA decisions
- Refactor opportunities

## 3. Generate

Create AGENTS.md with sections:
- Purpose & Scope (owns X, does NOT own Y)
- Entry Points & Contracts
- Dependencies
- Usage Patterns
- Anti-Patterns
- Downlinks (if has children)
- Outlinks (external docs, ADRs)
- Patterns & Pitfalls
- Open Questions (if unresolved)
- Pending Tasks (if refactors found)

Target: 1-3k tokens. Dense, high-signal.

## 4. LCA Resolution (parent nodes)

For each child Open Question:
- Answerable here? → Include answer, remove from child
- Still unresolved? → Add to this node's Open Questions
- Belongs higher? → Leave for next ancestor

Update child AGENTS.md files to remove resolved items.

## 5. Confirm & Write

Show generated content.
Confirm with user.
Write AGENTS.md.
Report: tokens, items resolved, questions remaining.
```

---

## Command Definitions

### `/intent-init`

```markdown
---
name: intent-init
description: Bootstrap intent layer for project
agent: build
---

Bootstrap complete intent layer hierarchy.

## Process

1. Run @intent-chunk — analyze and show capture plan
2. Confirm plan with user
3. For each node in leaf-first order:
   - Run @intent-capture
   - Show progress: [X/N] capturing /path/
4. Install pre-push git hook
5. Final summary:
   - Nodes created
   - Total tokens
   - Remaining Open Questions
   - Pending Tasks discovered
   - Hook installed confirmation

## Hook Content

Write to .git/hooks/pre-push:

#!/bin/bash
CHANGED=$(git diff --name-only @{push}.. 2>/dev/null || git diff --name-only origin/HEAD..HEAD 2>/dev/null)
[ -z "$CHANGED" ] && exit 0

STALE=""
while IFS= read -r file; do
  [[ "$file" == *AGENTS.md ]] && continue
  dir=$(dirname "$file")
  while [ "$dir" != "." ]; do
    [ -f "$dir/AGENTS.md" ] && ! echo "$CHANGED" | grep -qx "$dir/AGENTS.md" && STALE="$STALE$dir\n" && break
    dir=$(dirname "$dir")
  done
done <<< "$CHANGED"

STALE=$(echo -e "$STALE" | sort -u | grep .)
[ -z "$STALE" ] && exit 0

echo "Intent nodes may need refresh:"
echo -e "$STALE"
read -p "Run /intent-sync? [Y/n] " -r
[[ $REPLY =~ ^[Nn]$ ]] && exit 1

opencode -p "/intent-sync"

echo "Sync complete. Run 'git push' again."
exit 1

Make executable: chmod +x .git/hooks/pre-push
```

### `/intent-capture`

```markdown
---
name: intent-capture
description: Capture single intent node
agent: build
---

Run @intent-capture for: $ARGUMENTS (default: current directory)
```

### `/intent-sync`

```markdown
---
name: intent-sync
description: Sync intent nodes after code changes
agent: build
---

Refresh intent nodes affected by recent changes.

## Process

1. Get changed files:
   git diff --name-only @{push}.. 2>/dev/null || git diff --name-only origin/HEAD..HEAD

2. For each changed file (excluding AGENTS.md):
   - Find nearest ancestor AGENTS.md
   - Collect unique affected directories

3. Sort affected nodes leaf-first

4. For each affected node:
   - Re-run @intent-capture
   - Show diff
   - Confirm before writing

5. Summary: nodes refreshed, questions resolved/added
```

---

## T-Shaped Context Loading

OpenCode automatically loads ancestor AGENTS.md files:

```
When agent works in /services/payment/validators/:

LOADED (automatic):
  /AGENTS.md                           (root)
  /services/AGENTS.md                  (ancestor)
  /services/payment/AGENTS.md          (ancestor)
  /services/payment/validators/AGENTS.md (target)

NOT LOADED:
  /services/billing/AGENTS.md          (sibling branch)
  /services/payment/settlement/AGENTS.md (sibling)
```

Siblings accessible via ancestor downlinks (progressive disclosure).

---

## LCA (Least Common Ancestor) Pattern

Shared facts live at shallowest node where always relevant:

```
Problem: shared-types.ts used by payment/ AND billing/

        ┌─────────┐
        │  ROOT   │  ← shared-types docs go HERE (LCA)
        └────┬────┘
             │
     ┌───────┴───────┐
     ▼               ▼
┌─────────┐    ┌─────────┐
│ payment │    │ billing │
└─────────┘    └─────────┘
```

**Why LCA matters**:
1. **No duplication** — fact exists once
2. **Loads when needed** — both consumers get via ancestor loading
3. **No drift** — single source of truth
4. **Doesn't over-load** — won't appear for unrelated paths

During parent capture:
- Read child Open Questions
- Resolve what belongs at this level
- Remove from children after resolving

---

## Reinforcement Loop

Agents surface missing context through usage:
- Code ↔ node contradictions
- Undocumented patterns
- Refined pitfalls
- Dead code candidates

Feed discoveries back → `/intent-sync` or manual update.

Codebase becomes reinforcement learning environment. Agents improve through better context, not model training.

---

## Capture Order Example

```
Codebase:
enterprise-platform/
├── services/
│   ├── payment/
│   │   └── settlement/
│   └── billing/
└── platform-config/

Capture order (leaf-first, easy-first):
1. /platform-config/               (leaf, likely simple)
2. /services/payment/settlement/   (leaf)
3. /services/billing/              (leaf)
4. /services/payment/              (parent)
5. /services/                      (parent)
6. /                               (root)
```

---

## Anti-Patterns (Build Process)

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Dumping everything in root | 15k+ tokens, overwhelms context | Hierarchical decomposition |
| Force-combining disparate code | Poor compression, muddy summaries | Group by shared responsibility |
| Duplicating facts in multiple leaves | Drift, wasted tokens | Use LCA placement |
| Vague purpose statements | Doesn't narrow agent scope | Be specific: owns X, not Y |
| Skipping interview for complex areas | Missing tribal knowledge | Interview scales with complexity |
| Capturing hard areas first | Context not yet accumulated | Easy first, hard last |

---

## Investment & Payoff

### Time Investment

| Codebase Size | Estimated Time |
|---------------|----------------|
| 100k tokens | 3-5 hours (experienced) |
| 100k tokens | 6-15 hours (first-time) |
| 500k tokens | 15-25 hours (with patterns) |

### Payoff

**Individual**:
- Agents behave like senior engineers
- ~50% effectiveness improvement
- Hard-won explanations reused forever

**Team**:
- Enable longer tasks and parallel agents
- New members productive faster
- Context compounds across all interactions

**Maintenance**: ~5-10 min/PR manual, or automate via `/intent-sync`

---

## Implementation Phases

### Phase 1: Skills
- [ ] `intent-chunk` skill — tree analysis, token counting, ordering
- [ ] `intent-capture` skill — interview, generation, LCA resolution
- [ ] AGENTS.md template

### Phase 2: Commands
- [ ] `/intent-capture` — single node
- [ ] `/intent-init` — full bootstrap + hook install
- [ ] `/intent-sync` — maintenance

### Phase 3: Polish
- [ ] Resume support (detect existing nodes, skip completed)
- [ ] Edge cases (monorepo, deep trees)

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| No lateral deps section | Ancestors expose via downlinks |
| Open Questions in nodes | Visible in code review, resolve via LCA |
| Pre-push hook (not post-merge) | Changes in PR review |
| Sequential capture | Simpler state management |
| Interview = conversation | No special UI, leverage OpenCode naturally |
| Idempotent regeneration | Same input → same output |
| 1-3k token target | Dense, high-signal nodes |
| Easy areas first | Clarity compounds |
| Agent describes first | Correcting is faster than explaining |

---

## References

- [Intent Layer Concept](https://www.intent-systems.com/learn/intent-layer)
- [OpenCode Docs](https://opencode.ai/docs)
- [OpenCode Skills](https://opencode.ai/docs/skills)
- [OpenCode Commands](https://opencode.ai/docs/commands)
