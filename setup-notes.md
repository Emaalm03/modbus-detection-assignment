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
- Ubuntu Server 22.04, RAM 8 GB, 4 CPUs, 50 GB disk
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


### Docker and Zeek
```bash
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
docker pull zeek/zeek
### Wazuh (all-in-one, installation assistant)
```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a
```
- Installed: manager, indexer and dashboard on the same VM (no agent)

## attacker (Kali)
- Kali Linux, runs the attack scripts
- Lab IP: to be set on its host-only adapter
