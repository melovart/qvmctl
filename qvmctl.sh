#!/bin/bash
set -e

#
# DISCLAIMER:
# This script is provided "AS IS" without any warranties of any kind.
# You are fully responsible for any actions performed on your VPS.
# By running this script, you acknowledge that:
#   - You choose to execute it on your own decision.
#   - The author (melovart) is NOT responsible for any damage, data loss,
#     misconfiguration, downtime, or security issues that may occur.
#   - This script does NOT intentionally harm your system and only performs
#     operations exactly as written, including downloading files directly
#     from the official website.
#
# USE AT YOUR OWN RISK.
#
# PLEASE RUN THIS SCRIPT USING ROOT USER
#

# ========== GLOBAL CONSTANTS ==========
readonly INSTALLER_VERSION="1.0.0"

readonly ISO_NAME="vm.iso"
readonly IMG_NAME="vm.img"
readonly DRIVER_NAME="virtio.iso"

# ========== RUNTIME VARIABLES ==========
VM_PATH=""
ISO_URI=""
VM_CORE=""
VM_RAM=""
VM_STORAGE=""
# =======================================

installerPersonalization() {
	clear
	echo
	echo "   ██████╗ ██╗   ██╗███╗   ███╗ ██████╗████████╗██╗     "
	echo "  ██╔═══██╗██║   ██║████╗ ████║██╔════╝╚══██╔══╝██║     "
	echo "  ██║   ██║██║   ██║██╔████╔██║██║        ██║   ██║     "
	echo "  ██║▄▄ ██║╚██╗ ██╔╝██║╚██╔╝██║██║        ██║   ██║     "
	echo "  ╚██████╔╝ ╚████╔╝ ██║ ╚═╝ ██║╚██████╗   ██║   ███████╗"
	echo "   ╚══▀▀═╝   ╚═══╝  ╚═╝     ╚═╝ ╚═════╝   ╚═╝   ╚══════╝"
	echo
	echo "       Quick Virtual Machine Control - by melovart"
	echo "                      Version ${INSTALLER_VERSION}"
	echo
	echo
	echo
}

showInstallerVersion() {
	echo
	echo "   ██████╗ ██╗   ██╗███╗   ███╗ ██████╗████████╗██╗     "
	echo "  ██╔═══██╗██║   ██║████╗ ████║██╔════╝╚══██╔══╝██║     "
	echo "  ██║   ██║██║   ██║██╔████╔██║██║        ██║   ██║     "
	echo "  ██║▄▄ ██║╚██╗ ██╔╝██║╚██╔╝██║██║        ██║   ██║     "
	echo "  ╚██████╔╝ ╚████╔╝ ██║ ╚═╝ ██║╚██████╗   ██║   ███████╗"
	echo "   ╚══▀▀═╝   ╚═══╝  ╚═╝     ╚═╝ ╚═════╝   ╚═╝   ╚══════╝"
	echo
	echo "       Quick Virtual Machine Control - by melovart"
	echo "                      Version ${INSTALLER_VERSION}"
	echo
}

ShowHelpCommand() {
	installerPersonalization

	echo "Available args:"
	echo "-h, --help                       Display available args command"
	echo "-v, --version                    Check the qvmctl version"
	echo "-kvm-check                       Check whether your VPS supports KVM Virtualization"
	echo
}

ShowVncInfo() {
	clear
	installerPersonalization

	ipv4=$(curl -s https://api.ipify.org)

	echo "Virtual Machine Information"
	echo
	echo "• Connection"
	echo "├─ IPv4           : $ipv4"
	echo "├─ VNC Display    : 0"
	echo "└─ VNC Port       : 5900"
	echo
	echo "• Specifications"
	echo "├─ RAM            : $VM_RAM GB"
	echo "├─ CPU            : $VM_CORE Core"
	echo "└─ STORAGE        : $VM_STORAGE GB"
	echo
	echo "• VM Files"
	echo "├─ ISO Bootable   : ${VM_PATH}/${ISO_NAME}"
	echo "├─ Disk Image     : ${VM_PATH}/${IMG_NAME}"
	echo "└─ VirtIO Driver  : ${VM_PATH}/${DRIVER_NAME}"
	echo
	echo "• VM Service Status"
	systemctl is-active --quiet vm.service && \
		echo "└─ Status          : Running" || \
		echo "└─ Status          : Stopped"
	
	echo
	echo
	echo "Press CTRL+C to exit this screen"

	trap "echo; echo 'Bye...'; exit 0" SIGINT
	sleep infinity
}

CheckQemuDependencies() {
	echo
	echo "Checking required QEMU packages..."

	missing_packages=()

	if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
		missing_packages+=("qemu-system-x86")
	fi

	if ! command -v qemu-img >/dev/null 2>&1; then
		missing_packages+=("qemu-utils")
	fi

	if ! lsmod | grep -q kvm; then
		missing_packages+=("qemu-kvm (or KVM module not loaded)")
	fi

	if [ ${#missing_packages[@]} -eq 0 ]; then
		echo "All QEMU dependencies are installed"
		return 0
	else
		echo -e "${YELLOW}Missing dependencies:${RESET}"
		for pkg in "${missing_packages[@]}"; do
			echo " - $pkg"
		done
		return 1
	fi
}

projectVmPath() {
	echo "Where the VM resource will saved? default at /var/vm"

	while true; do
		read -p "Input a path (ex /var/vm): " vm_path

		if [ -z "$vm_path" ]; then
			echo "VM path set to /var/vm"
			VM_PATH="/var/vm"
			break
		fi

		VM_PATH="$vm_path"
		break
	done
}

isoUri() {
	echo
	echo "Input your ISO url (direct link)"

	while true; do
		read -p "ISO Url: " iso_uri

		if [ -z "$iso_uri" ]; then
			echo "ISO url cannot be empty"
			echo
			continue
		fi

		ISO_URI="$iso_uri"
		break
	done
}

setVmRam() {
	total_ram=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)+1}')

	echo
	echo "Your VPS have ${total_ram}GB RAM available, input number only"

	while true; do
		read -p "Set VM RAM (ex 4): " vm_ram

		if [ -z "$vm_ram" ]; then
			echo "Please set VM RAM"
			echo
			continue
		elif ! [[ "$vm_ram" =~ ^[0-9]+$ ]] || [ "$vm_ram" -le 0 ]; then
			echo "Invalid input, please input a positive number"
			echo
			continue
		elif [ "$vm_ram" -gt "$total_ram" ]; then
			echo "You cannot assign more RAM than available on VPS (${total_ram}GB)"
			echo
			continue
		else
			VM_RAM="$vm_ram"
			break
		fi
	done
}

setVmCpuCore() {
	total_core=$(nproc)

	echo
	echo "Your VPS CPU have ${total_core} Core available, input number only"

	while true; do
		read -p "Set VM CPU Core (ex 2): " vm_core

		if [ -z "$vm_core" ]; then
			echo "Please set VM CPU Core"
			echo
			continue
		elif ! [[ "$vm_core" =~ ^[0-9]+$ ]] || [ "$vm_core" -le 0 ]; then
			echo "Invalid input, please input a positive number"
			echo
			continue
		elif [ "$vm_core" -gt "$total_core" ]; then
			echo "You cannot assign more CPU cores than available on VPS (${total_core} Core)"
			echo
			continue
		else
			VM_CORE="$vm_core"
			break
		fi
	done
}

setVmStorage() {
	free_storage=$(df --output=avail -BG / | tail -1 | sed 's/G//')

	echo
	echo "Your VPS have ${free_storage}GB Storage available, input number only"

	while true; do
		read -p "Set VM Storage (ex 80): " vm_storage

		if [ -z "$vm_storage" ]; then
			echo "Please set VM Storage"
			echo
			continue
		elif ! [[ "$vm_storage" =~ ^[0-9]+$ ]] || [ "$vm_storage" -le 0 ]; then
			echo "Invalid input, please input a positive number"
			echo
			continue
		elif [ "$vm_storage" -gt "$free_storage" ]; then
			echo "You cannot assign more storage than available on your VPS (${free_storage}GB)"
			echo
			continue
		else
			VM_STORAGE="$vm_storage"
			break
		fi
	done
}

InstallationConfirm() {
    mkdir -p "$VM_PATH"

    if [ -f "${VM_PATH}/${ISO_NAME}" ]; then
        echo "ISO $ISO_NAME already exists! Skipping download..."
    else
        wget "$ISO_URI" -O "${VM_PATH}/${ISO_NAME}"
    fi

    if [ -f "${VM_PATH}/${IMG_NAME}" ]; then
        echo "Image $IMG_NAME already exists! Skipping creation..."
    else
        qemu-img create -f raw "${VM_PATH}/${IMG_NAME}" "${VM_STORAGE}G"
    fi

    if [ -f "${VM_PATH}/${DRIVER_NAME}" ]; then
        echo "Driver $DRIVER_NAME already exists! Skipping download..."
    else
        wget "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/virtio-win-0.1.285.iso" \
            -O "${VM_PATH}/${DRIVER_NAME}"
    fi

    clear
    installerPersonalization

    while true; do
        read -p "Do you want to create a systemctl for the VM as well? (Y/n): " sctl_option

        case $sctl_option in
            ""|y|Y)
                cat <<EOF > /etc/systemd/system/vm.service
[Unit]
Description=QEMU Virtual Machine
After=network.target

[Service]
Type=simple
User=root
Group=root

ExecStart=/usr/bin/qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp ${VM_CORE} \
    -m ${VM_RAM}G \
    -boot order=d \
    -drive file="${VM_PATH}/${ISO_NAME}",media=cdrom \
    -drive file="${VM_PATH}/${IMG_NAME}",format=raw,if=virtio \
    -drive file="${VM_PATH}/${DRIVER_NAME}",media=cdrom \
    -device usb-ehci,id=usb,bus=pci.0,addr=0x4 \
    -device usb-tablet \
    -audiodev none,id=noaudio \
    -vnc :0

Restart=always

[Install]
WantedBy=multi-user.target
EOF

                systemctl daemon-reload
                systemctl enable vm.service
                systemctl start vm.service

				ShowVncInfo

                break
                ;;
            n|N)
                echo "You canceled the creation of systemctl, you can run the VM manually."
                echo "Bye..."
                exit 1
                ;;
            *)
                echo "Please answer Y/N"
                echo
                ;;
        esac
    done
}

installationSummary() {
	clear
	installerPersonalization

	echo "Your VM Installation Summary, please check again before proceed this installation"
	echo
	echo "• URI"
	echo "└─ ISO Url      : $ISO_URI"
	echo
	echo "• Path Directory"
	echo "├─ VM Path      : $VM_PATH"
	echo "├─ ISO File     : ${VM_PATH}/${ISO_NAME}"
	echo "├─ Disk File    : ${VM_PATH}/${IMG_NAME}"
	echo "└─ Driver File  : ${VM_PATH}/${DRIVER_NAME}"
	echo
	echo "• VM Specifications"
	echo "├─ VM RAM       : $VM_RAM GB"
	echo "├─ VM CPU       : $VM_CORE Core"
	echo "└─ VM STORAGE   : $VM_STORAGE GB"

	echo
	while true; do
		read -p "Is everything as you want it? Continue to Installation step? (Y/n): " is_ok

		case $is_ok in
			""|y|Y)
				clear
				installerPersonalization

				if CheckQemuDependencies; then
					echo "Dependencies OK, continuing installation..."
					InstallationConfirm
				else
					echo
					echo "Some dependencies are missing."
					read -p "Install missing packages now? This operation will terminate if you select No (Y/n): " install_now

					case $install_now in
						""|y|Y)
							echo "Installing dependencies..."
							apt update
							apt install -y qemu-system-x86 qemu-utils qemu-kvm

							InstallationConfirm
							break
							;;
						*)
							echo "Cannot continue without required packages."
							exit 1
							;;
					esac
				fi
				break
				;;
			n|N)
				clear
				installerPersonalization

				echo "What would you like to change?"
				echo "1. The ISO Url (direct link)"
				echo "2. VM Directory Path"
				echo "3. VM RAM Size"
				echo "4. VM CPU Core"
				echo "5. VM Storage Size"
				echo "6. Cancel the VM creation"
				echo "0. Back to the Installation Summary"
				echo

				while true; do
					read -p "Select the Menu (0-6): " menu_edit

					case $menu_edit in
						0)
							installationSummary
							break
							;;
						1)
							clear
							installerPersonalization

							echo "You're wanted to change the ISO Url from the VM Installation"
							echo "Your current ISO Url: $ISO_URI"
							echo

							while true; do
								read -p "Update your ISO Url (direct link): " iso_uri

								if [ -z "$iso_uri" ]; then
									echo "ISO url cannot be empty"
									echo
									continue
								fi

								ISO_URI="$iso_uri"
								break
							done

							installationSummary
							break
							;;
						2)
							clear
							installerPersonalization

							echo "You're wanted to change the VM Directory Path from the VM Installation"
							echo "Your current VM Directory: $VM_PATH"
							echo

							while true; do
								read -p "Input a path (ex /var/vm): " vm_path

								if [ -z "$vm_path" ]; then
									echo "VM Directory cannot be empty"
									echo
									continue
								fi

								VM_PATH="$vm_path"
								break
							done

							installationSummary
							break
							;;
						3)
							clear
							installerPersonalization

							total_ram=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)+1}')

							echo "You're wanted to change the VM RAM Size from the VM Installation"
							echo "Your VPS have ${total_ram}GB RAM available, input number only"
							echo "Your current VM RAM Size: $VM_RAM GB"
							echo

							while true; do
								read -p "Set VM RAM (ex 4): " vm_ram

								if [ -z "$vm_ram" ]; then
									echo "Please set VM RAM"
									echo
									continue
								elif ! [[ "$vm_ram" =~ ^[0-9]+$ ]] || [ "$vm_ram" -le 0 ]; then
									echo "Invalid input, please input a positive number"
									echo
									continue
								elif [ "$vm_ram" -gt "$total_ram" ]; then
									echo "You cannot assign more RAM than available on VPS (${total_ram}GB)"
									echo
									continue
								else
									VM_RAM="$vm_ram"
									break
								fi
							done

							installationSummary
							break
							;;
						4)
							clear
							installerPersonalization

							total_core=$(nproc)

							echo "You're wanted to change the VM CPU Core from the VM Installation"
							echo "Your VPS CPU have ${total_core} Core available, input number only"
							echo "Your current VM CPU: $VM_CORE Core"
							echo

							while true; do
								read -p "Set VM CPU Core (ex 2): " vm_core

								if [ -z "$vm_core" ]; then
									echo "Please set VM CPU Core"
									echo
									continue
								elif ! [[ "$vm_core" =~ ^[0-9]+$ ]] || [ "$vm_core" -le 0 ]; then
									echo "Invalid input, please input a positive number"
									echo
									continue
								elif [ "$vm_core" -gt "$total_core" ]; then
									echo "You cannot assign more CPU cores than available on VPS (${total_core} Core)"
									echo
									continue
								else
									VM_CORE="$vm_core"
									break
								fi
							done

							installationSummary
							break
							;;
						5)
							clear
							installerPersonalization

							free_storage=$(df --output=avail -BG / | tail -1 | sed 's/G//')

							echo "You're wanted to change the VM Storage Size from the VM Installation"
							echo "Your VPS have ${free_storage}GB Storage available, input number only"
							echo "Your current VM Storage Size: $VM_STORAGE GB"
							echo

							while true; do
								read -p "Set VM Storage (ex 80): " vm_storage

								if [ -z "$vm_storage" ]; then
									echo "Please set VM Storage"
									echo
									continue
								elif ! [[ "$vm_storage" =~ ^[0-9]+$ ]] || [ "$vm_storage" -le 0 ]; then
									echo "Invalid input, please input a positive number"
									echo
									continue
								elif [ "$vm_storage" -gt "$free_storage" ]; then
									echo "You cannot assign more storage than available on your VPS (${free_storage}GB)"
									echo
									continue
								else
									VM_STORAGE="$vm_storage"
									break
								fi
							done

							installationSummary
							break
							;;
						6)
							echo
							echo "Bye..."
							echo
							exit 0
							
							break
							;;
						*)
							echo "Invalid option, please choose 0-5."
							;;
					esac
				done
				;;
			*)
				echo "Please answer using Y/N"
				echo
				continue
				;;
		esac
	done
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help)
			ShowHelpCommand
			exit 0
			;;
		-v|--version)
			showInstallerVersion
			exit 0
			;;
		-kvm-check)
			if ! grep -E -q '(vmx|svm)' /proc/cpuinfo; then
				echo "CPU virtualization is NOT Supported"
			else
				echo "CPU virtualization is Supported"
			fi

			if [ ! -e /dev/kvm ]; then
				echo "KVM is NOT Available on this VPS"
				echo "This VPS is likely OpenVZ / LXC / no-nested-virt"
				echo
			else
				echo "KVM is Available on this VPS"
				echo
			fi
			
			exit 0
			;;
		*)
			echo "Unknown option: $1"
			exit 1
			;;
	esac
	shift
done

installerPersonalization
projectVmPath
isoUri
setVmRam
setVmCpuCore
setVmStorage
installationSummary
