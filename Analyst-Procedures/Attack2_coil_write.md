## Attack 2: Unauthorized coil write (Rule 100012)

The alert generated here is about an unauthorized coil write, related to rule 100012.

### Step 1: Validate the alert

The analyst should start by checking the rule ID, alert level, function code, and PDU type. Rule 100012 detects the `WRITE_SINGLE_COIL` function. The PDU type can be `REQ` or `RESP`. In this case, it is `RESP`, meaning that the event is a response associated with a coil-write operation.

What this evidence answers: does the event match the condition configured in the rule?

This evidence alone does not confirm the attack or show whether the coil state changed. The analyst should examine the corresponding request in the PCAP before concluding what was targeted.

### Step 2: Identify the source

The analyst should check `data.conn_id.orig_h` to identify the source. In this case, the address is `192.168.56.6`, which belongs to the attacker VM, while the authorized master is `192.168.56.3`.

What this evidence answers: did the coil-write operation come from the authorized master?

If the source is the master, the analyst should look for documented reasons for the operation, such as approved maintenance. If the source is not the master, as in this case, the evidence does not rule out the attack, so we move to step 3.

### Step 3: Identify the targeted coil

The analyst should examine the PCAP and Zeek logs to identify the targeted coil and requested value.

In `attack_02a_valve_write_metasploit.pcap`, the attacker `192.168.56.6` sends a Write Single Coil request (function code 5) to the PLC `192.168.56.4`. The targeted coil reference is `1`, and the requested value is `0000` (OFF). The PLC then responds to the request.

**What this evidence answers:** which coil was targeted, what value was requested, and did the PLC respond?

This confirms a write attempt, but not that the coil state changed. The analyst should verify the coil mapping and compare the PLC state before and after the request. If the request cannot be found, further investigation is needed rather than ruling out the attack.

### Step 4: Check the process impact

The analyst should check the pump state, valve state, and tank level, then compare the observed values with the expected state in the address map. Where possible, the analyst should compare the PLC state before and after the request.

What this evidence answers: did the write change a control point or affect the simulated process?

If no change is observed, this does not rule out an unauthorized write attempt. The analyst should distinguish between an attempted write, a PLC response, and a confirmed state change.

### Step 5: Check the surrounding traffic

The analyst should examine events before and after the alert to see whether the write was isolated or part of a broader sequence. This includes checking for previous reconnaissance, repeated write requests, and unexpected changes in the process.

What this evidence answers: was this an isolated operation or part of an attempt to manipulate the process?

If additional suspicious commands or unexpected process changes follow, this strengthens the suspicion of a broader attack. However, even an isolated write remains suspicious when it originates from the known attacker VM.

### Conclusion

If the coil write comes from the attacker VM, the activity is suspicious. The analyst should identify the targeted coil, verify the requested value, and check whether the process state changed. The recommendation is to investigate the surrounding traffic and monitor for further attempts to manipulate the PLC.
