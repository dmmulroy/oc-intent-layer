# Intent Layer Tools for OpenCode

Bootstrap and maintain hierarchical AGENTS.md intent nodes for any codebase.

## What is an Intent Layer?

An intent layer embeds architectural knowledge directly in your codebase via AGENTS.md files. AI agents load this context automatically, behaving like senior engineers who already understand your system.

**Without intent layer:** Agents waste tokens exploring, miss critical files, lack tribal knowledge.

**With intent layer:** Agents know where to look, understand contracts and invariants, avoid historical landmines.

See [intent-layer-guide.md](./intent-layer-guide.md) for full theory.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sst/oc-intent-layer/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/sst/oc-intent-layer.git
cd oc-intent-layer
./install.sh
```

This installs skills and commands globally to `~/.config/opencode/`.

## Usage

### Bootstrap a project

```bash
cd your-project
opencode
/intent-init
```

This will:
1. Analyze your codebase structure and token counts
2. Propose a capture plan (leaf-first order)
3. Interview you about each area (agent describes, you correct)
4. Generate AGENTS.md files
5. Install a pre-push hook to warn about stale nodes

### Capture a single node

```bash
/intent-capture ./services/payment/
```

Use after understanding an area well, or to re-capture after major changes.

### Sync after code changes

```bash
/intent-sync
```

Detects which AGENTS.md files are affected by recent changes and proposes updates.

## Commands

| Command | Description |
|---------|-------------|
| `/intent-init` | Full bootstrap: analyze, capture all nodes, install hook |
| `/intent-capture [path]` | Capture single directory (default: cwd) |
| `/intent-sync` | Update nodes affected by recent changes |

## Skills

| Skill | Description |
|-------|-------------|
| `@intent-chunk` | Analyze codebase, calculate tokens, output capture order |
| `@intent-capture` | Interactive SME interview, generate AGENTS.md |

## How It Works

### Fractal Compression

Each layer summarizes the layer below:

```
Raw code (200k tokens)
    → Leaf AGENTS.md (20k) — 10:1 compression
        → Parent AGENTS.md (2k) — 10:1 compression
            → Root AGENTS.md (500) — 4:1 compression

Total: ~400:1 compression
```

Parents read child AGENTS.md files, never raw code. This enables progressive disclosure at scale.

### Capture Order

**Leaf-first, easy-first.** Children captured before parents. Simple modules before complex ones.

Why:
- Parents summarize children, so children must exist first
- Simple areas illuminate complex ones (context compounds)
- Open questions resolve during parent capture (LCA lifting)

### T-Shaped Context Loading

OpenCode automatically loads ancestor AGENTS.md files:

```
Working in /services/payment/validators/:

Loaded:
  /AGENTS.md                           (root)
  /services/AGENTS.md                  (ancestor)
  /services/payment/AGENTS.md          (ancestor)
  /services/payment/validators/AGENTS.md (target)

Not loaded:
  /services/billing/AGENTS.md          (sibling branch)
```

Siblings accessible via parent downlinks when needed.

## Requirements

- [OpenCode](https://opencode.ai) CLI
- Git
- Optional: `tiktoken` (Python) or `js-tiktoken` (Node) for accurate token counts

## License

MIT
