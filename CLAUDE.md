# travis Harness -- Project Context

> **Plugin**: `travis-harness` v0.2.1 | **Repo**: `https://github.com/PoleBarnes/travis-harness`

---

## Travis Hendrickson -- Company Context

Personal development harness for Travis Hendrickson — solo full-stack engineering projects.

Each employee installs the same plugin on their machine. Credentials stay local -- the plugin defines connections, never secrets. Company upgrades the plugin and everyone's capabilities upgrade simultaneously.

---

## Team Members & Roles

| Person | Role | Responsibilities |
|--------|------|-----------------|
| **Travis Hendrickson** | Owner | Solo developer |

---

## Linear Project & Workflow

- Organization URL: `https://linear.app/travis-hendrickson`
- Project keys: `TH`  -- all work items reference `Requirement: REQ-travis-XXX-NNN`
- Query language: Linear GraphQL API
- Workflow: `Todo -> In Progress -> In Review -> Done`
- Work items must be **self-contained** (agent-executable) with summary, description, acceptance criteria, component, priority
- Bug reports include: steps to reproduce, expected vs actual, severity (Critical/High/Medium/Low)
- All work traceable to `doc/requirements.md`; out-of-scope requires requirement change proposal

---

## Git Conventions

- **Repos**: Linear Repos at `https://github.com/PoleBarnes`
- **Branches**: `main` (stable) + feature branches: `feature/travis-123-short-description` or `fix/travis-456-bug-title`
- **Commits**: `travis-123: <type>: Short description` -- types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`
- **PRs**: Title includes work item ID; description includes what/why/testing/work item link; require review; target `main`
- **CI/CD**: GitHub Actions
- Commits serve as audit trail ("breadcrumbs")

> See `skills/pr/SKILL.md` for code review standards.
> See `skills/timecard/SKILL.md` for time tracking details.

---

## Key Resources

| Resource | Location |
|----------|----------|
| Requirements | `doc/requirements.md` (canonical source of truth) |
| MCP Server Research | `doc/mcp-server-research.md` |
| Model Selection Rationale | `doc/model-rationale.md` |
| Credential Setup | `scripts/setup-credentials.sh` |
| Plugin Manifest | `.claude-plugin/plugin.json` |
| MCP Configuration | `.mcp.json` |
| Working Context | `.harness/working-context.md` (gitignored, local session memory) |

---

## Plugin Architecture

> See `doc/requirements.md` section 3 for full directory structure.

### MCP Servers

| Server | Package | Covers |
|--------|---------|--------|
| `github` | `npx -y` (Node.js) | Github |
| `linear` | `npx -y` (Node.js) | Linear |


---

## Design Principles

| ID | Principle | Description |
|----|-----------|-------------|
| DP-1 | **Manual control first** | All AI actions via CLI with user oversight. Ctrl+C kills immediately. |
| DP-2 | **Incremental integration** | Each MCP server and skill is modular. Plugin grows over time. |
| DP-3 | **Credentials stay local** | Plugin defines connections, never credentials. Users provision their own keys. |
| DP-4 | **Breadcrumbs everywhere** | All work leaves traces (commits, work item updates, time entries). |
| DP-5 | **Spec-driven** | Requirements define what to build. AI executes. Humans verify. |
| DP-6 | **Portability considered** | Architecture decisions consider future portability to Open Code / Gemini CLI. |
| DP-7 | **100% test coverage** | All plugin components must have tests with verifiable acceptance criteria. |

---

## Quality Gates

| Gate | Value | Description |
|------|-------|-------------|
| Coverage threshold | 80% | Minimum code coverage percentage for all changes |
| Proportionality | `auto` | Tier selection: `auto` uses standard rules (lines changed + type + sensitivity); fixed values (`minimal`, `standard`, `comprehensive`) force that tier for all work items |

---

## Security Rules

- **NEVER** commit credentials, API keys, tokens, or secrets to the repo
- `.mcp.json` contains connection definitions with empty credential values
- Users populate credentials locally via environment variables or `.env` (gitignored)
- All write operations (work item creation, email sends, time entries) require user confirmation
- OAuth scopes must be minimum necessary
- Git history must pass secret scanning with zero matches

> See `doc/requirements.md` section 10 for phased rollout details.

---

## Quick Reference

### Requirement IDs
- `REQ-travis-PLG-*` -- Plugin structure | `REQ-travis-MCP-*` -- MCP integrations | `REQ-travis-SKL-*` -- Skills
- `REQ-travis-CTX-*` -- Context/config | `REQ-travis-NFR-*` -- Non-functional | `REQ-travis-TST-*` -- Testing

### Platforms Supported
- WSL2 / Ubuntu 22.04+ (primary development) | macOS | Node.js 18+
