# AI Requirements Writing Guide

A practical reference for writing high-quality agile requirements with AI assistance, grounded in **ISO/IEC/IEEE 29148:2018** quality rules.

---

## 1. The 8-Step Collaboration Loop

Every requirements elicitation session follows this loop. The AI leads; the human decides.

| Step | Actor | Action |
|------|-------|--------|
| **1. Listen** | Human | Describe the capability in plain language. No jargon required. |
| **2. Extract** | AI | Identify actors, actions, objects, constraints, and quality attributes from the description. |
| **3. Draft** | AI | Write a structured requirement using "shall" language per ISO 29148. |
| **4. Interrogate** | AI | Apply type-specific interrogation patterns (see Section 5) to surface gaps. |
| **5. Question** | AI | Present 3-5 clarifying questions the human must answer before the requirement is finalized. |
| **6. Refine** | AI | Incorporate answers, remove ambiguity, and produce the revised requirement. |
| **7. Confirm** | Human | Review and approve the final requirement. |
| **8. Log** | AI | Append the approved requirement to `doc/requirements.md`. |

The loop repeats for each requirement. Steps 4-6 may iterate multiple times until the human is satisfied.

---

## 2. Requirement Output Format

Every requirement must include all of the following fields:

```
### REQ-<COMPANY>-<CAT>-<NNN>: <Title>

**Statement**: The system shall <verb> <object> when <condition> so that <rationale>.

**Rationale**: <Why this requirement exists — business value or risk mitigated.>

**Acceptance Criteria**:
1. Given <precondition>, when <action>, then <measurable outcome>.
2. Given <precondition>, when <action>, then <measurable outcome>.

**Priority**: Must Have | Should Have | Could Have | Won't Have (MoSCoW)

**Source**: <Who requested this — stakeholder, regulation, architecture decision.>

**Category**: <SKL | AGT | MCP | PLG | TST | SEC | PER | DAT | INT>

**Traces To**: <Implementation file(s) — filled after implementation.>

**Tested By**: <Test file(s) — filled after test creation.>
```

### Field Rules

- **Statement**: Must use "shall" for mandatory requirements, "should" for recommended, "may" for optional.
- **Acceptance Criteria**: Must be testable by a machine or human without subjective judgment.
- **Priority**: Use MoSCoW. Every requirement gets exactly one priority level.
- **Source**: Never write "N/A" — every requirement comes from somewhere.

---

## 3. ISO/IEC/IEEE 29148 Quality Rules

Each requirement must pass ALL of the following quality checks:

| Rule | Definition | Test |
|------|-----------|------|
| **Necessary** | Removing it would create a gap in the system. | Can you delete it without impact? If yes, it's not necessary. |
| **Unambiguous** | Has exactly one interpretation. | Can two engineers read it and build different things? If yes, it's ambiguous. |
| **Complete** | Contains all information needed for implementation. | Can an engineer implement it without asking questions? If no, it's incomplete. |
| **Consistent** | Does not contradict other requirements. | Does it conflict with any existing REQ ID? If yes, resolve the conflict. |
| **Singular** | Expresses exactly one requirement. | Does it contain "and" joining two distinct behaviors? If yes, split it. |
| **Feasible** | Can be implemented within known constraints. | Is there a known technical path to implementation? If no, flag it. |
| **Traceable** | Can be linked to source, implementation, and test. | Does it have a unique REQ ID and category? If no, assign one. |
| **Verifiable** | Can be confirmed through test, inspection, or analysis. | Can you write a pass/fail test for it? If no, rewrite it. |

---

## 4. Banned Verbs and Replacements

These verbs are banned because they are vague and produce untestable requirements.

| Banned Verb | Why It's Banned | Concrete Replacements |
|-------------|----------------|----------------------|
| **handle** | Hides the actual behavior — handle how? | detect and respond to, route to, transform into, reject with error |
| **manage** | Covers too many operations — which ones? | create, read, update, delete (pick specific CRUD ops), allocate, schedule, revoke |
| **support** | Unclear scope — support how deeply? | accept as input, render in the UI, expose via REST API, parse from format X |
| **ensure** | Not testable — how do you verify "ensured"? | verify that X equals Y, enforce constraint Z, reject input when condition W |
| **process** | Black box — what actually happens? | parse field X from payload, validate against schema Y, transform to format Z, enqueue for worker W |

### How to Fix a Banned Verb

1. Ask: "What specifically happens when the system [banned verb]s this?"
2. The answer is your replacement verb.
3. If the answer contains multiple actions, split into multiple requirements.

---

## 5. Interrogation Patterns by Requirement Type

When drafting a requirement, apply the matching interrogation pattern to surface hidden assumptions and gaps.

### Functional Requirements

- What event or action triggers this behavior?
- What are the inputs (data, format, source)?
- What are the outputs (data, format, destination)?
- What happens on invalid input?
- What happens on timeout or failure?
- Are there rate limits or throttling?

### Interface Requirements

- What protocol is used (REST, gRPC, WebSocket, file)?
- What is the data format (JSON, XML, CSV, binary)?
- What is the maximum acceptable latency?
- What happens when the external system is unavailable?
- Is authentication required? What kind?
- What is the retry/backoff strategy?

### Data Requirements

- What is the schema (fields, types, constraints)?
- What are the retention and archival rules?
- What are the access patterns (read-heavy, write-heavy, mixed)?
- What are the consistency requirements (eventual, strong)?
- What is the backup and recovery strategy?
- What PII or sensitive data is involved?

### Security Requirements

- What are the threat vectors (STRIDE categories)?
- What authentication mechanism is required?
- What authorization model applies (RBAC, ABAC)?
- What is the blast radius if this is compromised?
- What audit trail is required?
- What compliance standards apply (SOC2, HIPAA, FedRAMP)?

### Performance Requirements

- What is the SLA (response time, throughput, availability)?
- What is the expected load profile (users, requests/sec)?
- What is the peak vs. average load ratio?
- What is the degradation strategy under overload?
- What are the resource budget constraints (CPU, memory, storage)?
- How is performance monitored and alerted?

---

## 6. Gap Checklist

Before finalizing any requirement, verify each item:

- [ ] REQ ID assigned and unique
- [ ] Statement uses "shall" / "should" / "may" correctly
- [ ] No banned verbs in statement or acceptance criteria
- [ ] All 8 ISO 29148 quality rules pass
- [ ] Acceptance criteria are measurable and testable
- [ ] Priority assigned (MoSCoW)
- [ ] Source identified
- [ ] Category assigned
- [ ] No compound requirements (singular rule)
- [ ] No contradictions with existing requirements (consistent rule)
- [ ] Edge cases and error conditions addressed
- [ ] Type-specific interrogation pattern applied

---

## 7. Common Anti-Patterns

| Anti-Pattern | Example | Fix |
|-------------|---------|-----|
| **Compound requirement** | "The system shall validate and store the input." | Split into two: one for validation, one for storage. |
| **Untestable criterion** | "The system shall be user-friendly." | Replace with measurable: "Task completion time shall be under 30 seconds." |
| **Implementation leak** | "The system shall use Redis to cache results." | Rewrite as behavior: "The system shall return cached results within 50ms." |
| **Missing error case** | "The system shall send a notification." | Add: "When delivery fails, the system shall retry 3 times with exponential backoff." |
| **Passive voice** | "The report shall be generated." | Active voice: "The system shall generate the report." |

---

## 8. Quick Reference Card

```
REQ ID format:     REQ-<COMPANY>-<CAT>-<NNN>
Statement verb:    shall (mandatory) | should (recommended) | may (optional)
Banned verbs:      handle, manage, support, ensure, process
Quality gates:     necessary, unambiguous, complete, consistent,
                   singular, feasible, traceable, verifiable
Elicitation loop:  Listen > Extract > Draft > Interrogate >
                   Question > Refine > Confirm > Log
```
