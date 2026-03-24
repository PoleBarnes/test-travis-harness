---
name: email
description: Triage email inbox — summarize unread, identify action items, draft replies. Trigger on "check my email", "inbox", "unread messages", "email triage".
argument-hint: [summary | triage | search-query]
---

# Email Triage

Triage and manage the user's email inbox.

> **Privacy and confirmation policies**: See `references/email-policies.md` for the required privacy banner, confirmation gates, and audit trail rules.
>
> **PII redaction rules**: See `references/pii-redaction.md` for redaction patterns to apply when summarizing email content.

Display the privacy warning banner (from `references/email-policies.md`) exactly once before any email content is shown.

## Request

Mode or query: **$ARGUMENTS**

## Instructions

Determine the mode from `$ARGUMENTS`:

- **summary** (or no arguments): Summarize unread emails
- **triage**: Full triage with archive proposals
- **Any other text**: Treat as an email search query (e.g., `from:client@example.com`, `subject:invoice`)

### Mode: Summary

1. Use the **gmail** MCP server to query for unread messages
2. Categorize each email:
   - **Action Required**: Emails that need a response or task from the user
   - **FYI**: Informational emails (newsletters, notifications, CC'd threads)
   - **Internal**: Emails from team members or company domains
   - **External**: Emails from outside the organization
   - **Promotional/Spam**: Marketing emails, automated notifications
3. Apply PII redaction rules from `references/pii-redaction.md` when generating summaries
4. Present a prioritized summary:

```
## Inbox Summary ([count] unread)

### Action Required ([count])
- [sender] — [subject] — [1-line summary of what's needed]

### FYI ([count])
- [sender] — [subject] — [1-line summary]

### Internal ([count])
- [sender] — [subject] — [1-line summary]

### Promotional ([count])
- [count] promotional/notification emails (use /email triage to review)
```

### Mode: Triage

1. Perform the full summary (as above)
2. For each **Promotional/Spam** and low-priority **FYI** email, propose archiving:

```
## Proposed Archive Actions
- [ ] [sender] — [subject] (promotional)
- [ ] [sender] — [subject] (automated notification)
- [ ] [sender] — [subject] (FYI, no action needed)

Confirm to archive these messages, or specify which to keep.
```

3. Wait for user confirmation before archiving — see confirmation requirements in `references/email-policies.md`
4. On confirmation, archive the approved messages via the gmail MCP server

### Mode: Search

1. Use the **gmail** MCP server to search with the user's query
2. Present matching emails in the same categorized format as Summary mode
3. If no results found, suggest alternative search terms

### Drafting Replies

When the user asks to reply to or forward a specific email:

1. Read the full email thread for context
2. Draft a professional reply matching the tone of the conversation
3. Apply PII redaction rules (see `references/pii-redaction.md`) if the draft quotes sensitive content
4. Present the draft for user review and editing
5. Show the recipient(s) and confirm: **"Send this reply to [recipient]? (yes/no)"**
6. Do not send until the user explicitly confirms — sending on behalf of the user without approval could cause real harm

### Privacy and Security

- Treat all email content as confidential — do not log or persist beyond the current conversation
- Apply PII redaction rules from `references/pii-redaction.md` when generating summaries
- Display the privacy warning banner before any email content is shown
- Follow confirmation requirements from `references/email-policies.md` for all write actions
- Include audit trail entries for send, reply, and forward actions (see `references/email-policies.md`)

### Error Handling

If the email MCP server (gmail) is not configured:
- Inform the user that email access requires the gmail MCP server
- Provide setup guidance: the MCP server should be configured in `.mcp.json` with appropriate credentials
- Do not attempt to access email through any other means
