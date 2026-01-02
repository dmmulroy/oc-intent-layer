---
name: intent-chunk
description: Analyze codebase structure, calculate token budgets, output leaf-first capture order for intent layer bootstrap
---

Analyze codebase for intent layer capture.

Target: $ARGUMENTS (default: project root)

## Process

### 1. Walk Directory Tree

Recursively traverse from target, collecting:
- Directory paths
- Code file counts per directory
- Token estimates per directory (code files only)

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

### 2. Calculate Token Counts

Try methods in order until one succeeds:

**1. npx js-tiktoken (preferred):**
```bash
# Count tokens for a file via npx (no install needed)
npx js-tiktoken <file> --encoding o200k_base
```

If npx unavailable or fails, try Python.

**2. Python tiktoken fallback:**
```bash
python3 -c "import tiktoken" 2>/dev/null && echo "available"
```
```python
import tiktoken
enc = tiktoken.get_encoding("o200k_base")
tokens = len(enc.encode(file_content))
```

**3. Estimation fallback:**
If neither available: `tokens ≈ bytes / 4`

**Encoding reference:**
| Encoding | Models |
|----------|--------|
| `o200k_base` | GPT-4o, GPT-4o-mini (recommended) |
| `cl100k_base` | GPT-4, GPT-3.5-turbo, embeddings |

Note in output which method was used:
- `[tiktoken]` — accurate count (npx or python)
- `[estimated]` — bytes/4 approximation

For each directory, sum tokens of all code files (non-recursive—direct children only for leaf identification).

### 3. Identify Semantic Boundaries

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
- <10k tokens: consider merging with parent
- >100k tokens: likely needs child nodes

**Responsibility shift indicators:**
- README or docs in directory
- Distinct naming conventions
- Clear module boundary

### 4. Determine Capture Order

**Principle:** Leaf-first, easy-first.

1. Identify all leaf candidates (no child intent nodes)
2. Sort leaves by estimated complexity (simpler first):
   - Fewer files = simpler
   - Smaller token count = simpler
   - Utils/helpers before core domain
3. After leaves, capture parents in bottom-up order
4. Root node captured last

**Why leaf-first:**
- Parents summarize child AGENTS.md, not code
- Context compounds—simple areas illuminate complex ones
- Open questions resolve during parent capture

### 5. Handle Edge Cases

**Monorepo:** Each independent project gets separate capture pass. Identify by:
- Multiple package manifests at same depth
- Independent CI configs
- No code imports between areas

**Deep trees (>4 levels):** Collapse middle layers if token counts allow. Parent can summarize grandchildren if intermediate layer adds no semantic value.

**Sparse directories:** Skip directories with <5 code files AND <2k tokens unless package manifest present.

## Output Format

Present to user:

```
Intent Layer Capture Plan
═════════════════════════

Target: [path]
Total code tokens: [N]k
Proposed nodes: [M]

Directory Tree (with token estimates):
──────────────────────────────────────
[tree view with token counts]

Capture Order (leaf → root):
────────────────────────────
1. /path/to/simple-leaf/     (~Xk tokens) - [reason: utils, small]
2. /path/to/another-leaf/    (~Yk tokens) - [reason: clear boundary]
...
N. /                         (summarizes children)

Skipped (below threshold):
──────────────────────────
- /path/tiny/  (800 tokens, no manifest)

⚠️  Potential issues:
- [any warnings about large directories, unclear boundaries]
```

Then ask: "Proceed with this capture plan? [y/n/modify]"

## Notes

- Token counts via tiktoken are accurate; fallback estimates may vary ±20%
- User can modify order before confirming
- If existing AGENTS.md found, note for resume support
- This skill only plans—actual capture uses @intent-capture
