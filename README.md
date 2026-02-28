# qvmctl ![Version](https://img.shields.io/badge/v1.0.0-blue) ![Last Commit](https://img.shields.io/github/last-commit/melovart/qvmctl)
**Quick Virtual Machine Control** - Lightweight QEMU-based virtual machine control utility for cloud VPS environments. Easily launch your own virtual machines using **VirtIO** and **your own ISO** (BYO ISO).

## Requirements
- Linux VPS
- QEMU / KVM
- root privileges
- systemd

## Features
- Lightweight and minimal setup
- Supports custom ISO images
- Configurable CPU, RAM, and storage

## Installation
### Download the Installer
```bash
wget https://raw.githubusercontent.com/melovart/qvmctl/main/qvmctl.sh
chmod +x qvmctl.sh
```

## Usage
### Run the script
```bash
./qvmctl.sh
```

### Displays all available command lists
```bash
./qvmctl.sh --help
```

---

If you don't know how my script works, maybe you can watch my [video](https://youtu.be/s17swdiaCfw?si=Bv0ROriP_QxuU9QC) at YouTube
