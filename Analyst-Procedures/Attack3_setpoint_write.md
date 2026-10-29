## Attack 3: Unauthorized Register Write (Rule 100013)

The alert generated here concerns an unauthorized register write detected by rule 100013.

### Step 1: Validate the alert

The analyst should check the rule ID, alert level, function code, and PDU type. In this case, `WRITE_SINGLE_REGISTER` with PDU type `REQ` indicates a write request sent to the PLC. This helps determine whether the event matches the condition configured in the rule. However, the alert alone does not prove that the register value changed, so the analyst should examine the corresponding packets in the PCAP.

### Step 2: Identify the source

The analyst should check `data.conn_id.orig_h` to identify where the request came from. Here, the source is `192.168.56.6`, which belongs to the attacker VM, while the authorized master is `192.168.56.3`. This helps determine whether the request came from an authorized device. Since the source is not the authorized master, the activity is suspicious and requires further investigation. If the source were the authorized master, the analyst would need to check whether the operation was part of approved maintenance or a legitimate setpoint adjustment.

### Step 3: Identify the targeted register

The analyst should examine the PCAP and related Zeek logs to identify the register address and requested value. In `attack_03a_setpoint_write_metasploit.pcap`, the attacker sends a Write Single Register request (function code 6) to the PLC `192.168.56.4`. The targeted register reference is `1`, and the requested value is `0064` in hexadecimal, equivalent to `100` in decimal. This helps determine which register was targeted and what value the attacker attempted to write. The analyst should verify the register mapping before identifying the exact process variable or setpoint.

### Step 4: Check the process impact

The analyst should compare the relevant register value before and after the request and check the tank level, pump, and valve states where relevant. This helps determine whether the write changed a register value or affected the simulated process. If no change is observed, the unauthorized write attempt is still suspicious. The analyst must distinguish between a write request, a PLC response, and a confirmed change in the process.

### Step 5: Check the surrounding traffic

The analyst should review events before and after the alert for previous reconnaissance, repeated write requests, or unexpected changes in setpoints and process behavior. This helps determine whether the request was isolated or part of a broader attempt to manipulate the process. Additional suspicious activity strengthens this suspicion, although an isolated write from the attacker VM still requires investigation.

### Conclusion

The request is suspicious because it originated from the attacker VM (`192.168.56.6`) rather than the authorized master (`192.168.56.3`). The analyst should verify the targeted register and requested value, check whether the PLC accepted the write and whether the process state changed, and monitor for further unauthorized activity.
