# Wazuh Test Results

Method: each capture's Zeek-converted log (modbus.log or conn.log) was
appended to a single monitored pipeline file
(/var/log/modbus/pipeline-modbus.log or pipeline-conn.log), truncated
before each test, then checked against /var/ossec/logs/alerts/alerts.json.
This is equivalent to the real ingestion pipeline Wazuh uses (localfile,
log_format json), just driven one capture at a time for isolation.

## Rule 100011 — Reconnaissance

**Fires on:** attack_01_recon / attack_01b_recon_modbusdetect_loop (func
READ_INPUT_REGISTERS or ENCAP_INTERFACE_TRANSPORT, from a non-master
source).

**Confirmed example alert (dashboard, Oct 27 2026 @ 18:18:40):**

```
rule.id: 100011
rule.level: 6
rule.description: Modbus: reconnaissance probe from non-master source
data.func: READ_INPUT_REGISTERS
data.conn_id.orig_h: 192.168.56.6
data.conn_id.resp_h: 192.168.56.4
```

**Baseline check:** fed baseline_test/modbus.log through the pipeline;
grep for rule 100011 returned no matches.

---

## Rule 100012 — Unauthorized coil write

**Fires on:** attack_02a_valve_write_metasploit (func WRITE_SINGLE_COIL, any source).

**Confirmed example alert — real attack (attacker source, 192.168.56.6):**

rule.id: 100012
rule.level: 12
rule.description: Modbus: unauthorized coil write (valve/pump command) - baseline never writes, regardless of source
data.func: WRITE_SINGLE_COIL
data.id.orig_h: 192.168.56.6

**Also confirmed — fires identically on a legitimate-source write (master, 192.168.56.3), demonstrating the false-positive edge case documented in edge-cases.md:**

```
rule.id: 100012
rule.level: 12
rule.description: Modbus: unauthorized coil write (valve/pump command) - baseline never writes, regardless of source
data.func: WRITE_SINGLE_COIL
data.id.orig_h: 192.168.56.3
```
(Both examples fired twice each: once on REQ, once on RESP — both carry the func field. The rule's source-independence is deliberate; see edge-cases.md for the rationale and tradeoff.)

**Baseline check:** fed baseline_test/modbus.log through the pipeline; grep for rule 100012 returned no matches.

---

## Rule 100013 — Unauthorized register write

**Fires on:** attack_03_setpoint_write_metasploit (func
WRITE_SINGLE_REGISTER, any source).

**Confirmed example alert (dashboard, Oct 28 2026 @ 16:14:43):**

```
rule.id: 100013
rule.level: 12
rule.description: Modbus: unauthorized register write (setpoint
manipulation) - baseline never writes, regardless of source
data.func: WRITE_SINGLE_REGISTER
data.conn_id.orig_h: 192.168.56.6
data.conn_id.resp_h: 192.168.56.4
rule.mail: true
```

**Baseline check:** fed baseline_test/modbus.log through the pipeline;
grep for rule 100013 returned no matches.

---

## Rule 100014 — Reset / diagnostic attempt

**Fires on:** attack_04a_reset_metasploit (func PROGRAM_UNITY) and
attack_04b_reset_fc8_python (func DIAGNOSTICS).

**Confirmed via wazuh-logtest:**

```
Input: {"func":"DIAGNOSTICS", "id.orig_h":"192.168.56.6", ...}
Phase 3: id: 100014, level: 10
description: Modbus: reset or diagnostic command attempt - function
never used in baseline
Alert to be generated.
```

**Baseline check:** fed baseline_test/modbus.log through the pipeline;
grep for rule 100014 returned no matches.

---

## Rule 100017 — Exception response (generic)

**Fires on:** attack_01_recon (ENCAP_INTERFACE_TRANSPORT_EXCEPTION),
attack_04a_reset_metasploit (PROGRAM_UNITY_EXCEPTION),
attack_04b_reset_fc8_python (DIAGNOSTICS_EXCEPTION).

**Confirmed:** triggered alongside rules 100011/100014 on the same
captures (any func value ending in _EXCEPTION).

**Baseline check:** fed baseline_test/modbus.log through the pipeline;
grep for rule 100017 returned no matches (baseline contains zero
exception responses).

---

## Rules 100015 / 100016 — Connection Volume and Flood Detection

**Source log:** `conn.log`, processed through `pipeline-conn.log`.

**Rule 100016 fires on:** `attack_05b_read_flood_python/conn.log`. This scenario uses a single TCP connection with more than 22,000 origin packets, exceeding the four-digit packet threshold.

**Rule 100016 does not fire on:** `attack_05a_read_flood_python/conn.log`. This scenario generates 144 separate connections, each containing only 1–2 origin packets. The packet count of each individual connection remains below the threshold required by Rule 100016.

However, the short-connection scenario is not completely undetected. Rule 100015 generates alerts for connections from the non-master source `192.168.56.6`. The limitation is that Rule 100015 detects individual connections but does not aggregate their frequency over a defined time window.

**Baseline check:** Feeding `baseline_test/conn.log` through the pipeline produced no alerts for Rules 100015 and 100016. The authorised master's traffic is excluded through the non-master-source condition in Rule 100015, which is the parent rule for Rule 100016.

**Detection gap:** The current rules identify individual non-master connections and high-volume connections, but they do not directly detect an unusually high connection rate by counting connections within a time window. A rate-based correlation rule could improve detection of this pattern, although legitimate reconnects and maintenance activity could also trigger alerts.

---

## Summary table

| Rule   | Attack it detects      | Fires on attack     | Silent on baseline |
|--------|------------------------|:-------------------:|:------------------:|
| 100011 | Reconnaissance         | Yes                 | Yes                |
| 100012 | Coil write             | Yes                 | Yes                |
| 100013 | Register write         | Yes                 | Yes                |
| 100014 | Reset / diagnostic     | Yes                 | Yes                |
| 100017 | Any exception response | Yes                 | Yes                |
| 100016 | High-volume flood (5b) | Yes                 | Yes                |
| 100016 | Low-rate flood (5a)    | No (documented gap) | Yes                |
