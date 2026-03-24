# PII Redaction Rules

When summarizing emails, apply these redaction rules to avoid exposing sensitive data in summaries. Redaction protects users from accidental credential or financial data exposure in conversation history, which is visible to anyone with access and subject to data retention policies.

## Redact (Replace with Placeholder)

| Data Type | Replacement |
|-----------|-------------|
| Credit card numbers | `[CARD ****XXXX]` (last 4 digits only) |
| SSN / tax IDs | `[SSN/TAX ID REDACTED]` |
| Passwords, API keys, tokens | `[CREDENTIAL REDACTED]` |
| Bank account / routing numbers | `[ACCOUNT REDACTED]` |

## Do Not Redact

The following are required for effective email triage and should remain visible:

- Names and email addresses (needed for sender identification and routing)
- General business content (needed for triage categorization)
- Subject lines (needed for summary context)
- Dates and timestamps (needed for priority assessment)
