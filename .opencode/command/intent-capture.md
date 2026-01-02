---
description: Capture intent node for single directory
---

Run @intent-capture for: $ARGUMENTS

If no path provided, use current working directory.

**Pre-capture validation (required):**
Before running capture, verify the target directory is correctly sized:
1. Count tokens in target directory (recursively)
2. If >100k tokens AND this would be a leaf node (no children planned):
   - STOP and warn user
   - This directory is too large for a single node
   - Suggest re-running /intent-init or manually creating child structure

**This validation prevents creating oversized leaf nodes like:**
```
❌ packages/effect/ (1.4M tokens) as single leaf
✓  packages/effect/ as parent with 28 child nodes
```

Show progress and results after capture completes.
