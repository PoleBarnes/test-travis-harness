# Harness Core v0.3.0 -- Unified Design Document

> **Status**: DRAFT | **Date**: 2026-03-12 | **Author**: Design consolidation from PRs #36, #43, #44 + Linear TRA-85 + F3 process meeting (2026-03-12)

---

## 1. Executive Summary

This design consolidates three open PRs, three GitHub issues, and five Linear issues into a single cohesive architecture for harness-core v0.3.0. The result is a **skills-only, flow-based, quality-gated** plugin framework with CI-integrated eval testing.

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| Remove all 5 agents; absorb logic into skills | Agents added indirection and token overhead without proportional value |
| Replace sprint ceremonies with flow-based development | Continuous flow + triage branches better fits multi-project teams |
| Add mandatory documentation deliverables to skills | Quality gating prevents incomplete work from reaching "Done" |
| Add LLM-powered eval testing to CI | Validates skill routing accuracy as skills absorb more responsibility |
| Incorporate GTD methodology from Forge design | Capture/Clarify/Organize/Reflect/Engage maps naturally to triage/plan/implement/pm/vv |
| Add `/catchup` skill for morning briefing | F3 meeting confirmed cross-tool communication triage is a top pain point |
| Breadcrumb-based automated time tracking | Mine activity across git, email, chat, Jira to auto-generate timecards |
| AI-assisted estimation from historical data | Correlate new tasks with historical Jira data for data-driven estimates |
| Jira-centric capture with approval workflow | Items enter as "unapproved", PM approves → scheduled; AI populates all fields |

---

## 2. Architecture Overview

### 2.1 Layer Model

```
Layer 5: User Interface     CLI slash commands (/prefix:skill)
Layer 4: Skills (12)        Self-contained workflows with inline logic
Layer 3: Quality Gates      Documentation deliverables + eval testing
Layer 2: MCP Integration    13 composable integration modules
Layer 1: Builder Pipeline   Jinja2 templates + customer configs → output repos
Layer 0: State & Hooks      Session persistence, bash guards, dep checking
```

### 2.2 Component Inventory (Post-Consolidation)

| Component | Count | Change from v0.2.0 |
|-----------|-------|---------------------|
| Skills (user-facing) | 13 | -4 removed, +3 added |
| Skills (internal) | 1 | unchanged (review) |
| Agents | 0 | -5 removed |
| Commands | 0 | -1 removed (dashboard) |
| Integrations | 13 | unchanged |
| Hooks | 3 | unchanged |
| Test suites | 8 | +1 (eval suite) |

---

## 3. Skill Architecture (Post-Consolidation)

### 3.1 Final Skill Inventory

| # | Skill | Command | Absorbed From | Modes |
|---|-------|---------|---------------|-------|
| 1 | **triage** | `/triage` | triage-agent + agile-requirements | analyze, scope-check, duplicate-check, branch-create |
| 2 | **plan** | `/plan` | project-manager (partial) + sprint-plan | list, synthesize, single-branch |
| 3 | **pm** | `/pm` | project-manager (partial) + standup + retro | skills, suggest, project-summary, detail |
| 4 | **implement** | `/implement` | (self, simplified) | parse, decompose, delegate, verify, document |
| 5 | **pr** | `/pr` | code-reviewer | create, review, triage |
| 6 | **vv** | `/vv` | vv-engineer | scope, trace, verify, validate-ac, audit-docs, report |
| 7 | **harness** | `/harness` | harness-engineer + dashboard cmd | audit, diagnose, check-mcp, dashboard |
| 8 | **email** | `/email` | -- | triage, summarize, draft |
| 9 | **timecard** | `/timecard` | -- | generate, review, submit |
| 10 | **update** | `/update` | -- | check, apply |
| 11 | **setup** | `/setup` | -- | deps, creds, statusline, check |
| 12 | **catchup** | `/catchup` | -- (NEW from F3 meeting) | morning-briefing, comms-triage, day-plan |
| 13 | **estimate** | `/estimate` | -- (NEW from F3 meeting) | historical-analysis, three-point, compare |
| 14 | **review** | (internal) | code-reviewer (partial) | multi-reviewer simulation |

### 3.2 Agent-to-Skill Absorption Map

```
code-reviewer agent ──────► /pr (Step 6: inline review team)
                     ├────► /review (internal: multi-reviewer simulation)

triage-agent ─────────────► /triage (full workflow, self-contained)

project-manager agent ────► /pm (prioritization, board analysis)
                     ├────► /plan (backlog synthesis, requirement drafting)

harness-engineer agent ───► /harness (audit, diagnose, dashboard)

vv-engineer agent ────────► /vv (traceability, AC validation, doc audit)
```

### 3.3 Removed Skills (Rationale)

| Skill | Why Removed | Where Logic Went |
|-------|-------------|-----------------|
| `/standup` | Duplicates native platform ceremony tools | `/pm` (flow-based context) |
| `/retro` | Sprint concept eliminated | `/pm` (continuous improvement via triage) |
| `/sprint-plan` | Replaced by flow-based planning | `/plan` (triage branch synthesis) |
| `/agile-requirements` | ISO 29148 enforcement moved to triage | `/triage` (scope check) + `/plan` (requirement drafting) |
| `dashboard` command | Absorbed into harness diagnostics | `/harness dashboard` mode |

---

## 4. Flow-Based Backlog System

### 4.1 Core Concept

Git branches and PRs replace sprint backlogs. Work flows continuously through a pipeline:

```
Disruption ─► /triage ─► triage/<name> branch
                              │
              ┌────────────── │ ──────────────┐
              │               ▼               │
              │    Open triage branches        │
              │    form the backlog            │
              │               │               │
              │               ▼               │
              │         /plan synthesize       │
              │         ┌─────┴─────┐         │
              │         ▼           ▼         │
              │   doc/requirements  work items │
              │         │           │         │
              │         ▼           ▼         │
              │       /implement ─► /pr       │
              │                     │         │
              │                     ▼         │
              │               merge + deliver │
              │                     │         │
              └──── new disruption ─┘─────────┘

/pm ── continuous visibility across all phases
/vv ── quality gate before delivery
```

### 4.2 Triage Branch Lifecycle

1. **Create**: `/triage` analyzes input, creates `triage/<description>` branch with structured document
2. **Review**: Team reviews triage documents (async, distributed)
3. **Synthesize**: `/plan` reads all `triage/*` branches, groups by component, synthesizes requirements
4. **Accept**: Merged triage branches = accepted into plan
5. **Execute**: Work items created in devops platform, flow to `/implement`
6. **Cleanup**: Processed triage branches optionally deleted

### 4.3 Triage Document Format

```markdown
# Triage: <title>

## Classification
- **Type**: bug | feature | scope-change | block | improvement
- **Severity**: critical | high | medium | low
- **Component**: <component-name>
- **Source**: user-report | meeting | code-review | monitoring | requirement-change

## Description
<detailed description>

## Reproduction Steps (if bug)
1. ...

## Scope Check
- **In-scope**: yes | no | partial
- **Related Requirements**: REQ-XXX-NNN
- **Impact Assessment**: <what changes if accepted>

## Proposed Action
- [ ] New requirement: REQ-XXX-NNN
- [ ] Modify existing: REQ-XXX-NNN
- [ ] New work item in <platform>
- [ ] Acceptance criteria: ...

## Decision
- **Status**: pending | accepted | rejected | deferred
- **Rationale**: ...
```

### 4.4 GTD Methodology Mapping (from TRA-85 Forge Design)

The flow-based system maps to GTD's five phases:

| GTD Phase | Harness Skill | Mechanism |
|-----------|---------------|-----------|
| **Capture** | `/triage` | Any disruption enters via triage — bugs, features, scope changes, meeting transcripts |
| **Clarify** | `/triage` | Scope check against requirements, duplicate detection, severity classification |
| **Organize** | `/plan` | Batch synthesis of triage branches into prioritized requirements and work items |
| **Reflect** | `/pm` | Continuous board review, WIP-first prioritization, blocker surfacing |
| **Engage** | `/implement` | Execute work items with documentation deliverables and quality gates |

### 4.5 Interrupt Handling (from TRA-85)

Interrupts follow the triage-first principle:

| Priority | Response | Example |
|----------|----------|---------|
| **P0 Critical** | Immediate `/triage` → direct to `/implement` | Production down, security breach |
| **P1 High** | `/triage` → fast-track through `/plan` | Customer-blocking bug, deadline risk |
| **P2 Medium** | `/triage` → normal backlog flow | Feature request, non-blocking bug |
| **P3 Low** | `/triage` → park in backlog | Tech debt, nice-to-have improvement |

### 4.6 F3 Process Insights (from 2026-03-12 meeting with David Thompson)

The F3 customer meeting validated the architecture and surfaced several concrete requirements:

#### 4.6.1 Jira-Centric Capture & Approval Workflow

F3 uses Jira as their single source of truth across hardware and software. Key workflow:

```
Customer request / meeting note / bug report
        │
        ▼
  /triage (capture into Jira as "unapproved")
        │
        ▼
  PM reviews in /pm → sets to "approved"
        │
        ▼
  BigPicture auto-schedules (soft/hard dependencies, resource availability)
        │
        ▼
  /implement → engineer works the task
```

**Implications for `/triage`**:
- Must create Jira tickets with status "unapproved" (not "To Do")
- Must populate ALL required fields (AI fills collaboratively — no incomplete tickets)
- Must support custom ticket types: Purchase Requests, Shipping Requests
- Must suggest milestone association during triage
- Must detect scope changes and flag for change order estimation

**Implications for `/pm`**:
- Surface unapproved items assigned to the PM as top priority
- Show items needing approval before engineers can start
- Cross-project view (F3 manages hardware + software + mechanical in single Jira)

#### 4.6.2 `/catchup` Skill (NEW)

Morning briefing that synthesizes across all communication channels:

```
/catchup
  ├─ Read unread emails (Gmail/Outlook via MCP)
  ├─ Read unread chat messages (Slack/Teams/Google Chat via MCP)
  ├─ Read today's calendar (meetings, deadlines)
  ├─ Check Jira for items needing attention (unapproved, blocked, overdue)
  ├─ Summarize what happened overnight
  └─ Suggest day plan: "Here's what I'd recommend you focus on today"
```

David Thompson confirmed this solves a major pain point: "Communications have only gotten worse... we spend so much time thrashing around."

#### 4.6.3 Breadcrumb Time Tracking (Enhanced `/timecard`)

Automated time tracking from cross-system activity breadcrumbs:

```
Activity Sources (MCP connections):
  ├─ Git: commits, PR reviews, branch activity → matched to work items
  ├─ Jira: status changes, comments, time logging
  ├─ Email: project-related threads
  ├─ Chat: channel activity, DMs
  ├─ Calendar: meeting attendance
  └─ Local: active window monitoring (optional, RescueTime-style)

Breadcrumb Algorithm:
  1. Collect all timestamped activity across sources
  2. Match each activity to a Jira ticket (AI correlation)
  3. Build timeline: activity A → ticket X (09:00-09:45), activity B → ticket Y (09:45-10:30)
  4. Generate time entries with auto-comments from activity context
  5. Submit to Jira time tracking fields AND sync to QBT/QuickBooks

Rules Engine:
  - No time entry for locked/past periods (QuickBooks constraint)
  - Auto-estimate "time remaining" based on historical data
  - Flag discrepancies between estimated and actual time
```

**Customer config additions**:
```yaml
time_tracking:
  platform: "jira"              # or quickbooks-time, harvest, ruddr
  sync_target: "quickbooks"     # secondary system for payroll
  lock_past_periods: true       # prevent backdated entries
  breadcrumb_sources:           # which MCP connections feed time data
    - git
    - jira
    - email
    - chat
```

#### 4.6.4 `/estimate` Skill (NEW)

AI-assisted estimation using historical Jira data:

```
/estimate <task-description-or-jira-key>
  ├─ Mine historical Jira data for similar tasks
  │     └─ Compare: task type, component, description similarity
  ├─ Correlate estimates vs. actuals from past work
  ├─ Generate three-point estimate (best/most-likely/worst)
  │     └─ Use F3's weighted formula: (O + 4M + P) / 6
  ├─ Show confidence interval based on data quality
  └─ Populate Jira estimate fields automatically
```

David Thompson: "I would love that... one of the base things we still need to solve."

#### 4.6.5 Meeting Transcript → Triage Pipeline

```
/triage <paste meeting transcript or path to file>
  ├─ AI parses transcript for:
  │     ├─ Action items → individual triage items
  │     ├─ Decisions → requirement updates
  │     ├─ Scope changes → change order triggers
  │     └─ Questions → items needing follow-up
  ├─ For each identified item:
  │     ├─ Suggest Jira ticket creation
  │     ├─ Suggest assignee (from team config)
  │     ├─ Suggest milestone
  │     └─ Show to PM for approval before creating
  └─ PM approves/rejects each suggestion collaboratively
```

#### 4.6.6 Regulated Industry Considerations

F3 works in medical/aviation-adjacent firmware. Key V&V implications:
- Validation focuses on **output** (the software), not the AI tool itself
- All AI-generated artifacts must be human-reviewed before acceptance
- Traceability chain must be complete: Requirement → Implementation → Test → Validation
- Engineering journal captures AI involvement for audit trail

---

## 5. Quality Gating System

### 5.1 Documentation Deliverables (from PR #44, migrated to skills-only)

Every work item must produce documentation artifacts before "Done". Enforcement is distributed across skills:

| Deliverable | Produced By | Audited By | Format |
|-------------|-------------|------------|--------|
| Software Design Document (SDD) | `/implement` Step 5 | `/vv` | Markdown in `doc/design/` |
| Linter Report | `/implement` Step 5 | `/vv` | Clean run or documented exceptions |
| Code Coverage Analysis | `/implement` Step 5 | `/vv` | Percentage vs. threshold |
| Unit Test Results | `/implement` Step 5 | `/vv` | All passing |
| Regression Test Results | `/implement` Step 5 | `/vv` | Zero regressions |
| V&V Audit Report | `/vv` | `/pr` review | Traceability matrix + gap analysis |
| Diagrams | `/implement` Step 5 | `/vv` | Mermaid (preferred), PlantUML, or ASCII |
| Engineering Journal | `/implement` Step 5 | `/vv` | `doc/journal/YYYY-MM-DD-<work-item-id>.md` |

### 5.2 Proportionality Rules

Not all work items require all 8 artifacts. Scale requirements to scope:

| Scope | Required Artifacts | When |
|-------|-------------------|------|
| **Minimal** | Linter report, unit test results, regression test results | Bug fixes, small refactors, config changes |
| **Standard** | Minimal + SDD + code coverage + V&V audit | Features, medium tasks, integrations |
| **Comprehensive** | All 8 artifacts | Architecture changes, security-sensitive work, new skills |

Scope determination is based on:
- Work item type (bug vs. feature vs. architecture)
- Lines changed (threshold: <50 = minimal, 50-300 = standard, >300 = comprehensive)
- Component sensitivity (security, auth, data handling → always comprehensive)

### 5.3 Documentation Enforcement Points

```
/implement
  ├─ Step 1-4: Parse, decompose, code, test
  ├─ Step 5: Produce documentation deliverables (NEW)
  │     └─ Scope-appropriate artifacts per proportionality rules
  ├─ Step 6: /pr create + review
  │     └─ /pr review invokes inline review team:
  │           ├─ Code Reviewer (OWASP, standards, quality)
  │           ├─ Test Auditor (coverage, boundaries, error paths)
  │           └─ V&V Engineer (traceability, AC validation, doc audit)
  └─ Step 7: Report

/vv (standalone audit)
  ├─ Step 1: Identify scope
  ├─ Step 2a: Build traceability chain (Req → Impl → Tests)
  ├─ Step 2b: Verify implementation
  ├─ Step 2c: Validate acceptance criteria quality
  ├─ Step 2d: Audit documentation deliverables (NEW)
  │     └─ Check all scope-appropriate artifacts PRESENT/MISSING
  ├─ Step 2e: Structured reporting
  └─ Step 3: Report with documentation checklist
```

---

## 6. CI & Testing Infrastructure

### 6.1 Eval Framework (from PR #36)

#### Skill Trigger Evals

LLM-powered classification tests that validate skill routing accuracy:

```
core/skills/<skill>/evals/trigger-evals.json
[
  {"query": "what should I work on next?", "should_trigger": true},
  {"query": "log 4 hours to the auth task", "should_trigger": false}
]
```

- **Minimum**: 6 test cases (3 positive, 3 negative)
- **Pass threshold**: >= 80% accuracy
- **Runner**: `test/skills/run-trigger-evals.sh`

#### 7 AI Quality Checks

| # | Check | Blocking? | What It Validates |
|---|-------|-----------|-------------------|
| 1 | Skill description quality | No | Clarity, specificity, trigger coverage (>= 6/10) |
| 2 | Skill instruction clarity | No | No ambiguity or contradictions in SKILL.md |
| 3 | Eval quality review | No | Trigger eval test cases cover realistic near-misses |
| 4 | Commit message conventions | No | `[PROJ-123:] type: description` format |
| 5 | PR change summary | No | AI-generated summary (informational only) |
| 6 | Skill consistency | No | Skill instructions align with CLAUDE.md rules |
| 7 | Template variable coverage | Yes | All template variables resolve; Jinja2 loop vars excluded |

#### Template Variable Fix

PR #36 fixes false positives for Jinja2 loop-scoped variables by excluding prefixes:
`agent.`, `member.`, `skill.`, `server.`, `mcp_defaults.`, `hook.`, `command.`, `integration.`, `doc.`, `eval.`, `override.`

Result: 43/43 template variables pass (up from 35/43).

### 6.2 Test Suite Structure (Post-Consolidation)

```
test/
├── run-all.sh              Master runner (8 suites)
├── unit/                   Utility unit tests
├── skills/                 Per-skill tests (12 files)
│   ├── pm.test.sh
│   ├── triage.test.sh
│   ├── plan.test.sh        NEW
│   ├── implement.test.sh
│   ├── pr.test.sh
│   ├── vv.test.sh
│   ├── harness.test.sh
│   ├── email.test.sh
│   ├── timecard.test.sh
│   ├── update.test.sh
│   ├── setup.test.sh
│   ├── evals.test.sh       Eval structure validation
│   ├── run-trigger-evals.sh
│   ├── check-description-quality.sh
│   ├── check-instruction-clarity.sh
│   └── check-eval-quality.sh
├── hooks/                  Hook validation
├── mcp/                    MCP config validation
├── docs/                   Documentation completeness
├── builder/                Builder tests
├── e2e/                    End-to-end scenarios
│   └── pr-review.test.sh   Updated for inline review
├── behavioral/             BDD scenarios
│   ├── triage-workflow.bdd.sh     NEW (replaces sprint-planning)
│   └── implementation-workflow.bdd.sh  NEW (replaces morning-workflow)
├── check-commit-messages.sh
├── check-pr-summary.sh
├── check-template-variables.sh
└── lib/
    └── helpers.sh          Shared test functions
```

### 6.3 Eval Framework Improvements (Recommended)

| Improvement | Priority | Description |
|-------------|----------|-------------|
| Structured output | High | Use JSON responses instead of first-word matching for AI checks |
| Configurable model | High | `EVAL_MODEL` env var instead of hardcoded haiku version |
| Cross-skill routing tests | Medium | Validate skill selection across multiple skills simultaneously |
| Eval score tracking | Medium | Export results to artifact for trend analysis |
| Per-skill thresholds | Low | Allow threshold override in SKILL.md frontmatter |

---

## 7. Builder Pipeline Updates

### 7.1 Changes for v0.3.0

```python
# builder/build.py changes:
- Remove _discover_agents() function
- Set variables["agents"] = [] for template backward compatibility
- Remove agent-related template rendering
- Remove _discover_commands() function
- Update _discover_skills() to handle new /plan skill
- Add documentation deliverable template scaffolding
- Update test copy to exclude deleted agent/command tests
```

### 7.2 Template Variable Cleanup

| Variable | Status | Notes |
|----------|--------|-------|
| `{{ agents }}` | Set to `[]` | Backward compat for templates that loop over agents |
| `{{ commands }}` | Remove | Dashboard command eliminated |
| `{{ skills }}` | Update | Now 12 skills (was 14+) |
| `{{ mcp_servers }}` | Unchanged | Same 13 integrations |


---

## 8. Session & State Management

### 8.1 Session State Schema (Updated)

```json
{
  "version": "1.1",
  "lastActiveProject": "<project-key>",
  "recentWorkItemIds": [],
  "lastTimecardDate": "<ISO-date>",
  "lastTriageBranch": "<branch-name>",
  "lastPlanSynthesis": "<ISO-date>",
  "documentationScope": "minimal|standard|comprehensive"
}
```

Removed: `lastSprintId`, `lastIterationPath` (sprint concepts eliminated)
Added: `lastTriageBranch`, `lastPlanSynthesis`, `documentationScope`

### 8.2 Merge Strategy

Skills read → update own fields → write back. No field-level locking. Skills own disjoint field sets:

| Skill | Owns Fields |
|-------|-------------|
| `/pm` | `lastActiveProject`, `recentWorkItemIds` |
| `/triage` | `lastTriageBranch` |
| `/plan` | `lastPlanSynthesis` |
| `/timecard` | `lastTimecardDate` |
| `/implement` | `documentationScope` |

---

## 9. Implementation Plan

### Phase 1: Foundation (PR #43 merge + cleanup)

| # | Task | Owner | Depends On |
|---|------|-------|------------|
| 1.1 | Merge PR #43 (skill consolidation) to main | Lead | -- |
| 1.2 | Delete `/agile-requirements` skill fully (lingering refs) | Lead | 1.1 |
| 1.3 | Add triage document template (`core/skills/triage/references/triage-template.md`) | Dev | 1.1 |
| 1.4 | Document subagent invocation mechanism in `/pr` references | Dev | 1.1 |
| 1.5 | Add initial `doc/requirements.md` bootstrap logic to `/plan` | Dev | 1.1 |
| 1.6 | Update CLAUDE.md for skills-only architecture | Lead | 1.1 |
| 1.7 | Close GitHub issue #40 | Lead | 1.1 |

### Phase 2: Quality Gates (PR #44 rework)

| # | Task | Owner | Depends On |
|---|------|-------|------------|
| 2.1 | Migrate PR #44 doc deliverables to `/implement` Step 5 | Dev | 1.1 |
| 2.2 | Migrate PR #44 doc audit to `/vv` Step 2d | Dev | 1.1 |
| 2.3 | Migrate PR #44 issue template to `/pm` references | Dev | 1.1 |
| 2.4 | Add proportionality rules (minimal/standard/comprehensive) | Dev | 2.1 |
| 2.5 | Define coverage threshold in customer config schema | Dev | 2.1 |
| 2.6 | Add engineering journal template | Dev | 2.1 |
| 2.7 | Add SDD template (Mermaid-based) | Dev | 2.1 |
| 2.8 | Test documentation gate in `/implement` → `/vv` flow | QA | 2.1-2.7 |

### Phase 2.5: F3 Features (from 2026-03-12 meeting)

| # | Task | Owner | Depends On |
|---|------|-------|------------|
| 2.5.1 | Create `/catchup` skill (morning briefing across email, chat, calendar, Jira) | Dev | 1.1 |
| 2.5.2 | Create `/estimate` skill (historical Jira data mining for three-point estimates) | Dev | 1.1 |
| 2.5.3 | Add breadcrumb time tracking to `/timecard` (git, email, chat, Jira activity mining) | Dev | 1.1 |
| 2.5.4 | Add meeting transcript parsing mode to `/triage` | Dev | 1.3 |
| 2.5.5 | Add Jira approval workflow support (unapproved → approved states) to `/triage` and `/pm` | Dev | 1.1 |
| 2.5.6 | Add custom ticket type support (Purchase Request, Shipping Request) to `/triage` | Dev | 1.1 |
| 2.5.7 | Add milestone suggestion to triage workflow | Dev | 1.3 |
| 2.5.8 | Add `time_tracking.breadcrumb_sources` and `time_tracking.sync_target` to customer config schema | Dev | 2.5.3 |
| 2.5.9 | Add QuickBooks time sync integration (lock past periods, payroll feed) | Dev | 2.5.3, 2.5.8 |
| 2.5.10 | Test `/catchup` with Google + Slack + Jira MCP servers | QA | 2.5.1 |

### Phase 3: CI & Evals (PR #36 rebase + improvements)

| # | Task | Owner | Depends On |
|---|------|-------|------------|
| 3.1 | Rebase PR #36 onto post-Phase-1 main | Dev | 1.1 |
| 3.2 | Remove agent consistency check (agents gone) | Dev | 3.1 |
| 3.3 | Add skill consistency check (replaces agent check) | Dev | 3.2 |
| 3.4 | Update trigger evals for consolidated skills | Dev | 3.1 |
| 3.5 | Switch AI checks to structured JSON output | Dev | 3.1 |
| 3.6 | Make eval model configurable via `EVAL_MODEL` env var | Dev | 3.1 |
| 3.7 | Add cross-skill routing test (pm vs plan vs pr) | QA | 3.4 |
| 3.8 | Merge PR #36 | Lead | 3.1-3.7 |

### Phase 4: Documentation & Lifecycle (Issue #42)

| # | Task | Owner | Depends On |
|---|------|-------|------------|
| 4.1 | Write lifecycle simulation document | Doc | 1.1, 2.8 |
| 4.2 | Include firmware project example (per issue #42 spec) | Doc | 4.1 |
| 4.3 | Demonstrate triage → plan → implement → pr → deliver flow | Doc | 4.1 |
| 4.4 | Show multi-iteration cycles with bugs, scope changes | Doc | 4.1 |
| 4.5 | Show meeting transcript triage workflow | Doc | 4.1 |
| 4.6 | Close GitHub issue #42 | Lead | 4.1-4.5 |

### Phase 5: Housekeeping

| # | Task | Owner | Depends On |
|---|------|-------|------------|
| 5.1 | Remove google integration from blacktie (issue #41) | Dev | -- |
| 5.2 | Rebuild all 4 customer repos | Lead | All phases |
| 5.3 | Push updated customer repos to GitHub | Lead | 5.2 |
| 5.4 | Close PRs #43, #44, #36 | Lead | All phases |
| 5.5 | Tag v0.3.0 release | Lead | 5.4 |

---

## 10. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Documentation burden slows teams | Medium | Medium | Proportionality rules + templates reduce overhead |
| LLM eval flakiness in CI | High | Low | Non-blocking checks; 80% threshold allows variance |
| Triage branch proliferation | Medium | Low | `/plan` cleanup step; branch naming conventions |
| Session state conflicts | Low | Medium | Disjoint field ownership; no concurrent writes expected |
| Template variable regressions | Low | High | PR #36 fix + CI enforcement |

---

## 11. Success Criteria

| Criteria | Measurement |
|----------|-------------|
| All 12 skills pass trigger evals (>= 80%) | CI green |
| Template variables: 43/43 pass | CI green |
| Builder produces valid output for all 4 customers | `python3 builder/build.py --all` succeeds |
| Full triage → plan → implement → pr flow documented | Lifecycle simulation doc exists |
| Documentation deliverables enforced in /implement and /vv | Skill tests verify steps |
| All existing tests pass (minus deleted agent/ceremony tests) | `bash test/run-all.sh` green |

---

## Appendix A: Consolidated Workflow Diagram

See companion Mermaid diagrams in `core/doc/diagrams/`.

## Appendix B: Sources

| Source | Key Contribution |
|--------|-----------------|
| PR #43 | Skills-only architecture, flow-based backlog, triage branches |
| PR #44 | Documentation deliverables, V&V audit, engineering journal |
| PR #36 | Skill trigger evals, 7 AI quality checks, template var fix |
| TRA-85 | GTD methodology, interrupt priority, session lifecycle |
| Issue #40 | Consolidation specification |
| Issue #42 | Lifecycle simulation requirements |
| Codebase | Current architecture baseline |
| F3 Meeting (2026-03-12) | `/catchup` skill, breadcrumb time tracking, AI estimation, Jira approval workflow, meeting transcript triage, regulated industry V&V |
