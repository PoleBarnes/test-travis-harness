# Harness Plugin -- Lifecycle Simulation

> **Purpose**: Walk through a realistic firmware project from first requirement to shipped release, demonstrating how every harness skill fits into a developer's daily workflow.
>
> **How to read this document**: Each section simulates a real interaction. Commands appear as `/>` prompts. Simulated output is shown in fenced blocks. Commentary explains what the plugin does behind the scenes.

---

## Project: SensorHub Pro Firmware

**Product**: Industrial IoT sensor hub -- aggregates temperature, pressure, and vibration data from multiple sensors over SPI/I2C, logs to onboard flash, and transmits via LoRa radio.

**Team**:

| Name | Role | Responsibilities |
|------|------|-----------------|
| Maria Chen | Tech Lead | Architecture, power management, code review |
| Jake Torres | Firmware Engineer | Drivers (SPI, I2C, UART), sensor calibration |
| Priya Kapoor | Firmware Engineer | OTA updates, flash storage, LoRa radio stack |
| David Park | Project Manager | Requirements, scheduling, stakeholder comms |

**DevOps**: Jira (project key `SHP`), GitHub repos, Slack, Google Calendar

**Harness Plugin**: Installed as `/shp:*` (prefix: `shp`)

---

## Day 1: Project Kickoff

David shares initial requirements from the product brief in a team meeting. Maria opens her terminal after the meeting.

### 1.1 Morning Briefing

```
/> /shp:catch-me-up
```

```
Good morning, Maria.

EMAIL (3 unread)
  ● Product brief from David Park — "SensorHub Pro Requirements v1"
  ● HR — Benefits enrollment reminder
  ● Jira digest — 0 items assigned

CALENDAR (today)
  09:00  SHP Kickoff (completed)
  14:00  Architecture Review — SHP

CHAT (Slack, 12 unread)
  #shp-firmware — David posted product brief PDF
  #general — IT maintenance window Saturday 02:00-06:00

WORK ITEMS (Jira SHP)
  No items assigned yet. Board is empty.

Suggested next actions:
  1. /shp:triage — Process the product brief into structured requirements
  2. /shp:email — Review product brief email in detail
```

### 1.2 Triage the Product Brief

Maria feeds the product brief into triage. She pastes the key requirements section directly.

```
/> /shp:triage

The SensorHub Pro must:
- Read temperature, pressure, and vibration sensors at configurable intervals (1Hz to 100Hz)
- Support SPI and I2C sensor buses
- Log all readings to onboard NOR flash with wear leveling
- Transmit aggregated data packets via LoRa at configurable intervals
- Support over-the-air firmware updates via LoRa downlink
- Enter low-power sleep between sensor readings to achieve 2-year battery life on 2x AA
- Provide a UART debug console for factory diagnostics
- Watchdog timer with 5-second timeout, automatic recovery logging
```

The plugin analyzes each requirement:

```
Analyzing 8 requirements from product brief...

Scope check: No existing doc/requirements.md found. These are founding requirements.

Quality analysis (ISO/IEC/IEEE 29148):

  1. "Read temperature, pressure, and vibration sensors at configurable
      intervals (1Hz to 100Hz)"
     ✓ Necessary  ✓ Unambiguous  ✓ Singular  ✓ Verifiable
     ⚠ Feasibility: 100Hz vibration sampling on battery power may
       conflict with 2-year battery life requirement. Flagging for
       architecture review.

  2. "Support SPI and I2C sensor buses"
     ✓ All 8 criteria pass

  3. "Log all readings to onboard NOR flash with wear leveling"
     ✓ All 8 criteria pass

  4. "Transmit aggregated data packets via LoRa at configurable intervals"
     ⚠ Unambiguous: "aggregated" is undefined — mean? min/max? raw buffer?
       Recommend: specify aggregation method.

  5. "Support over-the-air firmware updates via LoRa downlink"
     ✓ All 8 criteria pass
     ⚠ Note: OTA via LoRa has bandwidth constraints (~50kbps).
       Image size and chunking strategy needed.

  6. "Enter low-power sleep between sensor readings to achieve 2-year
      battery life on 2x AA"
     ✓ Verifiable (2-year, 2xAA is measurable)
     ⚠ Feasibility: Cross-reference with req #1 (100Hz sampling).

  7. "Provide a UART debug console for factory diagnostics"
     ✓ All 8 criteria pass

  8. "Watchdog timer with 5-second timeout, automatic recovery logging"
     ✓ All 8 criteria pass

Duplicate check: Jira SHP board is empty. No duplicates.

Creating triage branch: triage/product-brief-initial-requirements
Committing triage document...

✓ Triage complete. 8 requirements captured on branch
  triage/product-brief-initial-requirements

  2 warnings flagged for architecture review:
    - 100Hz vs battery life tension
    - "aggregated" needs specification

  Next: /shp:plan to synthesize into formal requirements and work items
```

**What happened behind the scenes**: The plugin created a structured markdown document on a `triage/product-brief-initial-requirements` branch containing each requirement, its quality analysis, cross-reference warnings, and recommended refinements. No Jira tickets were created yet — that is `/plan`'s job.

### 1.3 Plan: Synthesize Requirements and Create Work Items

Maria runs `/plan` to turn the triage findings into formal requirements and Jira tickets.

```
/> /shp:plan
```

```
Discovering triage branches...

Found 1 triage branch:
  ● triage/product-brief-initial-requirements (8 items, 2 warnings)

Synthesizing requirements...

Proposed requirements for doc/requirements.md:

  REQ-SHP-SENSOR-001: The system shall read temperature, pressure, and
    vibration sensors at configurable intervals from 1 Hz to 100 Hz.
    Acceptance: Unit test demonstrates each sensor type at 1Hz, 10Hz, 100Hz.

  REQ-SHP-SENSOR-002: The system shall support sensors connected via
    SPI and I2C buses.
    Acceptance: Integration test with at least one SPI and one I2C sensor.

  REQ-SHP-STORAGE-001: The system shall log all sensor readings to
    onboard NOR flash using wear-leveling.
    Acceptance: Write 1M records; verify no single block exceeds 2x
    average erase count.

  REQ-SHP-RADIO-001: The system shall transmit sensor data via LoRa
    at configurable intervals.
    Acceptance: Receive valid packet on gateway at configured interval ±5%.
    NOTE: "aggregated" left unspecified pending stakeholder clarification.

  REQ-SHP-OTA-001: The system shall support firmware updates delivered
    over-the-air via LoRa downlink.
    Acceptance: Flash a 128KB test image via OTA; verify CRC and boot.

  REQ-SHP-POWER-001: The system shall achieve ≥2-year battery life on
    2x AA cells under nominal operating conditions.
    Acceptance: Current measurement at each power state; power budget
    model shows ≥2 years.
    NOTE: Nominal conditions must be defined (sampling rate, TX interval).

  REQ-SHP-DIAG-001: The system shall provide a UART debug console for
    factory diagnostics.
    Acceptance: Connect at 115200 baud; execute "status" command; receive
    valid JSON response.

  REQ-SHP-WDT-001: The system shall implement a watchdog timer with
    5-second timeout and log recovery events to flash.
    Acceptance: Force a hang; verify watchdog reset occurs within 6s;
    verify recovery log entry written.

Proposed Jira work items:

  ┌──────────┬────────────────────────────────────┬──────────┬──────────┐
  │ Key      │ Summary                            │ Type     │ Assignee │
  ├──────────┼────────────────────────────────────┼──────────┼──────────┤
  │ SHP-1    │ Implement SPI/I2C sensor driver     │ Story    │ Jake     │
  │          │ framework                           │          │          │
  │ SHP-2    │ Add temperature sensor support      │ Story    │ Jake     │
  │ SHP-3    │ Add pressure sensor support         │ Story    │ Jake     │
  │ SHP-4    │ Add vibration sensor support        │ Story    │ Jake     │
  │ SHP-5    │ Implement NOR flash storage with    │ Story    │ Priya    │
  │          │ wear leveling                       │          │          │
  │ SHP-6    │ Implement LoRa radio TX/RX stack    │ Story    │ Priya    │
  │ SHP-7    │ Implement OTA firmware update       │ Story    │ Priya    │
  │          │ mechanism                           │          │          │
  │ SHP-8    │ Implement low-power sleep and       │ Story    │ Maria    │
  │          │ power state machine                 │          │          │
  │ SHP-9    │ Implement UART debug console        │ Story    │ Jake     │
  │ SHP-10   │ Implement watchdog timer with       │ Story    │ Maria    │
  │          │ recovery logging                    │          │          │
  │ SHP-11   │ Clarify "aggregated" data           │ Task     │ David    │
  │          │ definition with stakeholders        │          │          │
  │ SHP-12   │ Define nominal operating conditions │ Task     │ David    │
  │          │ for power budget                    │          │          │
  └──────────┴────────────────────────────────────┴──────────┴──────────┘

  12 work items proposed. Dependencies:
    SHP-2,3,4 blocked by SHP-1 (driver framework first)
    SHP-7 blocked by SHP-6 (radio stack first)
    SHP-8 depends on SHP-12 (need nominal conditions defined)

Approve? [y/n/edit]
```

Maria reviews, adjusts assignees, and approves:

```
/> y

✓ doc/requirements.md created with 8 requirements
✓ 12 Jira tickets created in SHP project
✓ Dependencies linked in Jira
✓ Triage branch triage/product-brief-initial-requirements merged to main

Next: /shp:pm for prioritized action list
```

### 1.4 Check Project Status

```
/> /shp:pm
```

```
PROJECT: SensorHub Pro (SHP)

BLOCKERS (0)
  None

IN PROGRESS (0)
  None — fresh board

READY TO START (prioritized)
  1. SHP-1   Implement SPI/I2C sensor driver framework     [Jake]
  2. SHP-5   Implement NOR flash storage with wear leveling [Priya]
  3. SHP-8   Implement low-power sleep / power state machine [Maria]
  4. SHP-9   Implement UART debug console                   [Jake]
  5. SHP-10  Implement watchdog timer with recovery logging  [Maria]

BLOCKED (waiting on dependencies)
  SHP-2,3,4 — waiting on SHP-1
  SHP-7     — waiting on SHP-6

NEEDS CLARIFICATION
  SHP-11  Clarify "aggregated" data definition      [David]
  SHP-12  Define nominal operating conditions        [David]

DOCUMENTATION
  Tier: standard (feature work, estimated 500-1500 LOC total)
  Required: SDD, coverage report, V&V audit

Suggested actions:
  1. /shp:implement SHP-1 — Unblocks 3 downstream tickets
  2. /shp:implement SHP-5 — Independent, can parallelize
  3. Ping David on SHP-11, SHP-12 — Blocks radio and power work
```

---

## Day 2-5: First Implementation Cycle

Jake picks up the sensor driver framework (SHP-1), which unblocks three downstream tickets.

### 2.1 Implement the Sensor Driver Framework

```
/> /shp:implement SHP-1
```

```
Fetching SHP-1 from Jira...

  Summary: Implement SPI/I2C sensor driver framework
  Acceptance Criteria:
    AC1: Common sensor_driver_t interface with init/read/sleep methods
    AC2: SPI transport layer with configurable clock/mode
    AC3: I2C transport layer with configurable address
    AC4: Unit tests for both transports using mock hardware registers

Linked requirement: REQ-SHP-SENSOR-002

Step 1/6: Parse and validate ✓
Step 2/6: Research codebase...
  Exploring project structure...
  Found: src/drivers/ (empty), src/hal/ (HAL stubs), test/ (unity framework)
  Pattern: Project uses Unity test framework, HAL abstraction layer

Step 3/6: Decompose
  Subtask 1: Define sensor_driver_t interface in src/drivers/sensor_driver.h
  Subtask 2: Implement SPI transport in src/drivers/transport_spi.c
  Subtask 3: Implement I2C transport in src/drivers/transport_i2c.c
  Subtask 4: Write unit tests in test/test_transport_spi.c, test/test_transport_i2c.c

Step 4/6: Implement...
  Creating feature branch: feature/SHP-1-sensor-driver-framework
  Writing src/drivers/sensor_driver.h...
  Writing src/drivers/transport_spi.c...
  Writing src/drivers/transport_i2c.c...
  Writing test/test_transport_spi.c...
  Writing test/test_transport_i2c.c...

Step 5/6: Verify
  Running tests... 14/14 passed ✓
  AC1: sensor_driver_t interface defined with init/read/sleep ✓
  AC2: SPI transport configurable clock (1-20MHz), modes 0-3 ✓
  AC3: I2C transport configurable 7-bit address ✓
  AC4: Unit tests cover both transports ✓

Step 6/6: Documentation (standard tier)
  ✓ SDD: doc/sdd/SHP-1-sensor-driver-framework.md
  ✓ Coverage: 94% line coverage (threshold: 80%)
  ✓ Unit test results: 14/14 pass

All acceptance criteria met. Creating PR...
```

The plugin automatically delegates to `/pr`:

```
PR created: #14 "SHP-1: feat: Implement SPI/I2C sensor driver framework"

Review team (parallel):
  Code Reviewer:  No blocking issues. Clean HAL abstraction.
  Test Auditor:   14 tests, 94% coverage. ✓
  V&V Engineer:   REQ-SHP-SENSOR-002 traced → impl → tests. ✓

PR #14 ready for human review.
  https://github.com/acme-iot/sensorhub-pro/pull/14
```

### 2.2 Log Time

At end of day, Jake logs his time:

```
/> /shp:timecard today
```

```
Gathering activity for today (2026-03-15)...

Git commits:
  feature/SHP-1-sensor-driver-framework
    09:32  SHP-1: feat: Define sensor_driver_t interface
    10:45  SHP-1: feat: Implement SPI transport layer
    13:15  SHP-1: feat: Implement I2C transport layer
    14:30  SHP-1: test: Add transport unit tests
    15:45  SHP-1: docs: Add SDD for sensor driver framework

Jira transitions:
    09:15  SHP-1 To Do → In Progress
    16:00  SHP-1 In Progress → In Review

Proposed time entries:

  ┌──────────┬─────────────────────────────────┬───────┐
  │ Work Item│ Description                     │ Hours │
  ├──────────┼─────────────────────────────────┼───────┤
  │ SHP-1    │ Sensor driver framework —       │  6.5  │
  │          │ interface, SPI/I2C transport,    │       │
  │          │ tests, documentation             │       │
  └──────────┴─────────────────────────────────┴───────┘
  Total: 6.5 hours

Submit to Harvest? [y/n/edit]

/> y
✓ Time entry created in Harvest
```

---

## Day 6: A Bug Appears

Priya is working on flash storage (SHP-5). During integration testing, she discovers the SPI driver drops bytes when the sensor FIFO drains mid-transfer.

### 3.1 Triage the Bug

```
/> /shp:triage

Bug: SPI transport drops bytes when sensor FIFO empties during a
multi-byte read. Observed on BMI270 vibration sensor at 100Hz. The
driver reads 12 bytes (6 axes × 2 bytes) but intermittently receives
only 10 bytes. Logic analyzer shows the sensor pulls MISO low after
byte 10 when its FIFO underflows. Driver does not detect the underflow
condition and returns truncated data without error.

Reproduction: Configure BMI270 at 100Hz ODR, read FIFO at 95Hz.
Approximately 1 in 200 reads returns short data.
```

```
Analyzing issue...

Type: BUG
Severity: HIGH — data integrity issue, silent data corruption
Component: drivers/transport_spi
Linked requirement: REQ-SHP-SENSOR-001 (sensor reading accuracy)

Scope check against doc/requirements.md:
  REQ-SHP-SENSOR-002 requires SPI support — this is a defect in that
  implementation. IN SCOPE.

Root cause hypothesis:
  transport_spi.c read function does not validate byte count returned
  by HAL SPI transfer. FIFO underflow is a known condition for
  streaming sensors.

Duplicate check: No existing bugs in SHP project.

Creating triage branch: triage/spi-fifo-underflow-bug
Committing triage document...

✓ Triage complete. Bug captured on triage/spi-fifo-underflow-bug

  Severity: HIGH — recommend prioritizing above new feature work
  Next: /shp:plan to create a bug fix ticket
```

### 3.2 Plan the Fix

```
/> /shp:plan
```

```
Discovering triage branches...

Found 1 triage branch:
  ● triage/spi-fifo-underflow-bug (1 item, severity HIGH)

Synthesizing...

No requirement changes needed — this is a defect against REQ-SHP-SENSOR-002.

Proposed Jira work item:

  ┌──────────┬────────────────────────────────────┬──────────┬──────────┐
  │ Key      │ Summary                            │ Type     │ Assignee │
  ├──────────┼────────────────────────────────────┼──────────┼──────────┤
  │ SHP-13   │ Fix SPI FIFO underflow — validate  │ Bug      │ Jake     │
  │          │ byte count on multi-byte reads      │          │          │
  └──────────┴────────────────────────────────────┴──────────┴──────────┘

  Priority: High (data integrity)
  Linked to: SHP-1 (driver framework)
  Acceptance criteria:
    AC1: SPI read returns error code when byte count < requested
    AC2: Caller can distinguish underflow from other errors
    AC3: Unit test simulates FIFO underflow and verifies error path
    AC4: Integration test with BMI270 at 100Hz shows 0 silent truncations
         over 10,000 reads

Approve? [y/n/edit]

/> y

✓ SHP-13 created in Jira (priority: High)
✓ Triage branch merged
```

### 3.3 Implement the Fix

```
/> /shp:implement SHP-13
```

```
Fetching SHP-13 from Jira...

Step 1/6: Parse ✓
Step 2/6: Research...
  Found: src/drivers/transport_spi.c:87 — spi_read() does not check
  hal_spi_transfer() return value for short reads.

Step 3/6: Decompose
  Subtask 1: Add byte count validation to spi_read()
  Subtask 2: Define SPI_ERR_UNDERFLOW error code
  Subtask 3: Add unit test for underflow path
  Subtask 4: Update SDD

Step 4/6: Implement...
  Branch: fix/SHP-13-spi-fifo-underflow
  Modified: src/drivers/transport_spi.c (added validation)
  Modified: src/drivers/sensor_driver.h (added error code)
  Added: test/test_spi_underflow.c

Step 5/6: Verify
  Tests: 18/18 passed ✓ (4 new underflow tests)
  AC1: ✓  AC2: ✓  AC3: ✓  AC4: Requires hardware — flagged for manual test

Step 6/6: Documentation (minimal tier — bug fix, <50 lines changed)
  ✓ Unit test results: 18/18
  ✓ Regression: all existing transport tests pass

PR created: #16 "SHP-13: fix: Validate SPI byte count to catch FIFO underflow"
  1 file changed, 23 insertions(+), 2 deletions(-)
  https://github.com/acme-iot/sensorhub-pro/pull/16
```

**Key point**: The documentation tier was automatically set to **minimal** because this is a bug fix with fewer than 50 lines changed. No SDD or V&V audit required — just test results and regression confirmation.

### 3.4 V&V Audit After the Fix

Maria runs a targeted V&V audit to verify traceability is intact:

```
/> /shp:vv REQ-SHP-SENSOR-002
```

```
Traceability audit for REQ-SHP-SENSOR-002:
  "The system shall support sensors connected via SPI and I2C buses."

  Implementation:
    ✓ src/drivers/transport_spi.c — SPI transport
    ✓ src/drivers/transport_i2c.c — I2C transport
    ✓ src/drivers/sensor_driver.h — Common interface

  Tests:
    ✓ test/test_transport_spi.c — 10 tests (incl. underflow)
    ✓ test/test_transport_i2c.c — 8 tests
    ✓ test/test_spi_underflow.c — 4 tests

  Coverage: 94% → 97% (underflow paths now covered)

  Documentation:
    ✓ SDD: doc/sdd/SHP-1-sensor-driver-framework.md
    ✓ Bug fix: SHP-13 linked to SHP-1

  Result: PASS — full traceability from requirement to implementation to tests
```

---

## Day 10: Scope Change from Stakeholders

David attends a stakeholder meeting. The customer now wants BLE support in addition to LoRa. He drops the news in Slack. Maria triages it.

### 4.1 Triage the Scope Change

```
/> /shp:triage

Scope change from stakeholder meeting: Customer wants BLE 5.0 support
for local configuration and real-time data streaming to a mobile app.
This is in addition to LoRa (not a replacement). They want:
- BLE GATT server for sensor data characteristics
- Mobile app can configure sampling rates and TX intervals via BLE
- BLE and LoRa can operate simultaneously
- BLE range: minimum 30 meters in open environment
```

```
Analyzing issue...

Type: SCOPE CHANGE
Severity: MEDIUM — new feature, does not break existing work
Component: radio (new: BLE)

Scope check against doc/requirements.md:
  ⚠ OUT OF SCOPE — No existing BLE requirements.
  This is a scope expansion. Flagging for PM approval.

Impact analysis:
  - New hardware: BLE radio (e.g., nRF52840 has both LoRa + BLE)
  - Power budget impact: BLE advertising + connection events increase
    average current. REQ-SHP-POWER-001 (2-year battery) at risk.
  - Concurrent radio: SPI bus contention if LoRa and BLE share bus.
  - Schedule: Estimated 3-4 additional work items.

Quality analysis:
  1. "BLE GATT server for sensor data characteristics" ✓ Verifiable
  2. "Mobile app can configure sampling rates via BLE"  ✓ Verifiable
  3. "BLE and LoRa can operate simultaneously"
     ⚠ Unambiguous: Define "simultaneously" — time-sliced or true
       concurrent? Hardware dependent.
  4. "BLE range: minimum 30 meters in open environment" ✓ Verifiable

Creating triage branch: triage/scope-change-ble-support
Committing triage document...

✓ Scope change captured on triage/scope-change-ble-support

  ⚠ OUT OF SCOPE — Requires PM approval before planning
  ⚠ Power budget risk — REQ-SHP-POWER-001 may need revision
  Next: Get David's approval, then /shp:plan
```

### 4.2 Plan After Approval

David approves the scope change. Maria runs plan:

```
/> /shp:plan
```

```
Discovering triage branches...

Found 1 triage branch:
  ● triage/scope-change-ble-support (4 items, scope change, PM approved)

Synthesizing...

Proposed requirement changes to doc/requirements.md:

  NEW: REQ-SHP-RADIO-002: The system shall implement a BLE 5.0 GATT
    server exposing sensor data as readable characteristics.
    Acceptance: nRF Connect app reads live sensor values over BLE.

  NEW: REQ-SHP-RADIO-003: The system shall allow configuration of
    sampling rate and LoRa TX interval via BLE write characteristics.
    Acceptance: Write new rate via BLE; verify sensor reads at new rate
    within 2 seconds.

  NEW: REQ-SHP-RADIO-004: The system shall support concurrent BLE and
    LoRa operation using time-division multiplexing.
    Acceptance: BLE connected + LoRa TX active simultaneously for
    60 minutes with zero data loss on either channel.

  MODIFIED: REQ-SHP-POWER-001: Added note — "Power budget must account
    for BLE advertising and connection intervals. 2-year target assumes
    BLE connected ≤10% of operating time."

Proposed Jira work items:

  ┌──────────┬────────────────────────────────────┬──────────┬──────────┐
  │ Key      │ Summary                            │ Type     │ Assignee │
  ├──────────┼────────────────────────────────────┼──────────┼──────────┤
  │ SHP-14   │ Implement BLE GATT server for      │ Story    │ Priya    │
  │          │ sensor data characteristics         │          │          │
  │ SHP-15   │ Add BLE configuration write         │ Story    │ Priya    │
  │          │ characteristics (rate, TX interval)  │          │          │
  │ SHP-16   │ Implement LoRa/BLE time-division   │ Story    │ Maria    │
  │          │ multiplexer                          │          │          │
  │ SHP-17   │ Update power budget model for BLE  │ Task     │ Maria    │
  │          │ operating scenarios                  │          │          │
  └──────────┴────────────────────────────────────┴──────────┴──────────┘

  SHP-15 blocked by SHP-14
  SHP-16 blocked by SHP-6 (LoRa stack) and SHP-14 (BLE stack)

Approve? [y/n/edit]

/> y

✓ doc/requirements.md updated (3 new, 1 modified)
✓ 4 Jira tickets created
✓ Triage branch merged
```

---

## Day 14: Meeting Transcript Triage

David records a project sync meeting. He feeds the raw transcript into triage to extract action items.

### 5.1 Triage a Meeting Transcript

```
/> /shp:triage

Meeting transcript from SHP weekly sync (2026-03-28):

Maria: "OK so the watchdog timer is done. I tested it on the eval board,
recovery logging works. But I noticed the flash write during watchdog
recovery takes about 200ms, which means if we get a watchdog reset
during a flash write, we could corrupt the wear-leveling metadata."

Jake: "That's a real problem. We should add a flash journal or at least
a dirty flag so we can detect and recover from that."

Priya: "I was going to bring up something similar. The OTA update
writes to flash too. If the device resets mid-OTA write, we need a
way to roll back to the previous firmware image. I was thinking a
dual-bank approach — write to bank B while running from bank A."

David: "Good catches. Maria, can you file those as risks? Also, the
customer demo is April 15. We need at minimum: sensor reading,
flash logging, and LoRa transmission working end-to-end by then.
BLE can wait until v2. Let's mark BLE tickets as v2 milestone."

Jake: "One more thing — the vibration sensor driver is flaky on the
I2C bus. I'm seeing NAK errors about 2% of the time. Might be a
pull-up resistor value issue but could also be a timing problem
in the I2C driver."

Maria: "Let's capture that too. Could be related to the bus speed —
we're running at 400kHz fast mode, maybe drop to 100kHz standard
mode and see if it resolves."
```

```
Analyzing meeting transcript...

Extracted 5 discrete items from transcript:

  1. RISK — Flash corruption during watchdog recovery
     Source: Maria, confirmed by Jake
     Component: storage, watchdog
     Severity: HIGH — data integrity risk
     Action: Add flash journal or dirty flag for crash recovery
     Linked: REQ-SHP-WDT-001, REQ-SHP-STORAGE-001

  2. RISK — OTA update interrupted by reset corrupts firmware
     Source: Priya
     Component: OTA
     Severity: HIGH — device could be bricked
     Action: Implement dual-bank (A/B) firmware update strategy
     Linked: REQ-SHP-OTA-001

  3. SCOPE DECISION — BLE deferred to v2 milestone
     Source: David (PM decision)
     Action: Move SHP-14, 15, 16, 17 to v2 milestone in Jira

  4. MILESTONE — Customer demo April 15
     Required: sensor reading + flash logging + LoRa TX end-to-end
     Action: Create milestone in Jira, link SHP-1 through SHP-6

  5. BUG — I2C NAK errors on vibration sensor (~2% failure rate)
     Source: Jake
     Component: drivers/transport_i2c
     Severity: MEDIUM — intermittent, may be hardware or software
     Hypothesis: Bus speed (400kHz) or pull-up resistor values
     Linked: REQ-SHP-SENSOR-002

Creating triage branch: triage/weekly-sync-2026-03-28
Committing 5 triage documents...

✓ Meeting transcript triaged into 5 items

  2 HIGH severity risks (flash corruption, OTA brick)
  1 scope decision (BLE → v2)
  1 milestone (demo April 15)
  1 MEDIUM bug (I2C NAK errors)

  Next: /shp:plan to process all 5 items
```

### 5.2 Plan From Meeting Items

```
/> /shp:plan
```

```
Discovering triage branches...

Found 1 triage branch:
  ● triage/weekly-sync-2026-03-28 (5 items: 2 risks, 1 scope, 1 milestone, 1 bug)

Synthesizing...

Proposed requirement changes:

  MODIFIED: REQ-SHP-WDT-001: Added — "Recovery logging must not
    corrupt flash wear-leveling metadata. System shall use a write
    journal or dirty flag to detect and recover from interrupted
    flash writes."

  MODIFIED: REQ-SHP-OTA-001: Added — "Firmware update shall use
    dual-bank (A/B) strategy. Device boots from bank A while writing
    update to bank B. Rollback to previous bank on failed boot."

Proposed Jira changes:

  ┌──────────┬────────────────────────────────────┬──────────┬──────────┐
  │ Key      │ Summary                            │ Type     │ Action   │
  ├──────────┼────────────────────────────────────┼──────────┼──────────┤
  │ SHP-18   │ Add flash write journal for crash  │ Story    │ CREATE   │
  │          │ recovery                            │          │          │
  │ SHP-19   │ Implement dual-bank (A/B) OTA      │ Story    │ CREATE   │
  │          │ firmware update                     │          │          │
  │ SHP-20   │ Fix I2C NAK errors on vibration    │ Bug      │ CREATE   │
  │          │ sensor at 400kHz                    │          │          │
  │ SHP-14   │ BLE GATT server                    │ Story    │ MOVE→v2  │
  │ SHP-15   │ BLE configuration writes           │ Story    │ MOVE→v2  │
  │ SHP-16   │ LoRa/BLE time-division mux         │ Story    │ MOVE→v2  │
  │ SHP-17   │ Power budget for BLE               │ Task     │ MOVE→v2  │
  │ DEMO     │ Customer Demo                      │ Milestone│ Apr 15   │
  │          │ Links: SHP-1,2,3,4,5,6              │          │          │
  └──────────┴────────────────────────────────────┴──────────┴──────────┘

Approve? [y/n/edit]

/> y

✓ doc/requirements.md updated (2 modified requirements)
✓ 3 new Jira tickets created (SHP-18, SHP-19, SHP-20)
✓ 4 BLE tickets moved to v2 milestone
✓ "Customer Demo" milestone created (April 15, 2026)
✓ Demo-critical tickets linked to milestone
✓ Triage branch merged
```

---

## Day 15-25: Multi-Issue Implementation Sprint

The team works through multiple tickets in parallel. Here is Maria's implementation of the flash write journal (SHP-18), which demonstrates the full documentation lifecycle for a standard-tier feature.

### 6.1 Implement Flash Write Journal

```
/> /shp:implement SHP-18
```

```
Fetching SHP-18 from Jira...

  Summary: Add flash write journal for crash recovery
  Acceptance Criteria:
    AC1: All flash writes go through journal (write-ahead log)
    AC2: On boot, if dirty flag is set, replay or discard incomplete writes
    AC3: Journal adds ≤5% write overhead to normal operations
    AC4: Unit test simulates power loss mid-write, verifies recovery

Linked requirements: REQ-SHP-WDT-001, REQ-SHP-STORAGE-001

Step 1/6: Parse ✓
Step 2/6: Research...
  Found: src/storage/flash_nor.c — current flash driver, no journaling
  Found: src/storage/wear_level.c — wear leveling layer
  Pattern: Storage stack is flash_nor → wear_level → application

Step 3/6: Decompose
  Subtask 1: Add flash_journal.c between wear_level and flash_nor
  Subtask 2: Journal format: header (seq, len, target_addr) + data + commit byte
  Subtask 3: Recovery function scanned on boot
  Subtask 4: Integration with watchdog recovery path
  Subtask 5: Unit tests with simulated power loss
  Subtask 6: Performance test for overhead measurement

Step 4/6: Implement...
  Branch: feature/SHP-18-flash-write-journal
  Writing src/storage/flash_journal.h...
  Writing src/storage/flash_journal.c...
  Modifying src/storage/wear_level.c (route writes through journal)...
  Modifying src/init/boot.c (add journal recovery check)...
  Writing test/test_flash_journal.c...

Step 5/6: Verify
  Tests: 12/12 passed ✓
  AC1: All writes routed through journal ✓
  AC2: Boot recovery replays uncommitted journal entries ✓
  AC3: Overhead measured: 3.2% (within 5% threshold) ✓
  AC4: Power loss simulation test passes ✓

Step 6/6: Documentation (standard tier — feature, ~180 lines)
  ✓ SDD: doc/sdd/SHP-18-flash-write-journal.md
    - Includes data flow diagram (journal → flash)
    - Describes journal entry format
    - Documents recovery algorithm
  ✓ Code coverage: 91%
  ✓ Unit test results: 12/12
  ✓ V&V audit: REQ-SHP-WDT-001 and REQ-SHP-STORAGE-001 traced

PR created: #22 "SHP-18: feat: Add flash write journal for crash recovery"
  https://github.com/acme-iot/sensorhub-pro/pull/22
```

### 6.2 Full V&V Audit Before Demo

With the demo approaching, Maria runs a full V&V audit to find gaps.

```
/> /shp:vv
```

```
Running full traceability audit...

TRACEABILITY MATRIX

  ┌──────────────────────┬──────────────┬──────────────┬────────────┐
  │ Requirement          │ Impl Status  │ Test Status  │ Doc Status │
  ├──────────────────────┼──────────────┼──────────────┼────────────┤
  │ REQ-SHP-SENSOR-001   │ ✓ Complete   │ ✓ 22 tests  │ ✓ SDD      │
  │ REQ-SHP-SENSOR-002   │ ✓ Complete   │ ✓ 22 tests  │ ✓ SDD      │
  │ REQ-SHP-STORAGE-001  │ ✓ Complete   │ ✓ 12 tests  │ ✓ SDD      │
  │ REQ-SHP-RADIO-001    │ ✓ Complete   │ ⚠ 6 tests   │ ✓ SDD      │
  │ REQ-SHP-OTA-001      │ ◐ Partial    │ ✗ No tests  │ ✗ No SDD   │
  │ REQ-SHP-POWER-001    │ ◐ Partial    │ ⚠ 2 tests   │ ✗ No SDD   │
  │ REQ-SHP-DIAG-001     │ ✓ Complete   │ ✓ 8 tests   │ ✓ SDD      │
  │ REQ-SHP-WDT-001      │ ✓ Complete   │ ✓ 16 tests  │ ✓ SDD      │
  │ REQ-SHP-RADIO-002    │ — Deferred   │ — v2        │ — v2       │
  │ REQ-SHP-RADIO-003    │ — Deferred   │ — v2        │ — v2       │
  │ REQ-SHP-RADIO-004    │ — Deferred   │ — v2        │ — v2       │
  └──────────────────────┴──────────────┴──────────────┴────────────┘

COVERAGE GAPS

  CRITICAL (1):
    REQ-SHP-OTA-001 — Dual-bank OTA partially implemented (SHP-19 in progress),
    no tests yet. Demo-critical if OTA is in scope.

  HIGH (1):
    REQ-SHP-POWER-001 — Power state machine implemented but only 2 sleep/wake
    tests. No power budget model document.

  MEDIUM (1):
    REQ-SHP-RADIO-001 — LoRa TX works but only 6 tests. Missing: packet loss
    test, range boundary test.

DOCUMENTATION GAPS
    REQ-SHP-OTA-001 — No SDD
    REQ-SHP-POWER-001 — No SDD, no power budget model

DEMO READINESS (April 15)
  Required: sensor reading + flash logging + LoRa TX
    ✓ Sensor reading — complete and tested
    ✓ Flash logging — complete and tested (with journal)
    ✓ LoRa TX — complete, needs more tests
    ◐ OTA — in progress, not demo-critical per David

Recommended actions:
  1. /shp:implement SHP-19 — Complete OTA dual-bank (CRITICAL gap)
  2. Add power budget model document for REQ-SHP-POWER-001
  3. Add LoRa packet loss and range tests for REQ-SHP-RADIO-001
```

---

## Day 26: Email and Communication Workflow

Maria receives an email from the customer asking about BLE timeline. She uses the email skill.

### 7.1 Email Triage

```
/> /shp:email
```

```
INBOX SUMMARY (4 unread)

  ACTION REQUIRED (1)
    ● From: Chen Wei (customer) — "BLE timeline for SensorHub Pro?"
      Received: 2026-04-01 09:15
      Preview: "Hi team, our mobile app team needs to know when BLE
      will be available so they can plan their sprint..."

  FYI (2)
    ● From: Jira — "SHP-19 moved to In Review"
    ● From: GitHub — "PR #24 approved by Maria"

  PROMOTIONAL (1)
    ● From: EmbeddedConf — "Early bird registration closing"

Actions:
  1. Reply to Chen Wei's BLE timeline question
  2. Archive promotional email
```

```
/> Reply to Chen Wei. BLE is deferred to v2, targeting end of Q2. v1
   demo is April 15 with core sensor/storage/LoRa functionality.
```

```
Draft reply to Chen Wei:

  Subject: Re: BLE timeline for SensorHub Pro?

  Hi Chen Wei,

  Thanks for reaching out. BLE support (GATT server for sensor data
  and mobile configuration) is planned for v2, which we're targeting
  for end of Q2 2026.

  Our v1 release focuses on the core sensor acquisition, flash
  storage, and LoRa transmission pipeline. We have a customer demo
  scheduled for April 15 showcasing this functionality end-to-end.

  I'll keep you posted as we finalize the v2 timeline. Please let me
  know if your mobile team needs any interface specs in advance to
  begin planning.

  Best regards,
  Maria

Send? [y/n/edit]

/> y
✓ Email sent
```

---

## Day 28: Pre-Demo Project Status

### 8.1 Final PM Check

```
/> /shp:pm
```

```
PROJECT: SensorHub Pro (SHP)

MILESTONE: Customer Demo — April 15 (14 days away)
  ✓ SHP-1   Sensor driver framework          DONE
  ✓ SHP-2   Temperature sensor               DONE
  ✓ SHP-3   Pressure sensor                  DONE
  ✓ SHP-4   Vibration sensor                 DONE
  ✓ SHP-5   Flash storage + wear leveling    DONE
  ✓ SHP-6   LoRa radio TX/RX                 DONE
  ✓ SHP-9   UART debug console               DONE
  ✓ SHP-10  Watchdog timer                   DONE
  ✓ SHP-13  SPI FIFO underflow fix           DONE
  ✓ SHP-18  Flash write journal              DONE
  ◐ SHP-19  Dual-bank OTA                    IN PROGRESS (Priya)
  ◐ SHP-20  I2C NAK fix                      IN PROGRESS (Jake)

BLOCKERS (0)
  None

IN REVIEW (1)
  PR #24 — SHP-19 dual-bank OTA (approved, merge pending)

DOCUMENTATION DEBT
  REQ-SHP-POWER-001 — Power budget model needed
  REQ-SHP-OTA-001 — SDD in draft

V2 BACKLOG (deferred)
  SHP-14,15,16,17 — BLE features (end of Q2)

HEALTH
  Test coverage: 87% overall
  Requirements traced: 8/8 active (3 deferred)
  Open bugs: 1 (SHP-20, medium severity)

Status: ON TRACK for April 15 demo
  Demo-critical items: 100% complete
  Remaining: OTA (nice-to-have for demo), I2C fix (non-blocking)

Suggested actions:
  1. Merge PR #24 (OTA) — approved, ready
  2. /shp:implement SHP-20 — I2C fix before demo if time permits
  3. Write power budget model — documentation gap
```

### 8.2 Weekly Timecard

```
/> /shp:timecard this-week
```

```
Gathering activity for this week (2026-04-06 to 2026-04-10)...

  ┌──────────┬───────────────────────────────────┬───────┐
  │ Work Item│ Description                       │ Hours │
  ├──────────┼───────────────────────────────────┼───────┤
  │ SHP-18   │ Flash journal — code review,      │  3.0  │
  │          │ feedback incorporation              │       │
  │ SHP-19   │ OTA review — PR #24 code review   │  2.0  │
  │ SHP-16   │ LoRa/BLE mux — design doc (v2     │  1.5  │
  │          │ planning)                           │       │
  │ SHP-20   │ I2C NAK investigation — logic      │  4.0  │
  │          │ analyzer captures, root cause       │       │
  │ (none)   │ Team meetings, email, planning     │  2.5  │
  ├──────────┼───────────────────────────────────┼───────┤
  │          │                            Total:  │ 13.0  │
  └──────────┴───────────────────────────────────┴───────┘

  Note: 2.5 hours unlinked (meetings, email). Assign to a project
  code or leave as overhead? [assign/overhead]

/> overhead

✓ 5 time entries created in Harvest
  4 linked to Jira work items
  1 overhead (meetings/email)
```

---

## Orchestrator Integration (TRA-104)

The `/orchestrate` skill serves as the central task lifecycle coordinator:

1. **Entry**: `user> /orchestrate status` — shows dependency-aware dashboard of all work items
2. **Selection**: `user> /orchestrate next` — recommends highest-priority unblocked item
3. **Start**: `user> /orchestrate start SHP-1` — validates dependencies, creates branch, transitions tracker to "In Progress"
4. **Implementation**: `user> /implement SHP-1` — existing workflow (now with Step 0 gate check)
5. **Review**: `user> /pr` — existing workflow (now with output verification gate + auto state transition to "In Review")
6. **Validation**: `user> /vv SHP-1` — existing workflow (now attaches V&V report to tracker)
7. **Completion**: `user> /orchestrate complete SHP-1` — verifies all gates, transitions to "Done", reports unblocked items

### Process Enforcement

When `process_enforcement.mode: warn`:
- Gate violations show warnings with remediation instructions
- User can override with confirmation

When `process_enforcement.mode: block`:
- Gate violations prevent proceeding
- User must resolve the issue before continuing

### Full Lifecycle Mode

`user> /orchestrate run SHP-1` — automates the entire sequence (start → implement → pr → vv → complete) with confirmation pauses at each step.

### Enforcement Engine (TRA-118)

Building on the orchestrator, the enforcement engine adds:
- **Structured rejections**: Gate failures return JSON with rejection codes, remediation, and retry policies
- **Role-based access control**: Team member roles govern which transitions are allowed
- **Human gates**: Configurable approval requirements (design review, PR review, sign-off) with timeout and escalation
- **Two-tier verification**: Mechanical checks (Tier 1) + intelligent sub-agent evaluation (Tier 2)

---

## Summary: Complete Lifecycle Flow

This simulation demonstrated how a firmware project flows through the harness plugin from initial requirements to demo-ready product:

```
Day 1     /catch-me-up ─── Morning context across email, chat, calendar
            │
          /triage ──────── Product brief → 8 structured requirements
            │                (ISO 29148 quality checks, feasibility flags)
            │
          /plan ────────── 8 REQs → doc/requirements.md + 12 Jira tickets
            │                (dependencies linked, assignees set)
            │
          /pm ──────────── Prioritized backlog, unblocking order

Day 2-5   /implement ───── SHP-1 sensor driver framework
            │                (code → tests → SDD → PR, standard tier)
            │
          /timecard ────── Git commits → time entries in Harvest

Day 6     /triage ──────── Bug: SPI FIFO underflow (discovered during integration)
            │
          /plan ────────── Bug → SHP-13 with acceptance criteria
            │
          /implement ───── Fix: 23 lines, 4 new tests (minimal tier docs)
            │
          /vv ──────────── Targeted audit: REQ-SHP-SENSOR-002 fully traced

Day 10    /triage ──────── Scope change: BLE support (flagged OUT OF SCOPE)
            │                (impact analysis, power budget risk)
            │
          /plan ────────── 3 new REQs, 4 Jira tickets, PM approval required

Day 14    /triage ──────── Meeting transcript → 5 discrete items
            │                (2 risks, 1 scope decision, 1 milestone, 1 bug)
            │
          /plan ────────── 2 REQ updates, 3 new tickets, 4 moved to v2,
                             milestone created

Day 15-25 /implement ───── Multiple tickets in parallel (team of 4)
            │
          /vv ──────────── Full audit: traceability matrix, coverage gaps,
                             demo readiness assessment

Day 26    /email ────────── Customer inquiry → drafted reply re: BLE timeline

Day 28    /pm ──────────── Pre-demo status: ON TRACK, 100% demo-critical done
            │
          /timecard ────── Weekly time entries from cross-system activity

          /harness ─────── (Available anytime) Plugin health, MCP connectivity
          /update ──────── (Available anytime) Plugin version management
```

### Key Patterns Demonstrated

| Pattern | Skills Used | Example |
|---------|-------------|---------|
| Requirements intake | `/triage` → `/plan` | Product brief → REQs → Jira tickets |
| Bug lifecycle | `/triage` → `/plan` → `/implement` → `/vv` | SPI underflow: found → filed → fixed → verified |
| Scope change | `/triage` → `/plan` | BLE request: flagged out-of-scope → new REQs after PM approval |
| Meeting extraction | `/triage` → `/plan` | Raw transcript → 5 structured items → tickets + milestones |
| Documentation tiers | `/implement` | Minimal (bug fix), Standard (feature), Comprehensive (architecture) |
| Quality gates | `/vv` | Traceability matrix, coverage gaps, demo readiness |
| Communication | `/email` | Inbox triage, draft replies with context |
| Time tracking | `/timecard` | Git + Jira activity → Harvest entries |
| Project visibility | `/pm` | Blockers, priorities, WIP discipline, health |
| Morning context | `/catch-me-up` | Cross-system briefing: email + chat + calendar + work items |

### What the Plugin Does NOT Do

- **Make decisions for you** — Every write action (Jira ticket creation, email send, time entry) requires explicit user approval
- **Replace engineering judgment** — It structures and automates the workflow, but humans decide what to build and how
- **Store credentials** — MCP connections are defined in the plugin; credentials stay in your local environment
- **Push code without review** — PRs go through the standard review process with human reviewers
