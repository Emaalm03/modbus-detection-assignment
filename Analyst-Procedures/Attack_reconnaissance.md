## Attack 1: Reconnaissance probe (Rule 100011)

The alert generated here is about a reconnaissance probe, related to
rule 100011.

### Step 1: Validate the alert

The analyst should start by validating the alert: the rule ID, the
alert level, and which function was used (data.func), which can be
READ_INPUT_REGISTERS or ENCAP_INTERFACE_TRANSPORT. If the source used
either of these functions, the alert is generated.

What this evidence answers: is this a genuine function-code mismatch,
or something else? In this case, the function shows
READ_INPUT_REGISTERS, which is not a function normally used in this
environment. This evidence alone does not rule the attack out, so we
move to the next step.

### Step 2: Identify the source

The analyst should identify the source of the request. The evidence
here is data.conn_id.orig_h, which shows where the request came from.
We check whether this address is a known, approved master or not.

What this evidence answers: is this address the known master?

This step rules the attack out if the source is the master address
AND a documented reason exists for the master using a non-standard
function, for example diagnostics, a maintenance window, or a firmware
update. If the source is a different address, not the master, then
this evidence does not rule the attack out, and we move to step 3.

### Step 3: Check the target and the scope

In this step, the analyst checks what the request targets and its
scope. The evidence here is data.conn_id.resp_h, which confirms the
target, in this case the known plc. The analyst should also look at
the specific addresses or unit IDs queried, and how many times this
source has triggered the rule in a short window, by checking the
timeline of events for that source.

What this evidence answers: is this a single, isolated query, or part
of a sweep across multiple addresses?

This helps the analyst determine whether this looks like a one-off
check or an automated scan. If it is a single query at a reasonable,
human pace, this rules the attack out as reconnaissance scanning. If
there are many rapid requests across several addresses, this does not
rule it out, and we move to step 4.

### Step 4: Assess the process impact

Here, the analyst checks the current state of the process: the level,
the pump, and the valve state, by polling the plc directly, then
compares these values to the normal ranges in the address map.

What this evidence answers: did this activity cause, or lead to, any
harm to the process?

Since this is a read-only attack, this step can never fully rule out
the attack on its own, because a read never changes the process by
definition. Its real purpose is to confirm whether a write followed
this read. If no write is found immediately after, the purpose of this
activity was reconnaissance only, not an active manipulation attempt.

### Conclusion

If the source is not the master, and the scope shows repeated probing,
this is reconnaissance. Since reading alone does not harm the process,
the recommendation is to monitor this source for any write activity
that may follow.
