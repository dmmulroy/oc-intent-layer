# OpenCode Configuration Summary

## Config Files

- **Format**: JSON/JSONC, files merge (not replace)
- **Locations** (precedence order):
  1. `OPENCODE_CONFIG` env var
  2. `opencode.json` in project root
  3. `~/.config/opencode/opencode.json`
- Variable substitution: `{env:VAR}`, `{file:path}`

## AGENTS.md (Rules)

- **Project**: `AGENTS.md` at root (commit to VCS)
- **Global**: `~/.config/opencode/AGENTS.md`
- `/init` generates one by scanning project
- Can reference external files: `@docs/filename.md` for lazy loading
- `instructions` array in config supports globs for monorepos

**Discovery mechanism**: Walks up from cwd to git worktree root; all files combine (not replace).

**Nested example:**
```
ecommerce/
├── .git/
├── AGENTS.md                    # org-wide: code style, PR process
├── services/
│   ├── AGENTS.md                # shared service patterns
│   ├── payments/
│   │   ├── AGENTS.md            # PCI rules, Stripe patterns
│   │   └── src/
│   └── inventory/
│       ├── AGENTS.md            # stock sync rules
│       └── src/
└── libs/
    └── shared/
        ├── AGENTS.md            # pkg publish rules
        └── src/
```

**Discovery by location:**

| cwd | AGENTS.md files loaded (combined) |
|-----|-----------------------------------|
| `services/payments/src/` | payments → services → root → global |
| `services/inventory/` | inventory → services → root → global |
| `libs/shared/` | shared → root → global |
| `ecommerce/` (root) | root → global |

**Pattern**: General rules at root, domain-specific rules deeper. All combine into single context.

## Agents

- **Primary**: Tab to cycle; `build` (full tools) and `plan` (restricted) built-in
- **Subagents**: Invoke via `@name`; `general` and `explore` built-in
- **Markdown config**: `.opencode/agent/<name>.md` or `~/.config/opencode/agent/`

```yaml
---
description: Required brief summary
mode: primary|subagent|all
model: anthropic/claude-sonnet-4-5
temperature: 0.7
maxSteps: 10
tools:
  write: false
  bash: true
permission:
  bash: ask|allow|deny
---
System prompt here
```

## Skills

- **Name pattern**: `^[a-z0-9]+(-[a-z0-9]+)*$` (lowercase, hyphens, no consecutive hyphens)

**Discovery locations** (searched at each level):
1. `.opencode/skill/<name>/SKILL.md`
2. `.claude/skills/<name>/SKILL.md` (Claude-compatible)

**Global locations**:
- `~/.config/opencode/skill/<name>/SKILL.md`
- `~/.claude/skills/<name>/SKILL.md`

**Discovery mechanism**: Walks up from cwd to git worktree root, loading matches at each level. Global paths loaded simultaneously.

**Loading**: Skills listed in `skill` tool description; full content loaded on-demand via `skill({ name: "skill-name" })`

**Nested example:**
```
ecommerce/
├── .git/
├── .opencode/skill/
│   └── db-migrate/SKILL.md           # org-wide migrations
├── services/
│   ├── .opencode/skill/
│   │   └── service-scaffold/SKILL.md # shared service patterns
│   ├── payments/
│   │   └── .opencode/skill/
│   │       ├── stripe-refund/SKILL.md
│   │       └── pci-audit/SKILL.md
│   └── inventory/
│       └── .opencode/skill/
│           └── stock-sync/SKILL.md
└── libs/shared/
    └── .opencode/skill/
        └── publish-pkg/SKILL.md
```

**Discovery by location:**

| cwd | Skills discovered |
|-----|-------------------|
| `services/payments/` | `stripe-refund`, `pci-audit`, `service-scaffold`, `db-migrate`, + global |
| `services/inventory/` | `stock-sync`, `service-scaffold`, `db-migrate`, + global |
| `libs/shared/` | `publish-pkg`, `db-migrate`, + global |
| `ecommerce/` (root) | `db-migrate`, + global |

**Pattern**: Domain-specific skills deep, shared ops at root. Skills closer to cwd supplement parent skills.

```yaml
---
name: my-skill        # required, must match dir
description: ...      # required, max 1024 chars
license: MIT          # optional
compatibility: ...    # optional
metadata: {}          # optional k/v
---
Skill content...
```

**Permission control**:
- `allow`: loads immediately
- `ask`: prompts user before access
- `deny`: hidden from agent, access rejected

```json
{ "permission": { "skill": { "pattern": "allow|deny|ask" } } }
```

## Commands

- **Invoke**: `/command-name`
- **Location**: `.opencode/command/<name>.md` or in `opencode.json` under `command`

```yaml
---
description: Brief desc
agent: build
model: anthropic/...
subtask: false
---
Template with $ARGUMENTS or $1 $2
Include file: @src/file.ts
Shell output: !`npm test`
```

JSON alternative:

```json
{
  "command": {
    "test": {
      "template": "Run tests...",
      "description": "...",
      "agent": "build"
    }
  }
}
```

**Built-in**: `/init`, `/undo`, `/redo`, `/share`, `/help`

## Server

- **Command**: `opencode serve [--port <number>] [--hostname <string>]`
- **Defaults**: port `4096`, hostname `127.0.0.1`
- **mDNS**: `--mdns` flag enables service discovery
- **OpenAPI docs**: `http://<hostname>:<port>/doc`
- TUI runs as client to server; `serve` starts standalone headless instance
- Multiple instances allowed on different ports

## SDK

- **Install**: `npm install @opencode-ai/sdk`

```javascript
// Start new server
import { createOpencode } from "@opencode-ai/sdk"
const { client } = await createOpencode()

// Connect to existing
import { createOpencodeClient } from "@opencode-ai/sdk"
const client = createOpencodeClient({ baseUrl: "http://localhost:4096" })
```

**Options**: `hostname`, `port`, `timeout` (ms, default 5000), `config`

**API Categories**:
- `Global`: health, version
- `App`: logging, agent listings
- `Project`: project/path info
- `Sessions`: create, manage, prompt, revert, permissions
- `Files`: search, read, status
- `TUI`: control terminal programmatically
- `Auth`: set credentials
- `Events`: SSE subscriptions

## Plugins

- **Location**: `.opencode/plugin/` (project) or `~/.config/opencode/plugin/` (global)
- **npm packages**: Specify in `opencode.json`, auto-installed via Bun to `~/.cache/opencode/node_modules/`
- **Types**: `@opencode-ai/plugin`

**Load order**: global config → project config → global plugin dir → project plugin dir

**Context params**: `project`, `directory`, `worktree`, `client` (SDK), `$` (Bun shell)

**Events**:
- `command.executed`, `file.edited`, `file.watcher.updated`
- `session.created`, `session.compacted`, `session.updated`, `session.idle`
- `tool.execute.before`, `tool.execute.after`
- `tui.prompt.append`, `tui.command.execute`, `tui.toast.show`
- Message, permission, LSP events

**Custom tools**: Use `tool()` helper with Zod schemas

**Dependencies**: Add `package.json` to plugin dir; OpenCode runs `bun install` at startup

## Sources

- [OpenCode Docs](https://opencode.ai/docs)
- [Config](https://opencode.ai/docs/config)
- [Agents](https://opencode.ai/docs/agents)
- [Skills](https://opencode.ai/docs/skills)
- [Rules](https://opencode.ai/docs/rules)
- [Commands](https://opencode.ai/docs/commands)
- [Server](https://opencode.ai/docs/server)
- [SDK](https://opencode.ai/docs/sdk)
- [Plugins](https://opencode.ai/docs/plugins)
