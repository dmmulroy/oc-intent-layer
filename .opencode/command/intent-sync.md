---
description: Sync intent nodes affected by recent code changes
---

Sync intent nodes affected by recent code changes.

**Key structural rules (enforced during sync):**
- Downlink URLs MUST end in `AGENTS.md` (e.g., `./child/AGENTS.md`)
- Only children with actual AGENTS.md files appear in Downlinks table
- Small items (<10k tokens) merged into parent go in "Inlined (Below Threshold)" section, NOT Downlinks

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

**Get change details (not just names):**
```bash
git diff --name-status @{push}.. 2>/dev/null || git diff --name-status origin/HEAD..HEAD
```

This shows: `A` (added), `M` (modified), `D` (deleted), `R` (renamed).

**For each changed file (excluding AGENTS.md files):**

1. Find the file's directory
2. Walk up to find nearest ancestor with AGENTS.md
3. Collect unique directories that need refresh

**Handle structural changes:**

| Change Type | Detection | Action |
|-------------|-----------|--------|
| File modified | `M` status | Normal refresh |
| File added | `A` status | Normal refresh |
| File deleted | `D` status | Refresh—scope may have narrowed |
| File renamed | `R` status | Check if AGENTS.md moved too |
| Directory deleted | All files `D` in dir with AGENTS.md | Flag orphaned node for removal |
| Directory renamed | `R` status pattern | Verify AGENTS.md moved, update parent downlinks |

Example:
```
Changed files:
  M  services/payment/validators/amount.ts
  R  services/billing/ → services/invoicing/
  D  lib/deprecated/old.ts

Affected intent nodes:
  services/payment/validators/  (has AGENTS.md)
  services/payment/             (parent—child changed)
  services/invoicing/           (renamed from billing—verify AGENTS.md)
  lib/                          (child file deleted)

Structural issues:
  ⚠️  services/billing/AGENTS.md → verify moved to services/invoicing/
  ⚠️  ./services/AGENTS.md downlink may need update (billing → invoicing)
```

### 3. Sort Leaf-First

Order affected nodes for refresh:
1. Deepest (most nested) first
2. Then their parents
3. Ensures parent summarizes updated child content

### 4. Analyze All Nodes

For each affected node (leaf-first order), generate proposed update:

**First, classify the existing AGENTS.md:**

| Classification | Detection | Action |
|----------------|-----------|--------|
| Valid Intent Node | Has `## Purpose & Scope` + structure | Update normally |
| Legacy File | No intent structure | Migrate: extract content, generate proper node |

**For valid leaf nodes:**
- Read changed files + existing AGENTS.md
- Analyze how code changes affect the intent node
- Generate proposed AGENTS.md update

**For legacy files (discovered during sync):**
- Extract valuable content (warnings, history, examples)
- Generate NEW intent node structure incorporating legacy content
- Present as migration, not just update:
  ```
  Legacy AGENTS.md detected at ./lib/helpers/
  Converting to intent node structure.
  Extracted: [summary of preserved content]
  ```

**For parent nodes:**
- Read child AGENTS.md (use proposed updates if child was also affected)
- Generate proposed parent update incorporating child changes
- Re-run LCA resolution for any new Open Questions
- **Validate downlinks** (critical—see below)

**Downlink validation during sync:**
```
For each downlink in parent AGENTS.md:
  1. URL format: MUST end in "AGENTS.md"
     ✓ ./services/AGENTS.md
     ✗ ./services/  ← FIX: append AGENTS.md
     
  2. Target exists: Child AGENTS.md must exist
     ✓ ./packages/editor-common/AGENTS.md (file exists)
     ✗ ./packages/tools/AGENTS.md (no file) ← REMOVE from downlinks
     
  3. Inlined items: Items in "Inlined (Below Threshold)" should NOT be in Downlinks
     Check for duplicates between sections
```

**If downlink validation fails:**
- Auto-fix URL format (append /AGENTS.md)
- Remove non-existent children from Downlinks
- If removed child was <10k tokens, consider adding to "Inlined (Below Threshold)" section
- Flag changes in diff output

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

Migrations (legacy → intent node): [L]
  ✓ ./lib/helpers/AGENTS.md (converted)

Structural fixes:
  ✓ Removed broken downlink: ./services/old-module/
  ✓ Updated downlink: billing/ → invoicing/

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

**Legacy AGENTS.md encountered:**
- Sync discovers AGENTS.md without intent structure
- Treat as migration opportunity (extract & replace)
- Present as: "Converting legacy docs to intent node"

**Directory renamed:**
- Git `R` status reveals rename
- Check if AGENTS.md exists at new location
- If yes: update parent downlinks
- If no (orphaned at old location): flag for user decision

**Directory deleted:**
- All files in directory show `D` status
- If directory had AGENTS.md: warn about orphaned node
- Propose: remove node, update parent downlinks

**Broken downlinks discovered:**
- When analyzing a parent node, validate downlinks exist
- If child AGENTS.md missing: flag for removal from downlinks
- Note: "Downlink ./old-child/ no longer exists—removing"
- If removed child was small (<10k tokens), suggest adding inline summary to "Inlined (Below Threshold)" section

**Malformed downlink URLs:**
- Downlinks MUST point to `./path/AGENTS.md`, NOT `./path/`
- Auto-fix during sync if detected
- Note: "Fixed downlink URL: ./services/ → ./services/AGENTS.md"

**New AGENTS.md added (not by us):**
- Someone committed an AGENTS.md manually
- Classify: intent node structure or legacy?
- If legacy: offer migration during sync
- If valid structure but not in parent's downlinks: suggest adding downlink
