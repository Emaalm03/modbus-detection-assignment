# Edge Cases

## False positive: legitimate write from the master

**Capture:** `02-captures/edge-cases/false_positive_master_write.pcap`

**What happened:** a WRITE_SINGLE_COIL request was sent from
192.168.56.3 (the known, legitimate master), simulating an authorized
engineer performing a routine valve operation from the master
workstation.

**Alert generated:** rule 100012, level 12 ("unauthorized coil write"),
fired on this traffic — confirmed in alerts.json with
`id.orig_h: 192.168.56.3`.

**Why it fires:** rules 100012 and 100013 were deliberately built
without a source-IP condition. This was intentional: the baseline
proves the master never writes under normal operation, so any write
is anomalous regardless of source, including from a potentially
compromised master. The cost of this choice is that it also cannot
distinguish a compromised master from a legitimate one performing a
one-off authorized action.

**What I would change:** correlate writes against a maintenance-
window allowlist or change-ticket reference, so writes occurring
inside an approved window are logged at a lower severity instead of a
full critical escalation.

**Cost of that change:** requires an external data source (a
maintenance schedule or ticketing system) this lab environment does
not have. Without it, the current tradeoff is deliberate: more false
alarms during legitimate master-side operations, in exchange for not
missing a compromised-master scenario.

---

## Missed attack: reconnaissance using the baseline's own function code

**Capture:** `02-captures/edge-cases/missed_recon_fc3.pcap`

**What happened:** a READ_HOLDING_REGISTERS request (function code 3)
was sent from Kali (192.168.56.6), interleaved in time with the
master's own normal polling traffic, using the exact same function
code the master uses continuously.

**Result:** no rule fired. Confirmed via the test pipeline — grep
across all rule IDs (100011, 100012, 100013, 100014, 100017) on
alerts.json returned no output.

**Why it's missed:** rule 100011 only flags READ_INPUT_REGISTERS and
ENCAP_INTERFACE_TRANSPORT, the specific function codes observed during
testing with Metasploit's reconnaissance modules. An attacker who
instead issues READ_HOLDING_REGISTERS performs identical
information-gathering that is indistinguishable from baseline traffic
by function code alone.

**What I would change:** add a rule flagging READ_HOLDING_REGISTERS
specifically from any source other than the known master IP,
independent of function code.

**Cost of that change:** this introduces a hard dependency on a fixed,
known-good source IP allowlist. If the master's address ever changes
(DHCP reassignment, VM rebuild, network reconfiguration), the rule
silently stops working until manually updated — a maintenance burden
traded for closing this detection gap.
