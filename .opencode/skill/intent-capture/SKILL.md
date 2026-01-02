---
name: intent-capture
description: Interactively capture intent node for a directory via SME interview, generate AGENTS.md with LCA resolution
---

Capture intent node for: $ARGUMENTS (default: current directory)

## Phase 1: Read

### Leaf Node (no child AGENTS.md)

Read ALL code files in target directory:
- Use glob to find code files (same extensions as @intent-chunk)
- Read each file's content
- Build mental model of: entry points, exports, dependencies, patterns

### Parent Node (has child AGENTS.md)

Read child AGENTS.md files ONLY—this is fractal compression:
- Do NOT read child code directly
- Note each child's: Purpose, Entry Points, Contracts, Open Questions
- Collect all child Open Questions for LCA resolution

### Legacy AGENTS.md Handling

If this node was tagged "has legacy content" during chunking:

**Read the legacy AGENTS.md file(s):**
- Direct legacy: Legacy file at this exact location
- Inherited legacy: Legacy from child location that lifted here

**Extract valuable content from legacy file:**
- Warnings/gotchas → candidate for Patterns & Pitfalls
- Historical context → candidate for Patterns & Pitfalls  
- Dependency notes → candidate for Dependencies
- Usage examples → candidate for Usage Patterns
- API docs → candidate for Entry Points & Contracts
- Agent instructions → candidate for Patterns & Pitfalls OR flag for `.opencode/` migration

**Note:** Legacy file will be REPLACED, not merged. All valuable content must flow into new intent node structure.

**For root-level legacy with agent instructions:**

Common pattern—existing root AGENTS.md often contains:
```markdown
# Project Name
Instructions for AI agents working in this codebase...

## Rules
- Always use yarn, not npm
- Run tests before committing
...
```

Separate concerns:
- **Architectural content** → new intent node's Purpose & Scope, Patterns & Pitfalls
- **Agent behavior rules** → flag for user decision:
  - Keep in Patterns & Pitfalls section
  - OR migrate to `.opencode/agent.md` (cleaner separation)

Present migration options during interview if detected.

## Phase 2: Interview

### Agent Describes First

Before asking questions, share observations:

```
Based on my analysis of [directory]:

OBSERVATIONS:
• This appears to handle [X]...
• I see [Y] calling [Z], which suggests [pattern]...
• The main entry points seem to be [A, B, C]
• There's an interesting pattern where [D]...
• I'm uncertain about [E]—it could be [F] or [G]

Does this match your understanding?
```

### If Legacy Content Exists

When this node has legacy AGENTS.md content, ALSO share:

```
LEGACY CONTENT FOUND:
I found an existing AGENTS.md at this location. Here's what it contains:

From [path]/AGENTS.md:
• [Summary of existing content]
• Key points: [X, Y, Z]
• Warnings mentioned: [A, B]

Questions about legacy content:
• "The existing docs say [X]—is this still accurate?"
• "There's a warning about [Y]. Should this be preserved?"
• "I see instructions to [Z]. Is this still relevant?"
• "The legacy file mentions [W] but I don't see it in code—deprecated?"
```

For root-level agent instructions specifically:
```
AGENT INSTRUCTIONS DETECTED:
The existing root AGENTS.md contains agent behavior rules:
• [Rule 1]
• [Rule 2]

Options:
1. Preserve in new intent node's Patterns & Pitfalls section
2. Migrate to .opencode/agent.md (cleaner separation)
3. Discard (no longer needed)

Which approach do you prefer?
```

### Then Ask Targeted Questions

Based on analysis gaps, ask relevant questions from:

**Scope & Ownership:**
- "What does this module own that might not be obvious from code?"
- "What does this explicitly NOT own that someone might assume it does?"

**Contracts & Invariants:**
- "Any invariants enforced only by convention, not code?"
- "Critical constraints callers must respect?"
- "What breaks if [observed pattern] is violated?"

**History & Evolution:**
- "Is [X] deprecated or legacy?"
- "Why does [Y] exist—historical reason or active need?"
- "Any past incidents caused by this area?"

**Runtime & Environment:**
- "Feature flags or conditional paths?"
- "Environment-specific behavior?"
- "External dependencies not obvious from imports?"

**Gotchas:**
- "What trips up new engineers here?"
- "Any 'looks wrong but is correct' patterns?"
- "Performance landmines?"

### Interview Calibration

Scale depth with complexity:
- **Trivial module** (utils, simple helpers): 1-2 quick questions or skip
- **Standard module**: 3-5 targeted questions
- **Complex/critical module**: Thorough exploration, multiple rounds

### Track Shared State

Maintain across capture session:

```
SHARED STATE:
├── Open Questions (unresolved)
│   • "Who owns retry logic?" → tag: settlement
│   • "Is legacy_handler used?" → tag: unknown
├── Cross-References
│   • validators mentions settlement invariants
│   • both reference shared-types
├── LCA Candidates
│   • shared-types docs → needs root or services/
├── Refactor Opportunities
│   • Duplicate validation in 3 places
│   • Dead code candidate: old_handler.ts
```

## Phase 3: Generate

Create AGENTS.md following this template:

```markdown
# [Module Name]

## Purpose & Scope
[What this owns. What it explicitly doesn't own.]
Example: "Owns: payment validation, amount formatting. Does NOT own: persistence, user identity."

## Entry Points & Contracts
- `function(input): output` — [description]
- Invariants: [constraints callers must respect]

## Dependencies
- [External system, library, env var requirement]

## Usage Patterns
[Canonical correct usage example—code snippet if helpful]

## Anti-Patterns
❌ [Bad pattern] — [why]

## Downlinks
- ./child/AGENTS.md — [brief description]

## Outlinks
- /docs/adr/NNN-decision.md — [why relevant]
- /docs/diagrams/flow.png — [what it shows]

## Patterns & Pitfalls
- [Gotcha]
- [Historical context]
- [Non-obvious behavior]

---

## Open Questions
- ? [Unresolved question—will lift to ancestor or resolve later]

## Pending Tasks
- [ ] [Refactor discovered during capture]
- [ ] [Dead code to investigate]
```

### Generation Guidelines

**Target: 1-3k tokens.** Dense, high-signal.

- **Be specific:** "Owns X, does NOT own Y" beats "handles X-related things"
- **Contracts over descriptions:** What MUST hold, not what currently happens
- **Anti-patterns are critical:** Prevent repeated mistakes
- **Downlinks only to children:** No lateral deps—ancestors expose via their downlinks
- **Open Questions are temporary:** They resolve via LCA lifting or future passes

## Phase 4: LCA Resolution (Parent Nodes Only)

When capturing a parent node:

### Read Child Open Questions

For each child AGENTS.md, extract `## Open Questions` section.

### Resolve What Belongs Here

For each child question:

1. **Answerable at this level?**
   - Cross-child knowledge resolves here
   - Example: "Who owns shared-types?" → Parent knows, add to parent's docs

2. **Still unresolved?**
   - Add to THIS node's Open Questions
   - Will lift to grandparent

3. **Belongs higher?**
   - Leave for next ancestor
   - Tag with likely destination

### Update Children

After resolving questions:
- Remove resolved items from child AGENTS.md
- Add brief reference if helpful: "See parent for shared-types docs"

## Phase 5: Confirm & Write

### Show Generated Content

```
Generated AGENTS.md for [path]:
═══════════════════════════════

[full content]

═══════════════════════════════
Tokens: ~[N]
```

### Report Summary

```
Capture Summary:
• Token count: [N] (target: 1-3k)
• Open Questions: [M] (to lift to parent)
• Pending Tasks: [P] discovered
• Child questions resolved: [Q]
```

### Confirm

"Write this AGENTS.md? [y/n/edit]"

If edit requested, iterate with user feedback.

### Write

Write to `[target]/AGENTS.md`

## Notes

- If AGENTS.md exists, show diff and confirm overwrite
- Interview can span multiple messages—don't rush
- User "skip" or "later" on questions is valid—add to Open Questions
- Refactors go to Pending Tasks, not immediate action
- For monorepos, respect project boundaries
- **Legacy handling**: Always extract valuable content from existing AGENTS.md before replacing
- **Agent instructions**: If legacy root has agent rules, present migration options (keep vs move to .opencode/)
- **Inherited legacy**: When legacy content lifts from child location, acknowledge source in interview
