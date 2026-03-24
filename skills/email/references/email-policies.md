# Email Action Policies

## Privacy Warning Banner (REQ-travis-NFR-009)

Before displaying any email content, output the following warning banner exactly once per `/email` invocation:

```
-----------------------------------------------------------
  PRIVACY NOTICE: Email content is now visible in this
  conversation. Loaded messages are subject to Anthropic's
  data retention policies. Do not load emails containing
  credentials, financial account numbers, or sensitive PII.
-----------------------------------------------------------
```

## Privacy Limitations

- **Conversation visibility**: Email content is visible in the conversation once loaded. Anyone with access to the conversation can see it.
- **No automatic redaction**: There is no automatic PII or credential redaction. Sensitive content (passwords, SSNs, financial details) will appear as-is.
- **Attachments**: Avoid loading emails with sensitive attachments. Attachment content may be rendered in the conversation context.
- **Data retention**: Loaded email content is subject to Anthropic's data retention policies for conversation data.
- **Conversation segment isolation**: Claude Code does not support scoped memory segments or isolated conversation partitions — all tool output shares the same context window. This limitation is architectural to Claude Code (as of 2026-03) and cannot be resolved at the plugin level.

## Confirmation Requirements

Write actions carry real consequences (messages sent, emails deleted). Confirmation gates prevent accidental actions that cannot be undone.

| Action | Confirmation Required | Rationale |
|--------|----------------------|-----------|
| Archive emails | Yes — present list, wait for approval | Bulk archiving could hide important messages |
| Send new email | Yes — present draft, wait for "send" confirmation | Outbound messages represent the user |
| Reply to email | Yes — present draft, wait for "send" confirmation | Replies enter active threads |
| Forward email | Yes — present draft and recipient, wait for confirmation | Forwards share content with new parties |
| Delete email | Yes — never delete without explicit confirmation | Deletion is irreversible |
| Read/summarize | No — read-only, but privacy banner must be shown | No side effects beyond context loading |

## Audit Trail

When sending, replying, or forwarding, include a summary line noting the action taken, recipient, and timestamp. This supports the session activity log captured by the Stop hook.
