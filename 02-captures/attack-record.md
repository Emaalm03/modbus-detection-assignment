# Attack Record

All attacks were executed from Kali (192.168.56.6) against the plc
(192.168.56.4:502), except the false-positive edge case, executed
from the master (192.168.56.3). Captures were taken with tcpdump on
the plc, on the host-only interface, filtered to port 502.

## Attack 1 — Reconnaissance

**Tools:** Metasploit `auxiliary/scanner/scada/modbusdetect`,
`auxiliary/scanner/scada/modbus_findunitid`,
`auxiliary/scanner/scada/modbus_banner_grabbing`; a supplementary
Python loop using function code 4 was also captured separately
(`attack_01b_recon_modbusdetect_loop.pcap`).

**What was executed:**
- `modbusdetect`: confirmed Modbus/TCP, unit ID 1, correct header.
- `modbus_findunitid`: swept unit IDs (observed responses up to ID
  254+); OpenPLC's bare server accepted every ID as "correct" (no
  unit-ID validation implemented).
- `modbus_banner_grabbing`: returned an "Illegal Function" exception —
  OpenPLC does not implement the function code this module uses
  (likely Read Device Identification).

**Address/function:** function codes 4 (READ_INPUT_REGISTERS) and a
non-implemented identification function (resulting in an exception).

**Effect on process:** none — all requests were read-only.

**Capture:** `02-captures/attacks/attack_01b_recon_modbusdetect_loop.pcap`

---

## Attack 2 — Coil write (close outlet valve)

**Tool:** Metasploit `auxiliary/scanner/scada/modbusclient`,
ACTION=WRITE_COIL.

**What was executed:** FC5 (Write Single Coil), address 1 (outlet
valve), value `0x0000` (OFF). Confirmed via Wireshark: request and
response both show Function Code 5, Reference Number 1, Data 0000 —
accepted with no exception.

**Before:** valve = 1 (open), level ~51%.

**Effect on process:** with the valve closed and the pump already in
its "off" phase of the hysteresis cycle, inflow and outflow both
became 0. The tank level froze completely and stopped changing —
confirmed unchanged across repeated reads. The process could not
recover on its own: the pump would not restart until the level
naturally dropped below 20%, which cannot happen with the valve
closed. A single coil write produced a stalled/denial-of-process
condition.

**Capture:** `02-captures/attacks/attack_02a_valve_write_metasploit.pcap`

---

## Attack 3 — Register write (high setpoint manipulation)

**Tool:** Metasploit `auxiliary/scanner/scada/modbusclient`,
ACTION=WRITE_REGISTER.

**What was executed:** FC6 (Write Single Register), address 1 (high
setpoint), value 100 (0x0064). Confirmed via Wireshark: request shows
Function Code 6, Reference Number 1, Data 0064.

**Before:** High_SP = 80.
**After:** High_SP = 100.

**Effect on process:** the pump no longer shut off at the designed
80% level. Confirmed via high-rate polling (~10 reads/second): the
pump remained ON at level 91% (observed on two consecutive reads),
well past the original 80% safety margin. The pump was eventually
force-stopped by the hard-coded, non-writable 95% high-high alarm
(Alarm_HH) — caught only via polling faster than the PLC's own 100ms
scan cycle, since the alarm condition and the resulting pump shutoff
occur within the same scan, and the alarm clears on the very next
scan as the level immediately begins falling.

**Conclusion:** the attack successfully removed the primary, writable
safety threshold. The process was only protected from a full overflow
by a second, independent, non-writable safety mechanism.

**Capture:** `02-captures/attacks/attack_03a_setpoint_write_metasploit.pcap`

---

## Attack 4 — Reset / diagnostic command attempt

Two variants were tested.

### 4a — Metasploit, vendor-specific (Modicon/UMAS)

**Tool:** `auxiliary/admin/scada/modicon_command`, MODE=STOP.

**What was executed:** a multi-step sequence using non-standard
function code 90 (0x5A, Schneider/Modicon proprietary UMAS protocol)
— identification/handshake sub-commands followed by a STOP attempt.

**Result:** the attack FAILED. Confirmed via `systemctl status
openplc.service`: the service remained `active (running)` throughout
and after the attack, with no interruption in uptime. OpenPLC does
not implement genuine Modicon UMAS semantics.

**Detection relevance:** function code 90 is never used by the
legitimate master, making any packet with this function code a
reliable, zero-ambiguity indicator of this attack attempt, regardless
of success or failure.

**Capture:** `02-captures/attacks/attack_04a_reset_metasploit.pcap`

### 4b — Python, standard Modbus (FC8 Diagnostics)

**Tool:** hand-written Python (raw socket).

**What was executed:** FC8 (Diagnostics), sub-function 1 (Restart
Communications Option), data 0x0000.

**Result:** exception response `0x88` / exception code `1` ("Illegal
Function") — OpenPLC does not implement function code 8 at all.
Cleanly rejected, no process effect.

**Capture:** `02-captures/attacks/attack_04b_reset_fc8_python.pcap`

**Conclusion (both variants):** this OpenPLC configuration has no
implemented remote stop/reset command over Modbus; this category of
attack has no real foothold here. Both attempts are nonetheless
independently detectable (function code 90, or any exception
response).

---

## Attack 5 — Read flood

Two variants were tested, deliberately, to compare detection
signatures.

### 5a — Connection-per-request (slow)

**Tool:** hand-written Python, new TCP connection per request.

**What was executed:** 144 FC3 read requests over 15 seconds
(~9.6 req/s — statistically similar to the baseline's ~8 req/s).

**TCP behavior:** 144 separate TCP connections opened (144 SYN
packets), vs. the master's single persistent connection.

**Detection signal:** NOT request rate (matches baseline); IS
connection count (144 new connections from one source in 15s is
anomalous; the master opens ~1 per session).

**Capture:** `02-captures/attacks/attack_05a_read_flood_python.pcap`

### 5b — Persistent connection (fast)

**Tool:** hand-written Python, single reused TCP connection.

**What was executed:** 22,656 FC3 read requests in 15.0 seconds
(~1,510 req/s — approximately 190x the baseline rate).

**TCP behavior:** 1 TCP connection opened, reused for all 22,656
requests.

**Detection signal:** request rate (massively exceeds baseline);
connection count alone would NOT catch this variant (it looks like
one normal-looking session).

**Capture:** `02-captures/attacks/attack_05b_read_flood_python.pcap`

**Conclusion:** neither a rate-based rule nor a connection-count-based
rule alone catches both flood styles; a robust ruleset needs both
(rule 100016 in this submission currently uses a packet-count
threshold, which catches 5b; 5a's connection-pattern signature is
documented here as an acknowledged gap / future rule candidate).

---

## Baseline

**What was executed:** approximately 5 minutes of unmodified master
polling (the master's own Slave Devices configuration, reading
holding registers 0-2 from the plc), no attacker traffic present.

**Purpose:** establishes the normal-traffic footprint documented in
`01-environment/address-map.md`, and is used as the negative control
for every rule (see `wazuh-test-results.md`).

**Capture:** `02-captures/baseline/baseline_test.pcap`
