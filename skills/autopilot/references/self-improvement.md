# Self-Improvement Engine Reference

## Overview

The self-improvement engine analyzes autopilot session behavior and proposes optimizations. It runs at configurable granularity from session-level retrospectives to per-step training analysis.

## Levels

| Level | Trigger | Overhead | Description |
|-------|---------|----------|-------------|
| `off` | Never | None | No analysis (default) |
| `end-of-session` | On stop/pause | Low | One analysis pass against full session log |
| `per-cycle` | After each EVALUATE | Medium | Lightweight analysis each cycle; can adjust approach |
| `training` | After every skill invocation | High | Maximum insight; analyzes each step within EXECUTE |

## Configuration

```yaml
autopilot:
  self_improvement:
    level: off                    # off | end-of-session | per-cycle | training
    auto_apply: false             # Apply improvements automatically (vs propose-only)
    capabilities:
      session_analysis: true      # Review logs for patterns/inefficiencies
      skill_research: false       # Search for better approaches
      improve_skills: false       # Propose skill prompt changes
      install_dependencies: false # Install missing npm/pip packages
      install_mcp_servers: false  # Discover/install MCP servers
      prompt_refinement: true     # Adjust skill invocation patterns
```

CLI: `--self-improve off|end-of-session|per-cycle|training`

## Capabilities

### 1. session_analysis (default: on)

Reads the run log and session state. Identifies:
- Repeated failures on the same item type
- Skills that consistently take longer than expected
- Enforcement rejections that could be avoided with better sequencing
- Priority decisions that led to dead ends

Output: `observations[]` array of pattern descriptions. No side effects.

### 2. skill_research (default: off)

When encountering an unfamiliar domain (new framework, unfamiliar test pattern):
- Search documentation via available MCP tools
- Check for relevant examples in the codebase
- Record findings in `observations[]`

### 3. improve_skills (default: off)

Analyzes skill prompt templates for:
- Missing edge case handling
- Unclear instructions that caused failures
- Redundant or contradictory steps

Generates entries in `improvementsProposed[]`:

```json
{
  "skill": "/implement",
  "file": "core/skills/implement/SKILL.md",
  "section": "Step 3: Subagent Delegation",
  "issue": "No guidance for handling test framework detection",
  "proposal": "Add test framework detection step before spawning test subagent",
  "confidence": "medium"
}
```

Default: propose-only. If `auto_apply: true`, applies changes. ALWAYS requires user confirmation for skill file modifications (DP-1: manual control first).

### 4. install_dependencies (default: off)

When implementation fails due to missing packages:
- Detect the missing dependency from error output
- Propose `npm install` or `pip install` command
- If `auto_apply: true`: execute with user confirmation
- Record in `improvementsApplied[]` or `improvementsProposed[]`

### 5. install_mcp_servers (default: off)

When a capability gap is detected:
- Identify which MCP server would help
- Propose installation/configuration
- ALWAYS requires user confirmation (never auto-apply)
- Record in `improvementsProposed[]`

### 6. prompt_refinement (default: on)

Adjusts how autopilot invokes skills within the current session:
- Adding context flags based on what worked
- Changing argument patterns based on failures
- Silently applied within the session (no persistence across sessions)
- Record in `improvementsApplied[]`

## Analysis Engine Algorithm

```
function analyze(session, level, trigger_point):
    # Skip conditions
    if level == "off": return
    if trigger_point == "post-skill" and level != "training": return
    if trigger_point == "post-cycle" and level == "end-of-session": return

    observations = []
    proposed = []
    applied = []

    for capability in enabled_capabilities:
        result = run_capability(session, capability, trigger_point)
        observations.extend(result.observations)
        proposed.extend(result.proposed)

        if auto_apply and result.applicable:
            for improvement in result.applicable:
                if improvement.requires_confirmation:
                    # Present to user, wait for [y/n]
                    if user_confirms:
                        apply(improvement)
                        applied.append(improvement)
                else:
                    apply(improvement)
                    applied.append(improvement)

    # Update session state
    session.selfImprovement.observations.extend(observations)
    session.selfImprovement.improvementsProposed.extend(proposed)
    session.selfImprovement.improvementsApplied.extend(applied)
```

## Timing Constraints

| Level | Max Analysis Time | Notes |
|-------|------------------|-------|
| end-of-session | 5 minutes | Full session review, comprehensive |
| per-cycle | 2 minutes | Quick pattern check, lightweight |
| training | 1 minute per step | Must not dominate execution time |

Analysis time counts against session budget but NOT against cycle timeout.

## Safety Constraints

1. `improve_skills` in propose-only mode: NEVER modifies skill files without confirmation
2. `install_dependencies`: ALWAYS confirms with user (even with auto_apply)
3. `install_mcp_servers`: ALWAYS confirms with user
4. `prompt_refinement`: Applied silently (session-scoped, no persistence)
5. No self-improvement action can bypass enforcement gates
6. Only `prompt_refinement` improvements may set `requires_confirmation: false`. All other improvement types (`skill_change`, `dependency`, `mcp_server`) MUST have `requires_confirmation: true` regardless of `auto_apply` setting.
7. If analysis time exceeds the limit: truncate and report partial results

## Output Format

Shown to user at session end (end-of-session level) or inline (per-cycle/training):

```
## Self-Improvement Observations

- [observation 1 -- what was noticed]
- [observation 2 -- what pattern was detected]

### Proposed Improvements
1. [proposal description] -- Apply? [y/n]
2. [proposal description] -- Apply? [y/n]

### Applied This Session
- [improvement description -- what was changed and why]
```

## Integration with the Autopilot Loop

The self-improvement engine hooks into the EVALUATE phase of the SCAN-DECIDE-EXECUTE-EVALUATE cycle (see `autopilot-loop.md`).

### Invocation Points

| Level | When | What Runs |
|-------|------|-----------|
| `off` | Never | Nothing |
| `end-of-session` | After final EVALUATE (on STOP or PAUSE) | Full analysis of the complete run log |
| `per-cycle` | After each EVALUATE, before the next SCAN | Lightweight check of the most recent cycle against cumulative patterns |
| `training` | After each skill invocation within EXECUTE, before EVALUATE completes | Per-step analysis of the skill's inputs, outputs, and duration |

### Per-Cycle Flow

When `level` is `per-cycle` or `training`, the engine runs between EVALUATE and the next SCAN:

```
SCAN -> DECIDE -> EXECUTE -> EVALUATE -> [self-improvement analysis] -> SCAN
```

The analysis may update `prompt_refinement` adjustments that affect the next EXECUTE phase. It does NOT alter the DECIDE priority table or skip list.

### End-of-Session Flow

When `level` is `end-of-session`, the engine runs once after the loop terminates:

```
[loop terminates] -> [self-improvement analysis] -> [session summary with observations]
```

Observations and proposals are included in the session summary shown to the user and appended to the run log.

## Session State Fields

| Field | Type | Description |
|-------|------|-------------|
| `autopilot.selfImprovement.level` | string | Active level for this session |
| `autopilot.selfImprovement.observations` | array of strings | Collected observations |
| `autopilot.selfImprovement.improvementsApplied` | array of objects | Changes applied this session |
| `autopilot.selfImprovement.improvementsProposed` | array of objects | Proposals awaiting user review |

### Improvement Object Schema

```json
{
  "id": "si-001",
  "type": "skill_change | dependency | mcp_server | prompt_refinement",
  "description": "Human-readable description of the improvement",
  "target": "core/skills/implement/SKILL.md",
  "confidence": "low | medium | high",
  "requires_confirmation": true,
  "applied": false,
  "applied_at": null
}
```
