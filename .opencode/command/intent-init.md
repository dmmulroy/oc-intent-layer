---
description: Bootstrap complete intent layer hierarchy with pre-push hook
---

Bootstrap complete intent layer for this project.

## Process

### 1. Analyze & Plan

Run @intent-chunk to analyze codebase and generate capture plan.

Present the plan and ask user to confirm before proceeding.

### 2. Capture All Nodes

For each node in the confirmed leaf-first order:

```
[X/N] Capturing /path/to/directory/
```

Run @intent-capture for each node.

Track progress:
- Completed nodes
- Open questions accumulated
- Pending tasks discovered
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

If interrupted, check for existing AGENTS.md files:
- Skip directories that already have AGENTS.md
- Note: "Resuming—[N] nodes already captured"
- Continue with remaining nodes in order

User can force re-capture with explicit path via /intent-capture.
