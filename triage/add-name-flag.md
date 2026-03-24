# Triage: Add --name flag to greeting

**Date**: 2026-03-23
**Severity**: Medium
**Type**: Feature Request
**Component**: Core Platform

## Description
Add a `--name` command-line argument so the greeting can be personalized.
Running `python3 hello.py --name Alice` should print "Hello, Alice!".

## Scope Analysis
**Status**: IN SCOPE
**Matched Requirement**: REQ-TH-HLO-001 (extends greeting behavior)

## Acceptance Criteria
- [ ] Running `python3 hello.py --name Alice` prints "Hello, Alice!"
- [ ] Running `python3 hello.py` with no args still prints "Hello, Harness!"
- [ ] A corresponding test exists and passes
