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

**Step 1 - Try Node.js tiktoken (requires `npm install -g tiktoken`):**
```bash
# Actually run this command - don't skip it
NODE_PATH=$(npm root -g) node -e "
const { get_encoding } = require('tiktoken');
const enc = get_encoding('o200k_base');
console.log(enc.encode('test').length);
enc.free();
" 2>/dev/null
```
If this prints a number, use `TIKTOKEN_METHOD=node`

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
Tried Node.js tiktoken: [✓ available | ✗ not available]
Tried Python tiktoken: [✓ available | ✗ not available]
Using: [tiktoken via node | tiktoken via python | estimation (bytes/4)]
```

**If using estimation, warn about accuracy:**
```
⚠️  WARNING: Using bytes/4 estimation (tiktoken unavailable)
   Token counts may be ~20% inaccurate.
   Node boundary decisions may be suboptimal.
   
   For accurate counts:
     - Install Node.js tiktoken: npm install -g tiktoken
     - Or install Python tiktoken: pip3 install tiktoken
```

Set the method for use in later steps:
```
TIKTOKEN_METHOD: [node|python|estimated]
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

**If TIKTOKEN_METHOD=node:**
```bash
# Count tokens for a file using Node.js tiktoken
NODE_PATH=$(npm root -g) node -e "
const fs = require('fs');
const { get_encoding } = require('tiktoken');
const enc = get_encoding('o200k_base');
const content = fs.readFileSync('$FILE', 'utf8');
console.log(enc.encode(content).length);
enc.free();
"
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
Token counting: [tiktoken (o200k_base) via node | tiktoken (o200k_base) via python | estimated (bytes/4)]
```

For each directory, sum tokens of all code files (non-recursive—direct children only for leaf identification).

### 4. Identify Semantic Boundaries

A directory becomes an intent node candidate when ANY of:

**Package manifest present:**
- `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`
- `setup.py`, `pom.xml`, `build.gradle`

**IMPORTANT: Package manifest indicates semantic boundary, NOT "single node".**
A package with 2M tokens still needs ~40 internal child nodes. The manifest location becomes a PARENT node if children exist.

**Domain directory name:**
- `services/`, `api/`, `domain/`, `lib/`, `pkg/`
- `handlers/`, `controllers/`, `models/`, `utils/`
- `core/`, `internal/`, `cmd/`, `src/`

**Significant code mass:**
- 20k-64k tokens ideal (best compression ratio)
- <10k tokens: **MERGE with parent** (unless package manifest)
- >64k tokens: **MUST recurse into subdirectories**
- >100k tokens: **MUST have child nodes** (hard constraint)

**Responsibility shift indicators:**
- README or docs in directory
- Distinct naming conventions
- Clear module boundary

### 5. Apply Recursive Decomposition (MANDATORY)

**This algorithm is NOT optional. Apply it to EVERY directory >64k tokens.**

```
analyze(dir):
  tokens = count_tokens(dir)  # recursive total
  
  if tokens < 10k AND no_package_manifest(dir):
    return MERGE_INTO_PARENT
  
  if tokens <= 64k:
    return LEAF_NODE(dir)
  
  # tokens > 64k: MUST decompose further
  children = []
  for subdir in get_subdirectories(dir):
    result = analyze(subdir)
    if result != MERGE_INTO_PARENT:
      children.append(result)
  
  # If no valid children found but dir is >64k,
  # it becomes a leaf anyway (code is flat)
  if len(children) == 0:
    return LEAF_NODE(dir)  # flag as oversized if >100k
  
  # This directory becomes a PARENT node
  return PARENT_NODE(dir, children)
```

**Hard constraints:**
- NO leaf node may cover >100k source tokens
- Directories >64k tokens MUST recurse (not optional)
- Keep recursing until ALL leaves are in 10k-64k range (or smallest possible)

**Example recursive decomposition:**
```
packages/effect/ (2,538k tokens)
├── src/ (997k) → too big, recurse
│   ├── internal/ (454k) → too big, recurse
│   │   ├── stm/ (67k) → LEAF NODE ✓
│   │   ├── channel/ (20k) → LEAF NODE ✓
│   │   ├── metric/ (13k) → LEAF NODE ✓
│   │   ├── effect/ (8k) → merge candidate
│   │   └── ...
│   └── [other src subdirs...]
├── test/ (349k) → too big, recurse
│   ├── Schema/ (91k) → too big, recurse further
│   ├── Stream/ (73k) → LEAF NODE ✓
│   └── Effect/ (66k) → LEAF NODE ✓
└── dtslint/ (78k) → LEAF NODE ✓

Result: ~50 leaf nodes, not 1
```

### 6. Apply Node Count Heuristics

**Expected node counts based on ~50k tokens per leaf (middle of optimal range):**

| Total Tokens | Expected Leaves | Expected Total | Notes |
|--------------|-----------------|----------------|-------|
| <20k | 1 | 1 | Root only |
| 20k-64k | 1 | 1 | Single optimal node |
| 64k-200k | 2-4 | 3-6 | Root + leaves |
| 200k-500k | 4-10 | 8-15 | 2-level tree |
| 500k-2M | 10-40 | 20-60 | 3-level tree |
| 2M-10M | 40-200 | 60-300 | Deep hierarchy |
| >10M | 200+ | 300+ | Large monorepo |

**Sanity check formula:** `expected_leaves ≈ total_tokens / 50k`

If your plan has significantly fewer nodes than this formula suggests, you have NOT recursed deeply enough.

**Apply merge rule for small directories:**
- If a candidate node has <10k tokens AND no package manifest → merge into parent
- If merging would create a node >64k tokens → keep separate
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

### 7. Validate Capture Plan (REQUIRED)

**Before presenting the plan to the user, verify ALL of these constraints:**

```
VALIDATION CHECKLIST:
═════════════════════

1. No oversized leaves
   [ ] Every leaf node ≤ 100k tokens
   → If ANY leaf >100k: FAIL - must recurse further

2. Node count sanity
   [ ] actual_leaves within 0.5x-2x of (total_tokens / 50k)
   → If ratio <0.5x: WARNING - probably need more decomposition
   → If ratio >2x: WARNING - may have too many small nodes

3. Parents have children
   [ ] Every node >64k tokens has child nodes listed
   → If >64k with no children: FAIL - missing decomposition

4. Coverage complete
   [ ] Sum of leaf coverage ≈ total repo tokens
```

**Example validation:**
```
VALIDATION
──────────
Total source tokens:  5,765k
Expected leaves:      ~115 (5765k / 50k)
Actual leaves:        14
Ratio:                0.12x ← FAIL (need ~8x more decomposition)

Oversized leaves:     2
  packages/effect/    2,538k ← FAIL (>100k, needs children)
  packages/platform/  2,128k ← FAIL (>100k, needs children)

⛔ VALIDATION FAILED - Re-run with deeper recursion
```

**If validation fails:**
1. Re-analyze directories that are too large
2. Apply recursive decomposition more deeply
3. Re-validate until all constraints pass

**Only present plan to user AFTER validation passes.**

### 8. Determine Capture Order

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

### 9. Map Legacy Content to Nodes

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

### 10. Handle Edge Cases

**Monorepo:** Large monorepos require careful recursive analysis:

**Don't treat package count as node count:**
- 36 packages in a monorepo does NOT mean 36 nodes
- A 2.5M token package may need 50+ internal nodes
- Token mass determines node count, not manifest count

**Analyze each package independently:**
```
for each package:
  tokens = count_tokens(package)
  if tokens > 64k:
    recursively_decompose(package)  # creates child nodes
  else:
    single_node(package)
```

**Expected outcomes:**
- 1M token monorepo → 20-40 leaf nodes
- 5M token monorepo → 100-200 leaf nodes
- Root summarizes package-level parents (not all leaves)

**Identification:**
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

**Only present this AFTER validation passes (see Step 7).**

Present to user:

```
Intent Layer Capture Plan
═════════════════════════

Target: [path]
Token counting: tiktoken (o200k_base) via [method]
Total code tokens: [N]k

VALIDATION PASSED ✓
───────────────────
Expected leaves:    ~[N/50]
Actual leaves:      [L]
Ratio:              [L/(N/50)]x ✓
Oversized leaves:   0 ✓
Coverage:           100% ✓

Existing AGENTS.md:
───────────────────
Intent nodes (skip): [X]
  ./services/payment/AGENTS.md
Legacy files (replace): [Y]
  ./AGENTS.md → extract & replace

LEAF NODES ([L] total):
───────────────────────
 1. packages/effect/src/internal/stm/      67k  ✓ optimal
 2. packages/effect/src/internal/channel/  20k  ✓ optimal
 3. packages/effect/test/Stream/           73k  ⚠ slightly over (ok)
 ...
[L]. packages/typeclass/src/               45k  ✓ optimal

PARENT NODES ([P] total, summarize children not code):
──────────────────────────────────────────────────────
 1. packages/effect/src/internal/  454k  (8 children)
 2. packages/effect/src/           997k  (3 children)
 3. packages/effect/             2,538k  (4 children)
 ...
[P]. ./                          5,765k  (root, [N] children)

Merged (below threshold):
─────────────────────────
- packages/effect/src/internal/effect/ (8k) → merged into parent
- packages/vitest/ (10k) → merged into root

Legacy content lifting:
───────────────────────
- ./utils/helpers/AGENTS.md → lifts to ./utils/

Capture Order (leaf → root):
────────────────────────────
[Leaves first, sorted by complexity (simpler first)]
[Then parents, bottom-up]
[Root last]

⚠️  Notes:
- [any warnings about slightly oversized nodes]
- [legacy files at unexpected locations]
```

Then ask: "Proceed with this capture plan? [y/n/modify]"

## Notes

- **Always TRY tiktoken first** (node, then python) before falling back to estimation
- If using estimation, warn user about potential inaccuracy
- User can modify order before confirming
- Intent nodes (proper structure) are skipped—already captured
- Legacy AGENTS.md are extracted and replaced with new intent nodes
- This skill only plans—actual capture uses @intent-capture
- **Validation is mandatory** — never present a plan that fails token constraints
- **Recursive decomposition is mandatory** — directories >64k MUST be analyzed further
- **Sanity check**: If your leaf count is <50% of `total_tokens / 50k`, you haven't recursed enough
