---
description: Refresh intent nodes affected by recent code changes
---

Refresh intent nodes affected by recent code changes.

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

### 4. Refresh Each Node

For each affected node:

```
[X/N] Refreshing /path/to/directory/
```

Run @intent-capture with focus on changes:

**For leaf nodes:**
- Read changed files + existing AGENTS.md
- Show diff of what changed in code
- Ask: "How do these changes affect the intent node?"
- Generate updated AGENTS.md

**For parent nodes:**
- Re-read child AGENTS.md (which may have just been updated)
- Check if parent summary needs adjustment
- Re-run LCA resolution for any new Open Questions

### 5. Show Diff Before Writing

For each node, show:

```
Proposed changes to /path/AGENTS.md:
────────────────────────────────────

[diff view: - old lines, + new lines]

────────────────────────────────────
Accept? [y/n/edit/skip]
```

Options:
- **y**: Write the update
- **n**: Discard, keep existing
- **edit**: Modify before writing
- **skip**: Skip this node, continue to next

### 6. Summary

```
Intent Layer Refresh Complete
═════════════════════════════

Files changed: [N]
Nodes refreshed: [M]
Nodes skipped: [S]

Updated:
  ✓ services/payment/validators/AGENTS.md
  ✓ services/payment/AGENTS.md
  ○ lib/utils/AGENTS.md (skipped)

New Open Questions: [Q]
New Pending Tasks: [P]
```

## Batch Mode

If many nodes affected, offer batch options:

```
[N] nodes affected by changes.

Options:
1. Review each individually
2. Auto-accept low-risk updates (cosmetic, additive)
3. Show all diffs first, then batch confirm
```

## Edge Cases

**No AGENTS.md in ancestry:**
- File changed in directory without intent node coverage
- Note: "No intent node covers [path]—consider /intent-capture"

**Root-level changes:**
- Changes to root files affect root AGENTS.md
- Always include root if any root-level file changed

**New directories:**
- If changes create new directory with significant code
- Suggest: "New directory [path] may warrant intent node"
