---
name: intent-chunk
description: Analyze codebase structure, calculate token budgets, output leaf-first capture order for intent layer bootstrap
---

Analyze codebase for intent layer capture.

Target: $ARGUMENTS (default: project root)

## Process

### 0. Determine Token Counting Method

**IMPORTANT: You MUST actually attempt tiktoken before falling back to estimation.**

Try each method IN ORDER and use the first that succeeds:

**Step 1 - Try npx js-tiktoken:**
```bash
# Actually run this command - don't skip it
echo "test content" | npx js-tiktoken --encoding o200k_base 2>/dev/null
```
If this returns a number, use `TIKTOKEN_METHOD=npx`

**Step 2 - Try Python tiktoken:**
```bash
# Actually run this command - don't skip it
python3 -c "import tiktoken; enc=tiktoken.get_encoding('o200k_base'); print(len(enc.encode('test')))" 2>/dev/null
```
If this prints a number, use `TIKTOKEN_METHOD=python`

**Step 3 - Fall back to estimation (last resort):**
Only if BOTH above methods failed, use `TIKTOKEN_METHOD=estimated`

**Report which method will be used:**
```
Token Counting Method
═════════════════════
Tried npx js-tiktoken: [✓ available | ✗ not available]
Tried Python tiktoken: [✓ available | ✗ not available]
Using: [tiktoken via npx | tiktoken via python | estimation (bytes/4)]
```

**If using estimation, warn about accuracy:**
```
⚠️  WARNING: Using bytes/4 estimation (tiktoken unavailable)
   Token counts may be ~20% inaccurate.
   Node boundary decisions may be suboptimal.
   
   For accurate counts:
     - Ensure npx is available (comes with npm/node)
     - Or install Python tiktoken: pip3 install tiktoken
```

Set the method for use in later steps:
```
TIKTOKEN_METHOD: [npx|python|estimated]
```

### 1. Audit Existing AGENTS.md Files

Before analyzing structure, find and classify ALL existing AGENTS.md files.

**Find all AGENTS.md:**
```bash
find [target] -name "AGENTS.md" -type f
```

**Classify each file** by reading content and checking structure:

| Classification | Detection | Action |
|----------------|-----------|--------|
| **Intent Node** | Has `## Purpose & Scope` AND at least one of: `## Downlinks`, `## Entry Points`, `## Open Questions` | Skip during capture (already ours) |
| **Legacy Docs** | Any other AGENTS.md | Extract content, will replace |

**Classification logic:**
```
is_intent_node(content):
  has_purpose = "## Purpose & Scope" in content
  has_structure = any([
    "## Downlinks" in content,
    "## Entry Points" in content,
    "## Open Questions" in content,
    "## Anti-Patterns" in content
  ])
  return has_purpose AND has_structure
```

**For legacy files, extract valuable content:**
- Warnings and gotchas
- Historical context  
- Dependency notes
- Usage examples
- Any tribal knowledge
- Project instructions or agent directives

Store extracted content in session state—will feed into discovery pass.

**Check boundary alignment:**
For each legacy file, note whether its location aligns with a semantic boundary:
- Aligned: Legacy file will be replaced with new intent node at same location
- Misaligned: Legacy content will lift to nearest ancestor boundary

**Present audit summary:**

```
Existing AGENTS.md Audit
════════════════════════

Intent Nodes (will preserve):
  ./services/payment/AGENTS.md    (~2.1k tokens)
  ./lib/validators/AGENTS.md      (~1.8k tokens)

Legacy Files (will extract & replace):
  ./AGENTS.md                     (project instructions, root)
    → Contains: build instructions, project overview, agent rules
    → Action: Extract for root node capture
    
  ./api/AGENTS.md                 (hand-written docs)
    → Contains: endpoint list, auth notes
    → Action: Extract for ./api/ node capture
    
  ./utils/helpers/AGENTS.md       (basic readme)
    → Contains: brief description
    → Location: NOT at semantic boundary (2k tokens)
    → Action: Extract, lift to ./utils/ node

Legacy files to process: 3
Intent nodes to skip: 2

Options for each legacy file:
  [R] Replace - extract content, create new intent node
  [S] Skip - keep as-is, no intent node here  
  [M] Manual - review content before deciding

Default: Replace all with extraction

Proceed with audit results? [y/n/configure]
```

**Store in session state:**
```
AUDIT_STATE:
├── intent_nodes: [paths to skip]
├── legacy_files:
│   ├── path: ./AGENTS.md
│   │   ├── classification: legacy
│   │   ├── extracted_content: "..."
│   │   ├── boundary_aligned: true
│   │   └── target_node: ./
│   ├── path: ./api/AGENTS.md
│   │   └── ...
└── user_decisions: {path: action}
```

### 2. Walk Directory Tree

Recursively traverse from target, collecting:
- Directory paths
- Code file counts per directory
- Token counts per directory (code files only) **[MUST use tiktoken]**

**Skip directories:**
- `node_modules`, `.git`, `dist`, `build`, `vendor`
- `__pycache__`, `.venv`, `venv`, `.env`
- `.next`, `.nuxt`, `coverage`, `.cache`
- Any directory starting with `.` except `.opencode`

**Code file extensions:**
- JS/TS: `.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs`
- Python: `.py`
- Go: `.go`
- Rust: `.rs`
- Java/Kotlin: `.java`, `.kt`
- C/C++: `.c`, `.cpp`, `.h`, `.hpp`
- Ruby: `.rb`
- PHP: `.php`
- Shell: `.sh`, `.bash`
- Config as code: `.yaml`, `.yml`, `.json`, `.toml` (only if significant logic)

### 3. Calculate Token Counts

**Use the method determined in Step 0. Always indicate which method was used.**

**If TIKTOKEN_METHOD=npx:**
```bash
# Count tokens for a file
cat <file> | npx js-tiktoken --encoding o200k_base
```

**If TIKTOKEN_METHOD=python:**
```python
import tiktoken
enc = tiktoken.get_encoding("o200k_base")
with open(filepath) as f:
    tokens = len(enc.encode(f.read()))
```

**If TIKTOKEN_METHOD=estimated (fallback only):**
```bash
# Rough estimation - only use if tiktoken unavailable
wc -c <file> | awk '{print int($1/4)}'
```

**Encoding reference:**
| Encoding | Models |
|----------|--------|
| `o200k_base` | GPT-4o, GPT-4o-mini, Claude (recommended) |
| `cl100k_base` | GPT-4, GPT-3.5-turbo, embeddings |

**Always note which method was used in output:**
```
Token counting: [tiktoken (o200k_base) via npx | tiktoken (o200k_base) via python | estimated (bytes/4)]
```

For each directory, sum tokens of all code files (non-recursive—direct children only for leaf identification).

### 4. Identify Semantic Boundaries

A directory becomes an intent node candidate when ANY of:

**Package manifest present:**
- `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`
- `setup.py`, `pom.xml`, `build.gradle`

**Domain directory name:**
- `services/`, `api/`, `domain/`, `lib/`, `pkg/`
- `handlers/`, `controllers/`, `models/`, `utils/`
- `core/`, `internal/`, `cmd/`, `src/`

**Significant code mass:**
- 20k-64k tokens ideal (best compression ratio)
- <10k tokens: **MERGE with parent** (unless package manifest)
- >100k tokens: likely needs child nodes

**Responsibility shift indicators:**
- README or docs in directory
- Distinct naming conventions
- Clear module boundary

### 5. Apply Node Count Heuristics

**Based on TOTAL repository token count, recommend node structure:**

| Total Tokens | Recommended Nodes | Strategy |
|--------------|-------------------|----------|
| < 20k | 1 | Root only—below compression threshold |
| 20k-64k | 1-2 | Single root, or root + 1 major module |
| 64k-150k | 2-4 | Root + major semantic boundaries |
| 150k-500k | 4-8 | Hierarchical decomposition |
| > 500k | 8+ | Full tree, possibly monorepo treatment |

**Apply merge rule aggressively:**
- If a candidate node has < 10k tokens AND no package manifest → merge into parent
- If merging would create a node > 64k tokens → keep separate
- If clear semantic boundary (different language, different responsibility) → keep separate

**Example heuristic application:**
```
Total repo: 35k tokens

Initial candidates:
  ./lib/utils/     2k tokens  → MERGE (too small)
  ./services/api/  8k tokens  → MERGE (too small)
  ./config/        500 tokens → MERGE (too small)
  ./              24k tokens

After merge:
  ./              35k tokens (single node)

Recommendation: 1 node (root only)
```

### 6. Determine Capture Order

**Principle:** Leaf-first, easy-first.

1. Identify all leaf candidates (no child intent nodes)
2. **Exclude intent nodes found in audit** (already captured)
3. **Include legacy locations** if at semantic boundaries (will replace)
4. **Apply merge heuristics** - remove candidates below threshold
5. Sort leaves by estimated complexity (simpler first):
   - Fewer files = simpler
   - Smaller token count = simpler
   - Utils/helpers before core domain
6. After leaves, capture parents in bottom-up order
7. Root node captured last

**Why leaf-first:**
- Parents summarize child AGENTS.md, not code
- Context compounds—simple areas illuminate complex ones
- Open questions resolve during parent capture

### 7. Map Legacy Content to Nodes

For each legacy file from audit:

**If boundary-aligned:**
- Legacy file location matches a capture node
- Tag that node: "has legacy content"
- Content feeds into that node's capture

**If NOT boundary-aligned:**
- Find nearest ancestor that IS a capture node
- Tag ancestor: "inherits legacy from [path]"
- Content lifts to ancestor's capture

Example:
```
Legacy: ./utils/helpers/AGENTS.md (2k tokens, not a boundary)
Nearest boundary: ./utils/ (25k tokens, IS a boundary)
→ ./utils/ tagged with legacy content from ./utils/helpers/
```

### 8. Handle Edge Cases

**Monorepo:** Each independent project gets separate capture pass. Identify by:
- Multiple package manifests at same depth
- Independent CI configs
- No code imports between areas

**Deep trees (>4 levels):** Collapse middle layers if token counts allow. Parent can summarize grandchildren if intermediate layer adds no semantic value.

**Sparse directories:** Skip directories with <5 code files AND <2k tokens unless package manifest present.

**Legacy AGENTS.md at root with agent instructions:**
Common case—OpenCode users often have root AGENTS.md with project-level instructions.
- Extract architectural content → new root intent node
- Extract agent behavior rules → suggest moving to `.opencode/agent.md` or preserve in Patterns & Pitfalls
- Present migration plan to user before proceeding

## Output Format

Present to user:

```
Intent Layer Capture Plan
═════════════════════════

Target: [path]
Token counting: tiktoken (o200k_base) via [method]
Total code tokens: [N]k [tiktoken]
Proposed nodes: [M]

Existing AGENTS.md:
───────────────────
Intent nodes (skip): [X]
  ./services/payment/AGENTS.md
Legacy files (replace): [Y]
  ./AGENTS.md → extract & replace
  ./api/AGENTS.md → extract & replace

Directory Tree (with token counts):
───────────────────────────────────
[tree view with token counts, marking nodes with legacy content]

Node Count Recommendation:
──────────────────────────
Total tokens: [N]k → [M] nodes recommended
Merged candidates: [list any directories merged due to size]

Capture Order (leaf → root):
────────────────────────────
1. /path/to/module/          (~Xk tokens) [tiktoken] - [reason]
2. /api/                     (~Yk tokens) [tiktoken] - [reason] ◀ has legacy
...
N. /                         (summarizes children) ◀ has legacy

Skipped (below threshold):
──────────────────────────
- /path/tiny/  (800 tokens, merged into parent)

Legacy content lifting:
───────────────────────
- ./utils/helpers/AGENTS.md → lifts to ./utils/

⚠️  Potential issues:
- [any warnings about large directories, unclear boundaries]
- [legacy files at unexpected locations]
```

Then ask: "Proceed with this capture plan? [y/n/modify]"

## Notes

- **Always TRY tiktoken first** (npx, then python) before falling back to estimation
- If using estimation, warn user about potential inaccuracy
- User can modify order before confirming
- Intent nodes (proper structure) are skipped—already captured
- Legacy AGENTS.md are extracted and replaced with new intent nodes
- This skill only plans—actual capture uses @intent-capture
- Node count heuristics prevent creating too many small nodes
