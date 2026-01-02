# Intent Layer Guide

## Table of Contents

- [The Problem: Dark Room Navigation](#the-problem-dark-room-navigation)
- [Core Concept](#core-concept)
- [Architecture](#architecture)
- [T-Shaped Context Loading](#t-shaped-context-loading)
- [Intent Node Structure](#intent-node-structure)
  - [Downlinks vs Outlinks](#downlinks-vs-outlinks)
- [Harness Integration](#harness-integration)
- [Fractal Compression](#fractal-compression)
- [Least Common Ancestor (LCA) Pattern](#least-common-ancestor-lca-pattern)
- [Building It](#building-it)
  - [Semantic Boundaries](#semantic-boundaries)
  - [Chunking Strategy](#chunking-strategy)
  - [Capture Workflow](#capture-workflow)
  - [SME Interview Loop](#sme-interview-loop)
  - [Hierarchical Summarization](#hierarchical-summarization)
  - [Node Contents Checklist](#node-contents-checklist)
- [Maintenance Flywheel](#maintenance-flywheel)
  - [Sync Process](#sync-process)
  - [Reinforcement Learning Loop](#reinforcement-learning-loop)
  - [Automation Pipeline](#automation-pipeline)
- [Anti-Patterns](#anti-patterns)
- [Investment & Payoff](#investment--payoff)
- [Key Semantics](#key-semantics)

---

## The Problem: Dark Room Navigation

Without an Intent Layer, every agent starts from zero. Every request is a full onboarding—not just to your task, but to your entire system.

**Token consumption without Intent Layer:**

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT EXPLORING 2.5M TOKEN CODEBASE                        │
├─────────────────────────────────────────────────────────────┤
│  Query tokens                          ~500                 │
│  Exploration overhead (ls, grep)       ~15k                 │
│  Relevant code found                   ~10k                 │
│  Dead ends & noise                     ~15k+                │
│  ─────────────────────────────────────────────              │
│  TOTAL: 40k+ tokens consumed                                │
│  RESULT: Critical files missed, bugs not found              │
└─────────────────────────────────────────────────────────────┘
```

**Why noise actively degrades quality:**

Transformers weight every token against every other token. Irrelevant context doesn't just waste budget—it drowns out signal. Misleading tests, overgeneralized docs, unrelated files all compete for attention with the actual implementation target.

**Same task WITH Intent Layer:**

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT WITH INTENT LAYER                                    │
├─────────────────────────────────────────────────────────────┤
│  Intent Layer context                  ~16k                 │
│  Relevant code (targeted)              ~16k                 │
│  ─────────────────────────────────────────────              │
│  TOTAL: ~32k tokens                                         │
│  RESULT: Bug found—agent knew exactly where to look         │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Concept

**The ceiling on AI results isn't model intelligence—it's what the model sees before it acts.**

Senior engineers carry mental models of system boundaries, invariants, and critical contracts accumulated through years of experience. The Intent Layer captures this tribal knowledge and makes it automatically available to every agent on every task.

Two primary goals:
1. **Compress context efficiently** — distill large code areas into minimum necessary tokens
2. **Surface hidden context** — capture architectural decisions, invariants, and contracts that code alone cannot express

---

## Architecture

Intent Nodes form a sparse tree overlaid on your codebase:

```
┌─────────────────────────────────────────────────────────────┐
│                     ROOT INTENT NODE                        │
│              (project-wide: AGENTS.md/CLAUDE.md)            │
│         ┌─────────────────────────────────────┐             │
│         │  • Project purpose                  │             │
│         │  • Architectural invariants         │             │
│         │  • Cross-cutting concerns           │             │
│         └─────────────────────────────────────┘             │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  /payments/  │ │   /users/    │ │   /orders/   │
│  AGENTS.md   │ │  AGENTS.md   │ │  AGENTS.md   │
└──────┬───────┘ └──────────────┘ └──────────────┘
       │
       ├──────────────────┐
       ▼                  ▼
┌────────────────┐ ┌────────────────┐
│ /validators/   │ │ /settlement/   │
│   AGENTS.md    │ │   AGENTS.md    │
└────────────────┘ └────────────────┘
```

**Key behavior:** When an Intent Node loads, all ancestor nodes automatically load with it. A node covers its directory and all subdirectories.

---

## T-Shaped Context Loading

When an agent works on `/payments/validators/`:

```
        LOADED                      NOT LOADED
        ──────                      ──────────
     ┌──────────┐
     │  ROOT    │  ◄── always loaded (broad)
     └────┬─────┘
          │
     ┌────┴─────┐
     │ payments │  ◄── ancestor loaded           /users/, /orders/
     └────┬─────┘                                 (siblings skipped)
          │
   ┌──────┴──────┐
   │ validators  │  ◄── target (deep)            /settlement/
   └─────────────┘                               (sibling skipped)
```

This creates a **T-shaped view**: broad high-level context plus specific detail where needed.

---

## Intent Node Structure

A healthy Intent Node is **small but dense**—the briefing you'd give a senior engineer before they work in that area.

```markdown
# /payments/AGENTS.md

## Purpose
Payment processing domain boundary.
Owns: transaction lifecycle, amount validation, currency handling.
Does NOT own: user identity, order fulfillment.

## Entry Points
- `processPayment()` — main orchestrator
- `refund()` — reversal flow

## Contracts (Invariants)
- All amounts: cents (integer)
- Currency: ISO 4217 codes only
- Idempotency keys required on all mutations

## Usage Patterns
```typescript
// Canonical payment creation
const result = await processPayment({
  amountCents: 1999,
  currency: 'USD',
  idempotencyKey: uuid()
});
```

## Anti-Patterns
❌ Never call settlement directly from validators
❌ No floating point for money
❌ Don't bypass idempotency checks in tests

## Pitfalls
- `PaymentError` vs `ValidationError` — use former for business rules, latter for input shape
- Settlement retries are automatic; don't implement retry logic in callers

## Downlinks
- ./validators/AGENTS.md — input validation rules
- ./settlement/AGENTS.md — external processor integration

## Outlinks
- /docs/adr/003-payment-idempotency.md — why idempotency matters
- /docs/diagrams/payment-flow.png — visual flow
```

### Downlinks vs Outlinks

**Downlinks** point to child Intent Nodes—agents follow them for progressive disclosure when they need deeper context in a subsystem.

**Outlinks** reference external documentation: architecture decision records, diagrams, runbooks. These are for human/agent reference when specialized knowledge is needed.

---

## Harness Integration

Different agent harnesses auto-load different files:

| Harness | Auto-loaded file |
|---------|------------------|
| Claude Code | `CLAUDE.md` |
| Codex / GitHub Copilot | `AGENTS.md` |
| Cursor | `.cursor/rules`, skill files |

**"Intent Node" is semantic, not a specific filename.** Survey which tools your team uses and ensure nodes auto-load across all of them.

**Multi-tool setup options:**
- Symlinks: `AGENTS.md` → `CLAUDE.md`
- CI validation: ensure all Intent Node formats stay in sync
- Custom harness configuration

---

## Fractal Compression

Each layer compresses the layer below, standing on already-compressed context:

```
Layer          Tokens    Compresses
─────          ──────    ──────────
Raw code       200k      —
Leaf node      20k       raw code → 10:1
Parent node    2k        child nodes → 10:1
Root node      500       parents → 4:1

Total compression: ~400:1
```

**Key insight:** When capturing a parent, you summarize child Intent Nodes—not the raw code they cover. This enables **progressive disclosure at scale**.

---

## Least Common Ancestor (LCA) Pattern

**Rule:** Place facts in the shallowest Intent Node where the fact is always relevant.

```
Problem: shared-types.ts used by payments/ AND orders/

        ┌─────────┐
        │  ROOT   │  ◄── shared-types docs go HERE
        └────┬────┘      (LCA of both consumers)
             │
     ┌───────┴───────┐
     ▼               ▼
┌─────────┐    ┌─────────┐
│payments │    │ orders  │
└─────────┘    └─────────┘
     │               │
     └───────┬───────┘
             ▼
      both reference
      shared-types.ts
```

**Why LCA matters:**
1. **No duplication** — fact exists in one place
2. **Loads when needed** — both consumers get it via ancestor loading
3. **No drift** — single source of truth
4. **Doesn't over-load** — won't appear for unrelated paths

---

## Building It

### Semantic Boundaries

Place Intent Nodes where responsibilities shift, contracts matter, or complexity warrants context.

**Good boundaries:**
- Domain boundaries (payments, users, orders)
- Subsystem interfaces (validators, processors)
- Integration points (external APIs, databases)
- Areas with non-obvious invariants

**Bad boundaries:**
- Arbitrary folder splits
- Single-file utilities
- Test directories (unless complex test infrastructure)

### Chunking Strategy

**Target:** 20k-64k *source* tokens per semantic unit (best compression ratio). These compress to ~1-3k token intent nodes.

**Similar code compresses better:**

```
GOOD (cohesive)                    BAD (mixed concerns)
───────────────                    ────────────────────
┌──────────────────┐               ┌──────────────────┐
│ PaymentValidator │               │ PaymentValidator │
│ PaymentRules     │               │ UserSerializer   │
│ PaymentErrors    │               │ OrderLogger      │
└──────────────────┘               └──────────────────┘
    ↓                                  ↓
Clean summary,                     Muddy summary,
high compression                   poor compression
```

**Capture order:** Easy areas first, hard areas last. Clarity compounds—understanding simple areas illuminates complex ones.

### Capture Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. CHUNK CODEBASE                                          │
│     Divide into 20k-64k source token semantic units         │
│     Group by shared responsibility, patterns, vocabulary    │
└─────────────────────┬───────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. CAPTURE LEAF NODES FIRST                                │
│     Start with well-understood areas                        │
│     Move to complex ones as context accumulates             │
└─────────────────────┬───────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. SUMMARIZE UPWARD                                        │
│     Parents compress child Intent Nodes (not raw code)      │
│     Each layer builds on stable, compressed context         │
└─────────────────────────────────────────────────────────────┘
```

### SME Interview Loop

For each chunk, agent and human iterate:

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT                          │  HUMAN (SME)              │
├─────────────────────────────────┼───────────────────────────┤
│  Analyzes code + accumulated    │                           │
│  state from previous chunks     │                           │
│                                 │                           │
│  Describes observations:        │                           │
│  "This appears to handle X..."  │                           │
│                                 │                           │
│  Asks clarifying questions:     │  Answers questions        │
│  "Is Y still in production?"    │  Corrects misunderstandings│
│  "Why does Z bypass the cache?" │  Explains history         │
│                                 │  Warns about landmines    │
│                                 │                           │
│  Drafts Intent Node             │  Reviews, refines         │
└─────────────────────────────────┴───────────────────────────┘
```

**Track unresolved items in shared state:**

```
┌─────────────────────────────────────────────────────────────┐
│  SHARED STATE (accumulates across chunks)                   │
├─────────────────────────────────────────────────────────────┤
│  Open questions:                                            │
│  • "Is legacy_processor still used?" → resolved in chunk 7  │
│  • "Who owns retry logic?" → answered when we hit settlement│
│                                                             │
│  Cross-references:                                          │
│  • validators mentions settlement invariants                │
│  • both need LCA placement decision                         │
│                                                             │
│  Emerging tasks:                                            │
│  • Dead code candidate: old_payment_handler.ts              │
│  • Refactor opportunity: duplicate validation in 3 places   │
└─────────────────────────────────────────────────────────────┘
```

As you progress through the tree, questions resolve. By reaching the root, everything resolves into the Intent Layer itself.

### Hierarchical Summarization

```
         ┌─────────────────────────────┐
         │         ROOT NODE           │
         │    Summarizes parents       │
         │    (500 tokens)             │
         └──────────────┬──────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌───────────────┐               ┌───────────────┐
│  PARENT NODE  │               │  PARENT NODE  │
│  Summarizes   │               │  Summarizes   │
│  children     │               │  children     │
│  (2k tokens)  │               │  (2k tokens)  │
└───────┬───────┘               └───────┬───────┘
        │                               │
   ┌────┴────┐                     ┌────┴────┐
   ▼         ▼                     ▼         ▼
┌──────┐  ┌──────┐             ┌──────┐  ┌──────┐
│ LEAF │  │ LEAF │             │ LEAF │  │ LEAF │
│ 20k  │  │ 20k  │             │ 20k  │  │ 20k  │
└──────┘  └──────┘             └──────┘  └──────┘
    │         │                    │         │
    ▼         ▼                    ▼         ▼
 [raw]     [raw]                [raw]     [raw]
 code      code                 code      code
 200k      200k                 200k      200k
```

### Node Contents Checklist

| Section | Description | Example |
|---------|-------------|---------|
| Purpose & scope | What it owns, what it explicitly doesn't | "Owns validation. Does NOT own persistence." |
| Entry points | Public API surface | `processPayment()`, `refund()` |
| Contracts/Invariants | Rules that must always hold | "Amounts in cents, never floats" |
| Usage patterns | Canonical correct examples | Code snippet showing idiomatic use |
| Anti-patterns | What NOT to do | "Never call X directly" |
| Dependencies | External requirements, edges | "Requires Redis for rate limiting" |
| Pitfalls | Common mistakes, confusing areas | "Error types are often misused" |
| Downlinks | Child Intent Nodes | `./validators/AGENTS.md` |
| Outlinks | External docs, ADRs, diagrams | `/docs/adr/003-idempotency.md` |

---

## Maintenance Flywheel

Prevents drift + continuously improves agent performance.

### Sync Process

On every merge:

```
┌──────────┐
│ PR Merge │
└────┬─────┘
     ▼
┌────────────────────┐
│ Detect changed     │
│ files              │
└────┬───────────────┘
     ▼
┌────────────────────┐
│ Identify affected  │
│ Intent Nodes       │
│ (by directory      │
│  coverage)         │
└────┬───────────────┘
     ▼
┌────────────────────┐
│ For each node      │◄─────────────────┐
│ (LEAF-FIRST):      │                  │
│ ┌────────────────┐ │                  │
│ │ Read diff +    │ │                  │
│ │ existing node  │ │                  │
│ └───────┬────────┘ │                  │
│         ▼          │                  │
│ ┌────────────────┐ │                  │
│ │ Re-summarize   │ │                  │
│ │ if behavior    │ │                  │
│ │ changed        │ │                  │
│ └───────┬────────┘ │                  │
│         ▼          │                  │
│ ┌────────────────┐ │     ┌───────────┴───────────┐
│ │ Propose update │ │────▶│ Next affected node    │
│ └────────────────┘ │     │ (work upward)         │
└────────────────────┘     └───────────────────────┘
     ▼
┌────────────────────┐
│ Human review       │
│ (like code review) │
└────────────────────┘
```

**Manual:** ~5-10 minutes per PR
**Automated:** CI triggers agent to propose updates

### Reinforcement Learning Loop

Agents surface missing context through usage:

```
┌─────────────────────────────────────────────────────────────┐
│                    AGENT EXECUTION                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │ Edge cases │  │ Update     │  │ Feedback   │
   │ discovered │  │ proposals  │  │ signals    │
   └─────┬──────┘  └─────┬──────┘  └─────┬──────┘
         │               │               │
         │  • Code ↔ node contradictions │
         │  • Undocumented patterns      │
         │  • Refined pitfalls           │
         │  • Corrected invariants       │
         │  • Dead code flagging         │
         │               │               │
         └───────────────┼───────────────┘
                         ▼
              ┌─────────────────────┐
              │ UPDATE INTENT LAYER │
              └─────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │ Better context for  │
              │ future agents       │
              └─────────────────────┘
```

**Key insight:** Your codebase becomes a reinforcement learning environment. Agents get finetuned to your system through better context, not expensive model training.

### Automation Pipeline

```
MANUAL                              AUTOMATED
──────                              ─────────
┌─────────────┐                     ┌─────────────┐
│ Human reads │                     │ CI trigger  │
│ diff        │                     │ on merge    │
└──────┬──────┘                     └──────┬──────┘
       ▼                                   ▼
┌─────────────┐                     ┌─────────────┐
│ Human edits │                     │ Agent reads │
│ AGENTS.md   │                     │ diff + node │
└──────┬──────┘                     └──────┬──────┘
       ▼                                   ▼
┌─────────────┐                     ┌─────────────┐
│ Human       │                     │ Agent       │
│ commits     │                     │ proposes PR │
└─────────────┘                     └──────┬──────┘
                                           ▼
                                    ┌─────────────┐
                                    │ Human       │
                                    │ approves    │
                                    └─────────────┘
```

---

## Anti-Patterns

### Structure Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Dumping everything in root | Balloons to 15k+ tokens, overwhelms context | Hierarchical decomposition |
| Duplicating info already in code | Waste + drift risk | Capture what code cannot express |
| Structuring for human readers | Tokens wasted on prose | Optimize for agent consumption |
| No maintenance ownership | Drift, stale context | Assign owners, CI enforcement |
| Copying files across tools | Drift between CLAUDE.md/AGENTS.md | Symlinks or sync validation |

### Chunking Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Force-combining disparate code | Poor compression, muddy summaries | Group by shared responsibility |
| Chunks too small (<10k tokens) | Overhead dominates | Merge related small areas |
| Mixed concerns in single node | Unclear scope | Split by domain boundary |

### Content Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Duplicating facts in multiple leaves | Drift, wasted tokens | Use LCA placement |
| Cross-cutting knowledge only at root | Loads everywhere unnecessarily | Place at appropriate LCA |
| Missing negative examples | Agents repeat common mistakes | Add anti-patterns section |
| Vague purpose statements | Doesn't help agent narrow scope | Be specific: owns X, not Y |

---

## Investment & Payoff

### Time Investment

| Codebase Size | Estimated Time | Notes |
|---------------|----------------|-------|
| 100k tokens | 3-5 hours | Experienced practitioner |
| 100k tokens | 6-15 hours | First-time builder |
| 500k tokens | 15-25 hours | With established patterns |

### Payoff

**Individual impact:**
- Agents behave like senior engineers automatically
- ~50% effectiveness improvement on solo work
- Hard-won explanations reused forever

**Team impact:**
- Enable longer tasks and parallel agents
- New team members productive faster (agents carry context)
- Context compounds across all agent interactions

**Scaling unlock:**
- Individual engineers with strong Intent Layers operate like small teams
- Cross-repo federation enables agent coordination across dozens of repositories

### Maintenance Overhead

| Approach | Per-PR Time | Notes |
|----------|-------------|-------|
| Manual | 5-10 min | Human reviews diff, updates nodes |
| Automated | ~0 min | Agent proposes, human approves |

---

## Key Semantics

| Concept | Meaning |
|---------|---------|
| Intent Node | Small, opinionated markdown file at semantic boundary |
| Intent Layer | Collection of Intent Nodes forming sparse tree overlaid on codebase |
| Downlink | Pointer to child Intent Node (for progressive disclosure) |
| Outlink | Reference to external docs, ADRs, diagrams |
| [Ancestor loading](#t-shaped-context-loading) | Parent nodes automatically included when child loads |
| [T-shaped view](#t-shaped-context-loading) | Broad high-level context + deep detail where working |
| Progressive disclosure | Load minimum context upfront, drill into detail as needed |
| [Fractal compression](#fractal-compression) | Each layer compresses already-compressed layer below |
| [LCA](#least-common-ancestor-lca-pattern) | Place shared facts at shallowest common ancestor |
| Semantic boundary | Where responsibilities shift, contracts matter, complexity warrants context |
| Optimal chunk | 20k-64k *source* tokens per node (compresses to ~1-3k output) |
| Coverage | A node covers its directory and all subdirectories |
