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

rule.id: 100012
rule.level: 12
rule.description: Modbus: unauthorized coil write (valve/pump command) - baseline never writes, regardless of source
data.func: WRITE_SINGLE_COIL
data.id.orig_h: 192.168.56.3

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

## Rules 100015 / 100016 — Connection volume / flood

**Source log:** conn.log (not modbus.log), fed into pipeline-conn.log.

**100016 fires on:** attack_05b_read_flood_python/conn.log (one
connection, 22,656 packets — orig_pkts matches the 4+-digit threshold).

**100016 does NOT fire on:** attack_05a_read_flood_python/conn.log
(144 separate connections, each with only 1-2 packets — orig_pkts
never reaches 4 digits on any single connection). This is the
documented missed-attack-variant style gap for the slow/
connection-per-request flood; see edge-cases.md for the related,
confirmed-missed FC3 reconnaissance case.

**Baseline check:** fed baseline_test/conn.log through the pipeline;
grep for rules 100015/100016 returned no matches (the master's single
long-lived connection is explicitly excluded by the non-master-source
condition on rule 100015).

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
