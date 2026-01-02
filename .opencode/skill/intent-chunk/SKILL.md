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

**⚠️ CRITICAL CLARIFICATION: Package manifest indicates semantic boundary, NOT "single node".**

```
WRONG MENTAL MODEL:
  "package.json exists" → "this is one package" → "one node"
  
CORRECT MENTAL MODEL:
  "package.json exists" → "this is a semantic boundary" → "check token count"
  if tokens > 64k → "this boundary becomes a PARENT node, recurse inside"
  if tokens ≤ 64k → "this boundary becomes a LEAF node"
```

A package with 1.4M tokens needs ~28 internal child nodes, not 1 node.
The manifest location becomes a PARENT node that has children inside it.

**Domain directory name:**
- `services/`, `api/`, `domain/`, `lib/`, `pkg/`
- `handlers/`, `controllers/`, `models/`, `utils/`
- `core/`, `internal/`, `cmd/`, `src/`

**Token-based boundaries (THE ACTUAL DETERMINING FACTOR):**
- 20k-64k tokens ideal → LEAF NODE
- <10k tokens → **MERGE with parent** (unless package manifest)
- >64k tokens → **MUST recurse into subdirectories** (even if package manifest!)
- >100k tokens → **MUST have child nodes** (HARD CONSTRAINT - validation fails otherwise)

**Responsibility shift indicators:**
- README or docs in directory
- Distinct naming conventions
- Clear module boundary

**Monorepo patterns to watch for:**
```
packages/
├── effect/          (1.4M tokens) → NOT a leaf! Needs ~28 children
├── platform/        (1.5M tokens) → NOT a leaf! Needs ~30 children
├── sql/             (39k tokens)  → Could be leaf (but check children)
│   └── [many small sql-* siblings <10k each] → MERGE into sql/
├── sql-pg/          (5k tokens)   → MERGE into packages/sql/
├── sql-mysql2/      (4k tokens)   → MERGE into packages/sql/
└── vitest/          (6k tokens)   → MERGE into root or appropriate parent
```

### 5. Apply Recursive Decomposition (MANDATORY)

**This algorithm is NOT optional. Apply it to EVERY directory >64k tokens.**

**CRITICAL: Package manifest (package.json, Cargo.toml, etc.) indicates a BOUNDARY, not a stopping point.**
A package with 1.4M tokens MUST be decomposed into ~28 child nodes. The manifest location becomes a PARENT node with children—it does NOT become a 1.4M token leaf.

```
analyze(dir):
  tokens = count_tokens(dir)  # RECURSIVE total (all descendant code)
  
  if tokens < 10k AND no_package_manifest(dir):
    return MERGE_INTO_PARENT
  
  if tokens <= 64k:
    return LEAF_NODE(dir)
  
  # tokens > 64k: MUST decompose further - NO EXCEPTIONS
  # Even if this is a "package" with package.json, we MUST look inside
  children = []
  for subdir in get_subdirectories(dir):
    result = analyze(subdir)
    if result != MERGE_INTO_PARENT:
      children.append(result)
  
  # If no subdirectories found but dir is >64k, look for logical groupings:
  # - Group files by prefix (user_*.ts, payment_*.ts)
  # - Group by subdirectory under src/ (src/internal/, src/services/)
  # - If truly flat with no structure, it becomes an oversized leaf (flagged)
  if len(children) == 0:
    if tokens > 100k:
      # CRITICAL: This is a VALIDATION FAILURE, not acceptable
      return OVERSIZED_LEAF_ERROR(dir, tokens)
    return LEAF_NODE(dir)  # 64k-100k is acceptable as leaf
  
  # This directory becomes a PARENT node with child nodes
  return PARENT_NODE(dir, children)
```

**HARD CONSTRAINTS (validation will FAIL if violated):**
- **NO leaf node may cover >100k source tokens** — This is a HARD FAIL, not a warning
- **Directories >64k tokens MUST have children** — Keep recursing until ALL leaves are in 10k-64k range
- **Package directories are NOT exempt** — A 2M token package needs ~40 internal nodes

**Common mistake to avoid:**
```
WRONG: packages/effect/ (1.4M tokens) → single leaf node
       "It has package.json so it's one package = one node"

RIGHT: packages/effect/ (1.4M tokens) → PARENT node
       ├── src/internal/stm/ (67k) → leaf
       ├── src/internal/channel/ (20k) → leaf
       ├── test/Schema/ (91k) → PARENT (still too big!)
       │   ├── test/Schema/Class/ (30k) → leaf
       │   └── test/Schema/Struct/ (25k) → leaf
       └── ... (~28 total leaves)
```

**Example recursive decomposition (Effect monorepo case study):**

```
packages/effect/ (1,412k tokens) — HAS package.json, but 1.4M >> 64k, so MUST recurse
├── src/ (997k) → too big, recurse
│   ├── internal/ (454k) → too big, recurse
│   │   ├── stm/ (67k) → LEAF NODE ✓
│   │   ├── channel/ (45k) → LEAF NODE ✓
│   │   ├── stream/ (89k) → too big, recurse further
│   │   │   ├── stream/core.ts + related (40k) → LEAF NODE ✓
│   │   │   └── stream/sink.ts + related (35k) → LEAF NODE ✓
│   │   ├── schema/ (120k) → too big, recurse
│   │   │   ├── schema/AST/ (45k) → LEAF NODE ✓
│   │   │   └── schema/Parser/ (55k) → LEAF NODE ✓
│   │   └── ...
│   └── [public API files] (200k) → recurse by domain
│       ├── Effect.ts + core (50k) → LEAF NODE ✓
│       ├── Stream.ts + streaming (40k) → LEAF NODE ✓
│       └── Schema.ts + validation (60k) → LEAF NODE ✓
├── test/ (349k) → too big, recurse
│   ├── Schema/ (91k) → still >64k, recurse further!
│   │   ├── Schema/Class/ (30k) → LEAF NODE ✓
│   │   ├── Schema/Struct/ (35k) → LEAF NODE ✓
│   │   └── Schema/parsing/ (26k) → LEAF NODE ✓
│   ├── Stream/ (73k) → LEAF NODE ✓ (borderline ok)
│   └── Effect/ (66k) → LEAF NODE ✓ (borderline ok)
└── dtslint/ (78k) → LEAF NODE ✓

Result for 1.4M token package: ~28 leaf nodes
NOT: 1 node (would violate 100k max leaf constraint)
```

**Monorepo reality check:**
- Effect monorepo total: ~5.2M tokens
- Expected leaves: 5200k / 50k = ~104 leaves
- packages/effect/ alone (1.4M) needs: 1400k / 50k = ~28 leaves
- packages/platform/ alone (1.5M) needs: 1500k / 50k = ~30 leaves
- If your plan has 38 leaves for 5.2M tokens, you're at 0.36x expected — **VALIDATION MUST FAIL**

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

### 7. Validate Capture Plan (REQUIRED - HARD GATE)

**⛔ DO NOT PROCEED TO OUTPUT until ALL validation checks pass.**

**Before presenting the plan to the user, verify ALL of these constraints:**

```
VALIDATION CHECKLIST:
═════════════════════

1. No oversized leaves (HARD FAIL)
   [ ] Every leaf node ≤ 100k tokens
   → If ANY leaf >100k: ⛔ STOP - cannot proceed, must recurse further
   → This is NOT a warning, it's a blocking failure

2. Node count sanity (HARD FAIL if <0.3x)
   [ ] actual_leaves within 0.5x-2x of (total_tokens / 50k)
   → If ratio <0.3x: ⛔ STOP - severely under-decomposed
   → If ratio <0.5x: ⚠️ WARNING - likely need more decomposition
   → If ratio >2x: ⚠️ WARNING - may have too many small nodes

3. Parents have children (HARD FAIL)
   [ ] Every node >64k tokens has child nodes listed
   → If >64k with no children: ⛔ STOP - missing decomposition

4. Coverage complete
   [ ] Sum of leaf coverage ≈ total repo tokens
```

**VALIDATION IS A HARD GATE - Example of what happens:**

```
VALIDATION ATTEMPT #1
─────────────────────
Total source tokens:  5,217k
Expected leaves:      ~104 (5217k / 50k)
Actual leaves:        38
Ratio:                0.36x ← ⛔ HARD FAIL (<0.5x)

Oversized leaves:     7
  packages/effect/         1,412k ← ⛔ FAIL (14x over 100k limit!)
  packages/platform/       1,540k ← ⛔ FAIL (15x over 100k limit!)
  packages/ai/openai/        232k ← ⛔ FAIL (>100k)
  packages/cli/              110k ← ⛔ FAIL (>100k)
  packages/ai/ai/            103k ← ⛔ FAIL (>100k)
  packages/cluster/           87k ← OK (borderline)
  packages/ai/google/         66k ← OK

⛔ VALIDATION FAILED - 5 leaves exceed 100k limit
   CANNOT PROCEED - Must recursively analyze:
   - packages/effect/ (need ~28 sub-nodes)
   - packages/platform/ (need ~30 sub-nodes)
   - packages/ai/openai/ (need ~5 sub-nodes)
   - packages/cli/ (need ~2 sub-nodes)
   - packages/ai/ai/ (need ~2 sub-nodes)

RE-RUNNING DECOMPOSITION...
```

```
VALIDATION ATTEMPT #2 (after deeper recursion)
──────────────────────────────────────────────
Total source tokens:  5,217k
Expected leaves:      ~104 (5217k / 50k)
Actual leaves:        97
Ratio:                0.93x ← ✓ PASS

Oversized leaves:     0 ← ✓ PASS
Largest leaf:         73k (packages/effect/test/Stream/) ← OK

✓ VALIDATION PASSED - Ready to present plan
```

**If validation fails:**
1. DO NOT present plan to user
2. Identify ALL directories that caused failure
3. Re-run analyze() on each failed directory with deeper recursion
4. Re-validate
5. Loop until ALL constraints pass
6. Only THEN present plan to user

**The agent MUST NOT skip validation or present a failing plan.**

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

**⛔ ONLY present this AFTER validation passes (see Step 7). NEVER present a failing plan.**

Present to user:

```
Intent Layer Capture Plan
═════════════════════════

Target: [path]
Token counting: tiktoken (o200k_base) via [method]
Total source tokens: [N]k

HIERARCHY HEALTH ✓
──────────────────
Leaf coverage:
  Expected leaves:      ~[N/50] (source ÷ 50k)
  Planned leaves:       [L]
  Coverage ratio:       [L/(N/50)]x ✓

Leaf sizing:
  Largest planned leaf: [max]k (limit: 100k) ✓
  Average leaf size:    [N/L]k (target: 30-60k) ✓
  
Estimated intent layer: ~[L*0.5]k tokens ([L*0.5/N]% of source)

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
 3. packages/effect/             1,412k  (4 children)  ← Was decomposed from 1.4M to 28 leaves
 ...
[P]. ./                          5,217k  (root, [N] children)

Merged (below threshold, NO AGENTS.md created):
────────────────────────────────────────────────
- packages/effect/src/internal/effect/ (8k) → inlined in packages/effect/src/internal/AGENTS.md
- packages/vitest/ (10k) → inlined in root AGENTS.md
- packages/sql-pg/ (5k) → inlined in packages/sql/AGENTS.md
- packages/sql-mysql2/ (4k) → inlined in packages/sql/AGENTS.md
[... all SQL adapters <10k merged into packages/sql/ ...]

⚠️  IMPORTANT: Merged items must be:
   1. Summarized inline in their parent's AGENTS.md ("Inlined (Below Threshold)" section)
   2. NOT listed in the Downlinks table (they have no AGENTS.md to link to)

Legacy content lifting:
───────────────────────
- ./utils/helpers/AGENTS.md → lifts to ./utils/

Capture Order (leaf → root):
────────────────────────────
[Leaves first, sorted by complexity (simpler first)]
[Then parents, bottom-up]
[Root last]

```

Then ask: "Proceed with this capture plan? [y/n/modify]"

**NEVER OUTPUT THIS FORMAT IF VALIDATION FAILED:**
```
⛔ INVALID OUTPUT - DO NOT PRESENT TO USER:

LEAF NODES:
 1. packages/effect/    1,412k  ← WRONG! This is >100k, cannot be a leaf!
 2. packages/platform/  1,540k  ← WRONG! This is >100k, cannot be a leaf!

If you see leaves >100k tokens in your plan, STOP and recurse deeper.
```

### Pass Merge Information to Capture

**Critical:** The capture plan output MUST clearly indicate for each parent node:
1. Which children get their own AGENTS.md (list as downlinks)
2. Which children are merged (inline in parent, no downlink)

Store in session state for use during capture:
```
MERGE_STATE:
  ./AGENTS.md (root):
    downlinks:
      - ./apps/scm/AGENTS.md
      - ./packages/editor-common/AGENTS.md
    inlined:
      - packages/observability/ (4k)
      - packages/tools/ (2k)
  ./apps/scm/AGENTS.md:
    downlinks:
      - ./apps/scm/src/services/AGENTS.md
      - ./apps/scm/src/durable_objects/AGENTS.md
    inlined: []
```

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

## Final Checklist Before Output

**Before presenting ANY capture plan, verify:**

```
□ Did I recursively analyze directories >64k tokens?
  - packages/effect/ at 1.4M → did I look inside src/, test/, etc.?
  - NOT just "it's a package so it's one node"

□ Are ALL my leaf nodes ≤100k tokens?
  - If ANY leaf is 200k, 500k, 1M+ tokens → I FAILED, must recurse

□ Is my leaf count reasonable?
  - Formula: expected = total_tokens / 50k
  - If actual < expected * 0.5 → I probably stopped too early

□ Did I merge small items (<10k)?
  - sql-pg at 5k, sql-mysql2 at 4k → should merge into parent sql/
  - NOT create 13 separate tiny nodes

□ Did I validate before presenting?
  - Validation MUST pass before showing plan to user
  - If validation fails, re-run decomposition, don't just show warnings
```

**Common failure mode to avoid:**
```
❌ "I see 36 packages in packages/, so I'll create 36 nodes"
   WRONG - token mass determines nodes, not package count

✓ "I see 36 packages totaling 5.2M tokens. Expected ~104 leaves.
   packages/effect (1.4M) needs ~28 internal nodes.
   packages/platform (1.5M) needs ~30 internal nodes.
   13 sql-* packages (<10k each) merge into 1 parent node.
   Let me recurse into the large packages..."
```
