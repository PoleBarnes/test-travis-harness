# PR Skill — Create Mode

Detailed instructions for preparing and creating a new PR from the current branch.

## Target Branch Detection

1. **Detect target branch** (if not explicitly provided):
   - Try `git config branch.<current>.merge` for upstream tracking
   - Fall back to `git merge-base --fork-point main HEAD`
   - Default to `main` if it exists
   - If none found, ask user to specify

## Review and Creation Pipeline

2. Run the review and creation pipeline:
   - **Pre-flight checks**: uncommitted changes, branch pushed to remote, commits ahead of target
   - **Spawn the review team** in parallel (as defined in Step 6 of the main PR skill):
     - **Code Reviewer** subagent: OWASP security, standards, code quality, test coverage checks
     - **Test Auditor** subagent: verify test coverage for all changed code
     - **V&V Engineer** subagent: requirements traceability (if work item linked)
   - **Aggregate findings**
   - **Fix blocking issues** with user confirmation for each fix
   - **Re-verify** if fixes were applied
   - **Generate PR description** from commits, changes, review findings, and work item ACs
   - **Create the PR** via the **github** MCP server
   - **Link the PR to the work item** (if linked) using the **link_artifact** operation (see `_shared/references/tracker-operations.md`)

## Creation Output Format

3. Display completion:

```
## PR Created

- **PR**: #[number] — [title]
- **Branch**: [source] -> [target]
- **Work Item**: [work item ID] updated (if applicable)

### Review Summary
- Security: [PASS]
- Test Coverage: [ADEQUATE]
- Standards: [COMPLIANT]
- V&V Traceability: [VERIFIED / SKIPPED]

### Changes ([N] files, [M] commits)
- [file1]: [what changed]
- [file2]: [what changed]

### Remaining Suggestions
- [non-blocking suggestions from review team]
```
