---
description: Sync intent nodes affected by recent code changes
---

Sync intent nodes affected by recent code changes.

## Process

### 1. Detect Changed Files

Get files changed since last push:

```bash
git diff --name-only @{push}.. 2>/dev/null || git diff --name-only origin/HEAD..HEAD 2>/dev/null
```

If no changes detected, check for uncommitted changes:

```bash
git diff --name-only HEAD
```

### 2. Map Changes to Intent Nodes

For each changed file (excluding AGENTS.md files):

1. Find the file's directory
2. Walk up to find nearest ancestor with AGENTS.md
3. Collect unique directories that need refresh

Example:
```
Changed files:
  services/payment/validators/amount.ts
  services/payment/settlement/retry.ts
  lib/utils/format.ts

Affected intent nodes:
  services/payment/validators/  (has AGENTS.md)
  services/payment/settlement/  (has AGENTS.md)
  services/payment/             (parent—child changed)
  lib/utils/                    (has AGENTS.md)
```

### 3. Sort Leaf-First

Order affected nodes for refresh:
1. Deepest (most nested) first
2. Then their parents
3. Ensures parent summarizes updated child content

### 4. Analyze All Nodes

For each affected node (leaf-first order), generate proposed update:

**For leaf nodes:**
- Read changed files + existing AGENTS.md
- Analyze how code changes affect the intent node
- Generate proposed AGENTS.md update

**For parent nodes:**
- Read child AGENTS.md (use proposed updates if child was also affected)
- Generate proposed parent update incorporating child changes
- Re-run LCA resolution for any new Open Questions

Collect all proposed updates before any user interaction.

### 5. Present All Changes

Show complete picture of all proposed updates:

```
Intent Layer Sync Analysis
═════════════════════════════

Files changed: [N]
Nodes affected: [M]

Proposed Updates:
─────────────────

[1/M] services/payment/validators/AGENTS.md
──────────────────────────────────────────
[diff view: - old lines, + new lines]

[2/M] services/payment/AGENTS.md
────────────────────────────────
  Downlinks:
-   - ./validators/AGENTS.md — input validation rules
+   - ./validators/AGENTS.md — input validation incl. regional tax

...
```

### 6. Batch Confirmation

After showing all diffs:

```
─────────────────────────────────
Accept all updates? [y/n/select]
```

Options:
- **y**: Write all updates
- **n**: Discard all, keep existing
- **select**: Choose which to accept (shows numbered list)

If **select**:
```
Enter numbers to accept (comma-separated, or 'all'/'none'):
> 1,3,4
```

### 7. Summary

```
Intent Layer Sync Complete
═════════════════════════════

Files changed: [N]
Nodes synced: [M]
Nodes skipped: [S]

Updated:
  ✓ services/payment/validators/AGENTS.md
  ✓ services/payment/AGENTS.md
  ○ lib/utils/AGENTS.md (skipped)

New Open Questions: [Q]
New Pending Tasks: [P]
```

## Edge Cases

**No changes detected:**
- Report "No changes since last push" and exit

**No updates needed:**
- If analysis finds all affected AGENTS.md files are already current
- Report "All nodes current—no updates required" and exit
- Skip batch confirmation (nothing to confirm)

**No AGENTS.md in ancestry:**
- File changed in directory without intent node coverage
- Note: "No intent node covers [path]—consider /intent-capture"

**Root-level changes:**
- Changes to root files affect root AGENTS.md
- Always include root if any root-level file changed

**New directories:**
- If changes create new directory with significant code
- Suggest: "New directory [path] may warrant intent node"
