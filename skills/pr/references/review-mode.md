# PR Skill — Review Mode

Detailed instructions for reviewing an existing PR by number or URL.

## Fetching PR Data


1. Use the **github** MCP server to fetch:
   - PR metadata: title, description, author, head branch, base branch, status
   - PR diff: full diff of all changes
   - PR comments: existing review comments
   - Linked issue (from PR title/description pattern `TH-\d+` or `#\d+`)


## Review Team

2. Spawn the **review team** in parallel (as defined in Step 6 of the main PR skill):
   - **Code Reviewer** subagent: OWASP security, standards, code quality, test coverage checks
   - **Test Auditor** subagent: verify test coverage for all changed code
   - **V&V Engineer** subagent: requirements traceability (if work item linked)

3. **Aggregate findings** into a unified report
4. **Present blocking issues** with proposed fixes and ask for user confirmation
5. If fixes are confirmed, spawn a subagent to apply them (on a local checkout of the PR branch)
6. **Report the review** with verdict: APPROVE / REQUEST CHANGES

## Review Output Format

7. Display the review in the standard format:

```
## Review: PR #42 — Add login validation

**Author**: @teammate | **Branch**: feature/TH-42 -> main
**Verdict**: APPROVE / REQUEST CHANGES

### Security: [PASS / ISSUES FOUND]
### Test Coverage: [ADEQUATE / GAPS FOUND]
### Standards: [COMPLIANT / ISSUES FOUND]
### V&V Traceability: [VERIFIED / SKIPPED]

### Blocking Issues (N)
1. [Issue with file reference and proposed fix]

### Suggestions (N)
1. [Suggestion with rationale]

### Positive Notes
- [What was done well]
```
