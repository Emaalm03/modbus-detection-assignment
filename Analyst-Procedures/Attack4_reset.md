## Attack 4: Reset or Diagnostic Command Attempt (Rule 100014)

This alert is related to a diagnostic operation detected by rule 100014.

### Step 1: Validate the alert

The analyst should check the rule ID, alert level, function, PDU type, and exception. Here, the alert shows `DIAGNOSTICS_EXCEPTION`, with PDU type `RESP` and exception `ILLEGAL_FUNCTION`. This helps confirm why the alert was generated. However, it does not show exactly what the attacker tried to do or prove that a reset happened, so we need to investigate further.

### Step 2: Identify the source

The analyst should check `data.conn_id.orig_h` and `data.conn_id.resp_h` to identify the source and destination. In this case, the source is `192.168.56.6` (attacker VM), and the destination is `192.168.56.4` (PLC). The authorized master is `192.168.56.3`. Since the traffic comes from a device that is not the authorized master, the activity is suspicious and cannot be ruled out as an attack without further checks.

### Step 3: Examine the diagnostic request and response

The analyst should examine the PCAP to find the diagnostic request and its corresponding response. In `attack_04b_reset_fc8_python.pcap`, frame 220 contains a request using function code 8 (Diagnostics), with transaction ID `1` and unit ID `1`. Frame 222 contains a response with the same transaction ID. This helps link the two packets and understand how the PLC replied. The analyst should examine their details to identify the operation attempted and determine whether the response indicates that it was rejected. Until then, the result of the operation remains uncertain.

### Step 4: Check the process impact

The analyst should check whether the PLC or simulated process shows any unexpected changes after the event. This helps determine whether the activity affected the system. If no changes are found, this does not rule out the attempt, but there may be no visible process impact. The analyst should not conclude that a reset succeeded without evidence of a corresponding change.

### Step 5: Review the surrounding traffic

The analyst should check the packets before and after the event for repeated diagnostic requests or other unusual commands from the same source. The capture `attack_04a_reset_metasploit.pcap` also contains multiple requests using function code `90`, which is different from function code `8` in the second capture. This helps determine whether the activity was isolated or part of a sequence of suspicious commands. Repeated requests increase suspicion, but do not prove that a reset occurred.

### Conclusion

The activity is suspicious because the diagnostic-related traffic comes from the attacker VM rather than the authorized master. The analyst should examine the request and response, check for process changes, and review the surrounding traffic before deciding what happened. The available evidence indicates suspicious activity, but does not prove that a reset succeeded.
