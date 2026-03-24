# PM Skill — Discovery Modes

Detailed instructions for the three skill discovery modes: Skills, Suggest, and Skill Detail.

## Mode: Skills (Skill Discovery)

When `$ARGUMENTS` is "skills" or "list":

1. Read the **Available Skills** section from the main skill (populated by dynamic context injection)
2. Present them as a formatted inventory table:

```
## travis Harness — Skill Inventory

| Skill | Description |
|-------|-------------|
| /pm | Project manager assistant... |
| /pr | Pull request workflow — triage, review, create... |
| ...   | ... |

Total: [count] skills available
Tip: Use `/pm suggest` for context-aware recommendations or `/pm <skill-name>` for details.
```

## Mode: Suggest (Context-Aware Recommendations)

When `$ARGUMENTS` is "suggest":

1. Read the **Current Context** section (branch, recent commits, time of day, day of week, triage branches)
2. Check git and project board state to determine what the user is likely working on
3. Apply **context-aware recommendations**:
   - **Morning (before 10am)**: Suggest `/email`, `/pm`
   - **End of day (after 4pm)**: Suggest `/timecard`
   - **On a feature branch with recent commits**: Suggest `/pr`
   - **Open PRs awaiting review**: Suggest `/pr` (triage mode shows assigned PRs)
   - **Monday morning**: Suggest `/pm`, `/plan`
   - **No recent commits**: Suggest `/pm` to find next task
   - **Triage branches exist**: Suggest `/plan` to convert triage into implementation plans
   - **WIP items with no recent activity**: Suggest `/implement` to resume work
   - **High-priority backlog item ready**: Suggest `/implement` for the top-priority item

4. Present 2-4 contextually relevant skill suggestions with brief rationale:

```
## Suggested Skills

Based on your context ([time of day], [branch state]):

1. **/pr** — You have recent commits on a feature branch that may be ready for PR
2. **/timecard** — It's late afternoon — capture today's work before EOD

Tip: Use `/pm skills` to see all available skills.
```

## Mode: Skill Detail

When `$ARGUMENTS` matches a known skill name (e.g., "plan", "harness", "pr"):

1. Find the matching skill from the **Available Skills** list
2. Read the full SKILL.md for that skill from `skills/<name>/SKILL.md`
3. Present a detailed summary:

```
## Skill: /[name]

**Description**: [full description]
**Arguments**: [argument-hint value]
**Modes**: [list the modes/arguments the skill accepts]

### What It Does
[2-3 sentence summary of the skill's purpose and workflow]

### Usage Examples
- `/[name]` — [default behavior]
- `/[name] [arg]` — [specific behavior]

### Related Skills
- [other skills that complement this one]
```

**If the skill name is not found**:
- Report that no skill named `[name]` exists
- Show the full skill list as a fallback
- Suggest close matches if the name is similar to an existing skill
