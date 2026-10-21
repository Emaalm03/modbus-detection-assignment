# Setup notes

## Lab overview
- Host: MacBook Pro 2018, VirtualBox
- VMs: master, plc (Ubuntu Server 22.04), attacker (Kali), wazuh
- Every VM: Adapter 1 NAT, Adapter 2 host-only (192.168.56.0/24)

## master (Ubuntu Server 22.04)
- RAM 2 GB, 2 CPUs, 20 GB disk
- Fixed IP on enp0s8: 192.168.56.3

### Commands that worked
$ sudo apt update
$ sudo apt install -y openssh-server
$ sudo systemctl enable --now ssh
$ sudo apt install -y git curl net-tools tcpdump python3-pip
$ git clone https://github.com/thiagoralves/OpenPLC_v3.git
$ cd OpenPLC_v3 && ./install.sh linux

### Problems and fixes
- enp0s8 got its address from DHCP, not a static one.
  Fix: in /etc/netplan/50-cloud-init.yaml set enp0s8 to dhcp4: false
  with addresses: [192.168.56.3/24], then sudo netplan apply.

## plc

