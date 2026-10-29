# Setup notes

## Lab overview
- Host: MacBook Pro 2018 (Intel), VirtualBox
- VMs:
  - master: Ubuntu Server 22.04, OpenPLC Runtime (master)
  - plc: Ubuntu Server 22.04, OpenPLC Runtime (slave)
  - wazuh: Ubuntu Server 22.04, Wazuh manager (no agent) + Zeek in Docker
  - attacker: Kali Linux, attack scripts
- Every VM: Adapter 1 = NAT (internet), Adapter 2 = host-only (192.168.56.0/24)
- Host side of the lab network: 192.168.56.1, host-only DHCP server disabled

## master (OpenPLC master)
- Ubuntu Server 22.04, RAM 2 GB, 2 CPUs, 20 GB disk
- Lab IP on enp0s8: 192.168.56.3 (static)

### Commands that worked
```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo apt install -y git curl net-tools tcpdump python3-pip
git clone https://github.com/thiagoralves/OpenPLC_v3.git
cd OpenPLC_v3
./install.sh linux
```

### Network configuration
/etc/netplan/50-cloud-init.yaml, enp0s8 block:
```yaml
enp0s8:
  dhcp4: false
  addresses: [192.168.56.3/24]
```
Applied with `sudo netplan apply`.

### Problems and fixes
- enp0s8 got its address from DHCP, not a static one. Fixed with the netplan change above.
- Earlier temporary workaround (not persistent across reboots): `sudo ip link set enp0s8 up` and `sudo dhclient enp0s8`.

### Result
- OpenPLC web interface: http://192.168.56.3:8080

## plc (OpenPLC slave)
- Ubuntu Server 22.04, RAM 2 GB, 2 CPUs, 20 GB disk
- Lab IP on enp0s8: 192.168.56.4 (static)
- Same commands and same netplan change as master, with a different address.

### Result
- OpenPLC web interface: http://192.168.56.4:8080

## wazuh (Wazuh manager + Zeek in Docker)
- Ubuntu Server 22.04, RAM 8 GB, 4 CPUs, 50 GB disk (installer initially
  used only 25 GB of the 50 GB disk, no LVM; expanded with growpart +
  resize2fs)
- Lab IP on enp0s8: 192.168.56.5 (static), reachable by SSH from the Mac

### Network configuration
/etc/netplan/50-cloud-init.yaml:
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses: [192.168.56.5/24]
```

### Disk expansion
```bash
sudo apt install -y cloud-guest-utils
sudo growpart /dev/sda 2
sudo resize2fs /dev/sda2
```
Result: / grew from 25 GB to 50 GB.

### Docker and Zeek
```bash
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
docker pull zeek/zeek
docker run --rm zeek/zeek zeek --version
```
- Zeek version: 9.0.0
- Pinned image: zeek/zeek@sha256:70733f4e540ba1608e37e00c6a93d009f79734262c9ec2ba09d90aa9abc16de5
  (used in all conversions instead of the mutable `latest` tag)

### Zeek conversion (per capture)
```bash
mkdir -p ~/modbus-assignment/zeek-output/<capture-name>
docker run --rm --user "$(id -u):$(id -g)" \
  -v ~/modbus-assignment/incoming:/pcaps:ro \
  -v ~/modbus-assignment/zeek-output/<capture-name>:/out \
  -w /out \
  zeek/zeek@sha256:70733f4e540ba1608e37e00c6a93d009f79734262c9ec2ba09d90aa9abc16de5 \
  zeek -C -r /pcaps/<capture-name>.pcap LogAscii::use_json=T
```

### Wazuh (all-in-one, installation assistant)
```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a
```
- Installed: manager, indexer and dashboard on the same VM (no agent)
- Dashboard: https://192.168.56.5 (self-signed certificate warning expected)

### Ingestion pipeline
/var/ossec/etc/ossec.conf, added inside `<ossec_config>`:
```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/modbus/pipeline-modbus.log</location>
</localfile>
<localfile>
  <log_format>json</log_format>
  <location>/var/log/modbus/pipeline-conn.log</location>
</localfile>
```
```bash
sudo mkdir -p /var/log/modbus
sudo touch /var/log/modbus/pipeline-modbus.log /var/log/modbus/pipeline-conn.log
sudo systemctl restart wazuh-manager
```

### Testing a capture
```bash
sudo truncate -s 0 /var/log/modbus/pipeline-modbus.log
sudo bash -c 'cat /home/vboxuser/modbus-assignment/zeek-output/<capture-name>/modbus.log >> /var/log/modbus/pipeline-modbus.log'
sleep 2
sudo grep "<rule-id>" /var/ossec/logs/alerts/alerts.json
```

### Decoders and rules
- No custom decoder written: Wazuh's built-in `json` decoder
  auto-extracts all fields from Zeek's single-line JSON logs
  (confirmed via wazuh-logtest). See 03-detection/decoders/README.md
  for the full reasoning.
- Custom rules: /var/ossec/etc/rules/local_rules.xml, copied into
  this repo at 03-detection/rules/local_rules.xml.

### Problems and fixes
- Mac-to-VM ping initially failed; resolved once SSH connectivity was
  confirmed working (the ping test itself was unreliable, likely
  blocked by the Mac's firewall; SSH confirmed the network was fine).
- Docker commands failed with "permission denied" until a full
  logout/login after `usermod -aG docker $USER` (group membership
  requires a fresh session).
- A `negate="yes"` field in local_rules.xml silently failed to match
  when combined with regex metacharacters (^, $, \.) without
  `type="pcre2"` explicitly set; fixed by adding `type="pcre2"` to
  every field using regex syntax.
- A malformed custom decoder (incomplete regex, unclosed tag) caused
  `systemctl restart wazuh-manager` to fail entirely; resolved by
  clearing local_decoder.xml and validating with
  `sudo /var/ossec/bin/wazuh-control configcheck` before each restart.


## attacker (Kali)
- Kali Linux, Adapter 1 = NAT, Adapter 2 = host-only
- Lab IP on host-only adapter: 192.168.56.6 (static)


### Tools used
```bash
pip install pymodbus
```
- Metasploit (pre-installed on Kali): modules used —
  auxiliary/scanner/scada/modbusdetect,
  auxiliary/scanner/scada/modbus_findunitid,
  auxiliary/scanner/scada/modbus_banner_grabbing,
  auxiliary/scanner/scada/modbusclient (ACTION=WRITE_COIL,
  ACTION=WRITE_REGISTER),
  auxiliary/admin/scada/modicon_command (MODE=STOP)
- Hand-written Python (raw sockets, no library dependency beyond
  the standard `socket` and `struct` modules) for the remaining
  attacks: coil/register write comparisons, FC8 diagnostics,
  read flood (both variants), and the two edge-case tests.
