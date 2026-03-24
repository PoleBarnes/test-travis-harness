# Requirements — hello-harness

## REQ-TH-HLO-001: Greeting Output
The system shall print "Hello, Harness!" to stdout when invoked with no arguments.
The system shall accept a `--name <name>` argument and print "Hello, <name>!" to stdout.

### Acceptance Criteria
- [ ] Running `python3 hello.py` prints exactly "Hello, Harness!" followed by a newline
- [ ] Running `python3 hello.py --name Alice` prints exactly "Hello, Alice!" followed by a newline
- [ ] Exit code is 0

## REQ-TH-HLO-002: Repeat Count
The system shall accept a `--count N` argument and print the greeting N times, one per line. Default count is 1 when the flag is omitted.

### Acceptance Criteria
- [ ] `python3 hello.py --count 3` prints the greeting 3 times
- [ ] Default count is 1 when flag is omitted
- [ ] A corresponding test exists and passes

## REQ-TH-HLO-003: Version Output
The system shall accept a `--version` flag and print "hello-harness v1.0.0" to stdout.

### Acceptance Criteria
- [ ] `python3 hello.py --version` prints "hello-harness v1.0.0"
- [ ] A corresponding test exists and passes
