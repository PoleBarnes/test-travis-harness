# Triage: Add --count flag to repeat greeting

**Date**: 2026-03-23
**Severity**: Low
**Type**: Feature Request
**Component**: Core Platform

## Description
Add a `--count N` argument that repeats the greeting N times.

## Scope Analysis
**Status**: OUT OF SCOPE
**Matched Requirement**: None

## Requirement Change Proposal
**Proposed Requirement ID**: REQ-TH-HLO-002
The system shall accept a `--count N` argument and print the greeting N times, one per line.

## Acceptance Criteria
- [ ] `python3 hello.py --count 3` prints the greeting 3 times
- [ ] Default count is 1 when flag is omitted
- [ ] A corresponding test exists and passes
