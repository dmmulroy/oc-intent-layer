---
description: Bootstrap complete intent layer hierarchy with pre-push hook
---

Bootstrap complete intent layer for this project.

## Process

### 1. Analyze & Plan

Run @intent-chunk to analyze codebase and generate capture plan.

This includes:
- **Audit existing AGENTS.md files**: Classify as intent nodes (skip) or legacy (extract & replace)
- **Token analysis**: Calculate code mass per directory
- **Boundary detection**: Identify semantic boundaries for intent nodes
- **Legacy mapping**: Map legacy content to target nodes
- **Capture ordering**: Leaf-first, easy-first sequence

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

Legacy content will be reviewed during each node's capture interview.
Valuable content will be incorporated into new intent nodes.

Proceed? [y/n]
```

### 2. Capture All Nodes

For each node in the confirmed leaf-first order:

```
[X/N] Capturing /path/to/directory/
```

If node has legacy content:
```
[X/N] Capturing /path/to/directory/ ◀ has legacy AGENTS.md
```

Run @intent-capture for each node.

Track progress:
- Completed nodes
- Open questions accumulated
- Pending tasks discovered
- Legacy files processed
- Time elapsed

If user needs to pause, save state for resume (note completed nodes).

### 3. Install Pre-Push Hook

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
echo "Run: /intent-refresh"
echo ""
read -p "Push anyway? [y/N] " -r
[[ $REPLY =~ ^[Yy]$ ]] && exit 0
exit 1
```

Make executable: `chmod +x .git/hooks/pre-push`

### 4. Final Summary

```
Intent Layer Bootstrap Complete
═══════════════════════════════

Nodes created: [N]
Total tokens: ~[X]k across all nodes

Legacy files processed: [L]
  [list paths replaced]

Open Questions remaining: [M]
  [list top 3-5 if any]

Pending Tasks discovered: [P]
  [list top 3-5 if any]

Pre-push hook: ✓ installed

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
2. **Legacy content extracted** and stored for capture phase
3. **During capture**, legacy content is:
   - Presented in interview
   - Validated with user ("Is this still accurate?")
   - Incorporated into new intent node where relevant
4. **Legacy file replaced** with new intent node

**Root AGENTS.md with agent instructions:**
- Common pattern: existing root has project-level agent rules
- Migration options presented during root capture:
  - Keep in Patterns & Pitfalls section
  - Move to `.opencode/agent.md`
  - Discard if obsolete

**Boundary misalignment:**
- Legacy file at location that isn't a semantic boundary
- Content lifts to nearest ancestor that IS a boundary
- User notified during audit phase
