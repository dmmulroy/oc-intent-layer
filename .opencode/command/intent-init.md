---
description: Bootstrap complete intent layer hierarchy with pre-push hook
---

Bootstrap complete intent layer for this project.

## Phase 0: Install Dependencies

Before starting, ensure all required components are available.

### Check & Install Skills

```
Checking intent layer dependencies...
```

**Locate installation directory:**
```bash
# Find where oc-intent-layer is installed
INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/oc-intent-layer"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
```

**Link skills if not present:**
```bash
# Check for intent-chunk skill
if [ ! -d "$CONFIG_DIR/skill/intent-chunk" ]; then
  mkdir -p "$CONFIG_DIR/skill"
  ln -s "$INSTALL_DIR/.opencode/skill/intent-chunk" "$CONFIG_DIR/skill/intent-chunk"
fi

# Check for intent-capture skill  
if [ ! -d "$CONFIG_DIR/skill/intent-capture" ]; then
  ln -s "$INSTALL_DIR/.opencode/skill/intent-capture" "$CONFIG_DIR/skill/intent-capture"
fi
```

**Link other commands if not present:**
```bash
# intent-capture command
if [ ! -f "$CONFIG_DIR/command/intent-capture.md" ]; then
  ln -s "$INSTALL_DIR/.opencode/command/intent-capture.md" "$CONFIG_DIR/command/intent-capture.md"
fi

# intent-sync command
if [ ! -f "$CONFIG_DIR/command/intent-sync.md" ]; then
  ln -s "$INSTALL_DIR/.opencode/command/intent-sync.md" "$CONFIG_DIR/command/intent-sync.md"
fi
```

### Check tiktoken Availability

Token counting is more accurate with tiktoken. Check availability:

**Check for tiktoken:**
```bash
# Try npx js-tiktoken first (preferred - no install needed)
if echo "test" | npx js-tiktoken --encoding o200k_base 2>/dev/null; then
  echo "tiktoken: npx js-tiktoken available"
  TIKTOKEN_METHOD="npx"
# Try Python tiktoken
elif python3 -c "import tiktoken; print(len(tiktoken.get_encoding('o200k_base').encode('test')))" 2>/dev/null; then
  echo "tiktoken: Python tiktoken available"
  TIKTOKEN_METHOD="python"
else
  echo "tiktoken: Not available, will use estimation"
  TIKTOKEN_METHOD="estimated"
fi
```

**If tiktoken unavailable, warn and continue:**
```bash
if [ "$TIKTOKEN_METHOD" = "estimated" ]; then
  echo ""
  echo "⚠️  tiktoken not available via npx or python."
  echo "Token counts will use estimation (bytes/4) which has ~20% variance."
  echo ""
  echo "For more accurate counts, install Python tiktoken:"
  echo "  pip3 install tiktoken"
  echo ""
  echo "Or ensure npx is available (comes with npm/node)."
  echo ""
fi
```

**Report token counting method:**
```
Dependencies Ready
══════════════════
Skills:      ✓ intent-chunk, intent-capture
Commands:    ✓ intent-capture, intent-sync  
tiktoken:    [✓ available via npx | ✓ available via python | ⚠ using estimation]

Proceeding with intent layer bootstrap...
```

**If using estimation, note the warning:**
```
⚠️  Token counts will use bytes/4 estimation (~20% variance)
   Node boundaries may be suboptimal. Consider installing tiktoken later.
```

## Phase 1: Analyze & Plan

Run @intent-chunk to analyze codebase and generate capture plan.

This includes:
- **Audit existing AGENTS.md files**: Classify as intent nodes (skip) or legacy (extract & replace)
- **Token analysis**: Calculate ACTUAL code mass per directory using tiktoken
- **Boundary detection**: Identify semantic boundaries for intent nodes
- **Node count optimization**: Apply heuristics based on real token counts
- **Legacy mapping**: Map legacy content to target nodes
- **Capture ordering**: Leaf-first, easy-first sequence

**Node count heuristics (based on ACTUAL token counts):**

| Total Repo Tokens | Recommended Nodes | Reasoning |
|-------------------|-------------------|-----------|
| < 20k | 1 (root only) | Below compression threshold |
| 20k-64k | 1-2 | Single node ideal, maybe split if clear boundary |
| 64k-150k | 2-4 | Split at major semantic boundaries |
| 150k-500k | 4-8 | Hierarchical decomposition |
| > 500k | 8+ | Full tree structure |

**Per-node thresholds:**
- < 10k tokens: Consider merging with parent (unless package manifest)
- 20k-64k tokens: Ideal single node
- > 100k tokens: Should have children

Present the plan and ask user to confirm before proceeding.

**If legacy files found:**
```
Found [N] legacy AGENTS.md files that will be processed:

  ./AGENTS.md (project instructions)
    → Will extract: build instructions, project overview
    → Will replace with: root intent node
    
  ./api/AGENTS.md (hand-written docs)
    → Will extract: endpoint docs, auth notes
    → Will replace with: ./api/ intent node

Legacy content will be incorporated during discovery pass.

Proceed? [y/n]
```

## Phase 2: Discovery Pass (Agentic)

For each node in the confirmed leaf-first order, run @intent-capture in **discovery mode**:

```
Discovery Pass: Analyzing [N] nodes...
══════════════════════════════════════
```

**Discovery mode behavior:**
- Read all code files (or child AGENTS.md for parent nodes)
- Generate draft AGENTS.md with best-effort content
- Self-answer questions where code provides clear answers
- Collect questions that genuinely need SME input
- Perform LCA analysis across all discovered questions
- Do NOT prompt user during this phase

For each node:
```
[X/N] Discovering /path/to/directory/ (~Xk tokens)
      → Draft generated, 3 questions for SME
```

**Track discovery state:**
```
DISCOVERY_STATE:
├── draft_nodes:
│   ├── ./lib/utils/
│   │   ├── draft_content: "..."
│   │   ├── confidence: high
│   │   └── questions: []
│   ├── ./services/payment/
│   │   ├── draft_content: "..."
│   │   ├── confidence: medium
│   │   └── questions: ["Is retry logic owned here or by caller?"]
├── lca_analysis:
│   ├── resolved_at_parent: ["shared-types ownership" → ./services/]
│   └── needs_sme: ["retry policy decision"]
├── cross_references:
│   ├── ./lib/utils/ referenced by: [./services/payment/, ./api/]
└── total_questions: 5
```

**Discovery pass completion:**
```
Discovery Pass Complete
═══════════════════════

Nodes analyzed: [N]
Draft nodes generated: [N]
  High confidence: [X] (ready to write)
  Medium confidence: [Y] (questions for SME)
  Low confidence: [Z] (needs discussion)

Questions for SME: [M]
LCA resolutions: [L] questions answered by cross-node analysis

Proceeding to consolidated interview...
```

## Phase 3: Consolidated Interview

Present ALL remaining questions to user in a single session:

```
Intent Layer Interview
══════════════════════

I've analyzed your codebase and generated draft intent nodes.
[M] questions need your input to finalize.

Questions by topic:
───────────────────

OWNERSHIP & SCOPE
1. [./services/payment/] Does this own retry logic, or do callers handle retries?
2. [./lib/utils/] The date formatting functions - are these deprecated in favor of a library?

CONTRACTS & INVARIANTS  
3. [./api/handlers/] Is there a max request size enforced here or at the gateway?

HISTORY & GOTCHAS
4. [./services/billing/] Why is there both invoice.ts and legacy_invoice.ts?
5. [root] The "always use yarn" rule in existing AGENTS.md - still relevant?

Answer each, or type:
  skip    → Add to Open Questions (resolve later)
  n/a     → Not applicable, remove from draft
  <text>  → Your answer

─────────────────────────────────────────────────
Q1/5: [./services/payment/] Does this own retry logic, or do callers handle retries?
> 
```

**Interview flow:**
- Present questions grouped by topic
- User can answer, skip, or mark n/a
- Answers immediately incorporated into draft nodes
- Skipped questions become Open Questions in relevant node

After all questions:
```
Interview Complete
══════════════════

Questions answered: [A]
Questions skipped: [S] (added to Open Questions)
Questions removed: [R]

Ready to generate final intent nodes.
```

## Phase 4: Generate & Finalize

Apply interview answers to draft nodes and generate final AGENTS.md files:

```
Generating Final Intent Nodes
═════════════════════════════
```

For each node:
```
[X/N] Finalizing /path/to/directory/
      → Applying 2 interview answers
      → Final: ~1.2k tokens
```

**Show all generated nodes for review:**
```
Generated Intent Nodes
══════════════════════

[1/N] ./lib/utils/AGENTS.md (~800 tokens)
──────────────────────────────────────────
# Utils Library
## Purpose & Scope
...
[truncated preview - first 10 lines]
──────────────────────────────────────────

[2/N] ./services/payment/AGENTS.md (~1.5k tokens)
──────────────────────────────────────────
# Payment Service
## Purpose & Scope
...
──────────────────────────────────────────

...

Write all [N] nodes? [y/n/review]
```

Options:
- **y**: Write all nodes
- **n**: Abort without writing
- **review**: Show full content of specific node(s)

If review:
```
Enter node numbers to review (comma-separated):
> 2,3
```

## Phase 5: Install Pre-Push Hook

Write to `.git/hooks/pre-push`:

```bash
#!/bin/bash
# Intent Layer freshness check
# Installed by /intent-init

CHANGED=$(git diff --name-only @{push}.. 2>/dev/null || git diff --name-only origin/HEAD..HEAD 2>/dev/null)
[ -z "$CHANGED" ] && exit 0

STALE=""
while IFS= read -r file; do
  [[ "$file" == *AGENTS.md ]] && continue
  dir=$(dirname "$file")
  while [ "$dir" != "." ]; do
    if [ -f "$dir/AGENTS.md" ]; then
      if ! echo "$CHANGED" | grep -qx "$dir/AGENTS.md"; then
        STALE="$STALE$dir\n"
      fi
      break
    fi
    dir=$(dirname "$dir")
  done
done <<< "$CHANGED"

STALE=$(echo -e "$STALE" | sort -u | grep .)
[ -z "$STALE" ] && exit 0

echo ""
echo "⚠️  Intent nodes may need refresh:"
echo -e "$STALE" | while read -r dir; do echo "   $dir/AGENTS.md"; done
echo ""
echo "Run: /intent-sync"
echo ""
read -p "Push anyway? [y/N] " -r
[[ $REPLY =~ ^[Yy]$ ]] && exit 0
exit 1
```

Make executable: `chmod +x .git/hooks/pre-push`

## Phase 6: Final Summary

```
Intent Layer Bootstrap Complete
═══════════════════════════════

Nodes created: [N]
Total tokens: ~[X]k across all nodes
Token counting: [tiktoken method used]

Legacy files processed: [L]
  [list paths replaced]

Open Questions remaining: [M]
  [list top 3-5 if any]

Pending Tasks discovered: [P]
  [list top 3-5 if any]

Pre-push hook: ✓ installed

Commands now available:
  /intent-capture [path]  Capture/update single node
  /intent-sync            Sync nodes after code changes

Next steps:
• Review generated AGENTS.md files
• Resolve remaining Open Questions via /intent-capture on parent nodes
• Address Pending Tasks as technical debt
• Hook will warn when pushing changes without AGENTS.md updates
```

## Resume Support

State persistence is implicit—AGENTS.md files themselves ARE the state:

**On resume (re-running `/intent-init` after interruption):**

1. Re-run `@intent-chunk` to get full capture plan
2. For each node in the plan, check if AGENTS.md exists:
   - **Has intent node structure** → Skip (already captured)
   - **Has legacy structure** → Process as planned (extract & replace)
   - **No AGENTS.md** → Capture normally
3. Report: "Resuming—[N] nodes already captured, [M] remaining"
4. Continue with remaining nodes in leaf-first order

**Why this works:**
- Completed captures write AGENTS.md immediately
- The classification algorithm distinguishes our nodes from legacy
- No separate state file needed—the filesystem is the checkpoint

**To force re-capture** of a completed node:
```
/intent-capture ./path/to/directory/
```
This will show the existing node and ask to overwrite.

## Legacy File Handling

When existing AGENTS.md files are found that don't match intent node structure:

1. **Audit phase** classifies each as intent node vs legacy
2. **Legacy content extracted** during discovery pass
3. **During interview**, legacy content is:
   - Summarized for validation ("Is this still accurate?")
   - Incorporated into new intent node where relevant
4. **Legacy file replaced** with new intent node

**Root AGENTS.md with agent instructions:**
- Common pattern: existing root has project-level agent rules
- Migration options presented during interview:
  - Keep in Patterns & Pitfalls section
  - Move to `.opencode/agent.md`
  - Discard if obsolete

**Boundary misalignment:**
- Legacy file at location that isn't a semantic boundary
- Content lifts to nearest ancestor that IS a boundary
- User notified during audit phase
