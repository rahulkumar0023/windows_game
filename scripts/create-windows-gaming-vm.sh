#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Create or boot a Windows desktop VM for macOS gaming experiments.

Required for first boot:
  --windows-iso PATH      Path to a legitimate Windows installer ISO.

Options:
  --name NAME             VM name and directory under ./vms (default: windows-gaming)
  --disk-size SIZE        qemu-img disk size for first creation (default: 128G)
  --memory SIZE           VM memory, for example 8G (default: 8G)
  --cpus COUNT            vCPU count (default: host CPU count up to QEMU default if unknown)
  --virtio-iso PATH       Optional VirtIO driver ISO path.
  --uefi-code PATH        Optional ARM UEFI firmware code file override.
  --uefi-vars PATH        Optional ARM UEFI vars template override.
  --rdp-port PORT         Forward host localhost:PORT to guest RDP 3389 (default: 33890).
  --boot-installed        Boot existing VM disk without attaching Windows installer ISO.
  --help                  Show this help.

Examples:
  ./scripts/create-windows-gaming-vm.sh --windows-iso ~/Downloads/windows.iso
  ./scripts/create-windows-gaming-vm.sh --boot-installed
USAGE
}

name="windows-gaming"
disk_size="128G"
memory="8G"
cpus="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
windows_iso=""
virtio_iso=""
uefi_code=""
uefi_vars_template=""
rdp_port="33890"
boot_installed=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="${2:?Missing value for --name}"; shift 2 ;;
    --disk-size) disk_size="${2:?Missing value for --disk-size}"; shift 2 ;;
    --memory) memory="${2:?Missing value for --memory}"; shift 2 ;;
    --cpus) cpus="${2:?Missing value for --cpus}"; shift 2 ;;
    --windows-iso) windows_iso="${2:?Missing value for --windows-iso}"; shift 2 ;;
    --virtio-iso) virtio_iso="${2:?Missing value for --virtio-iso}"; shift 2 ;;
    --uefi-code) uefi_code="${2:?Missing value for --uefi-code}"; shift 2 ;;
    --uefi-vars) uefi_vars_template="${2:?Missing value for --uefi-vars}"; shift 2 ;;
    --rdp-port) rdp_port="${2:?Missing value for --rdp-port}"; shift 2 ;;
    --boot-installed) boot_installed=true; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! command -v qemu-img >/dev/null; then
  echo "qemu-img is required. Install QEMU with: brew install qemu" >&2
  exit 1
fi

if ! command -v qemu-system-aarch64 >/dev/null && ! command -v qemu-system-x86_64 >/dev/null; then
  echo "A QEMU system emulator is required. Install QEMU with: brew install qemu" >&2
  exit 1
fi

if [[ "$boot_installed" == false && -z "$windows_iso" ]]; then
  echo "--windows-iso is required unless --boot-installed is set." >&2
  exit 2
fi

if [[ -n "$windows_iso" && ! -f "$windows_iso" ]]; then
  echo "Windows ISO not found: $windows_iso" >&2
  exit 1
fi

if [[ -n "$virtio_iso" && ! -f "$virtio_iso" ]]; then
  echo "VirtIO ISO not found: $virtio_iso" >&2
  exit 1
fi

if ! [[ "$rdp_port" =~ ^[0-9]+$ ]] || (( rdp_port < 1 || rdp_port > 65535 )); then
  echo "--rdp-port must be a TCP port between 1 and 65535." >&2
  exit 2
fi

vm_dir="vms/$name"
disk="$vm_dir/windows.qcow2"
uefi_vars="$vm_dir/uefi-vars.fd"
mkdir -p "$vm_dir"

if [[ ! -f "$disk" ]]; then
  qemu-img create -f qcow2 "$disk" "$disk_size"
fi

arch="$(uname -m)"
extra_drives=()
boot_order="c"

if [[ "$boot_installed" == false ]]; then
  extra_drives+=( -drive "file=$windows_iso,media=cdrom,readonly=on" )
  boot_order="d"
fi

if [[ -n "$virtio_iso" ]]; then
  extra_drives+=( -drive "file=$virtio_iso,media=cdrom,readonly=on" )
fi

netdev="user,id=net0,hostfwd=tcp:127.0.0.1:${rdp_port}-:3389"

find_first_existing() {
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if [[ "$arch" == "arm64" || "$arch" == "aarch64" ]]; then
  qemu_system="qemu-system-aarch64"

  if [[ -z "$uefi_code" ]]; then
    uefi_code="$(find_first_existing \
      /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
      /usr/local/share/qemu/edk2-aarch64-code.fd || true)"
  fi

  if [[ -z "$uefi_vars_template" ]]; then
    uefi_vars_template="$(find_first_existing \
      /opt/homebrew/share/qemu/edk2-aarch64-vars.fd \
      /usr/local/share/qemu/edk2-aarch64-vars.fd || true)"
  fi

  if [[ -z "$uefi_code" || ! -f "$uefi_code" ]]; then
    echo "ARM UEFI firmware was not found. Pass --uefi-code PATH or install QEMU with Homebrew." >&2
    exit 1
  fi

  if [[ ! -f "$uefi_vars" ]]; then
    if [[ -z "$uefi_vars_template" || ! -f "$uefi_vars_template" ]]; then
      echo "ARM UEFI vars template was not found. Pass --uefi-vars PATH or install QEMU with Homebrew." >&2
      exit 1
    fi
    cp "$uefi_vars_template" "$uefi_vars"
  fi

  exec "$qemu_system" \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -drive "if=pflash,format=raw,readonly=on,file=$uefi_code" \
    -drive "if=pflash,format=raw,file=$uefi_vars" \
    -smp "$cpus" \
    -m "$memory" \
    -device ramfb \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -drive "if=virtio,file=$disk,format=qcow2" \
    "${extra_drives[@]}" \
    -netdev "$netdev" \
    -device virtio-net-device,netdev=net0 \
    -boot order="$boot_order" \
    -display cocoa,show-cursor=on
else
  qemu_system="qemu-system-x86_64"
  exec "$qemu_system" \
    -accel hvf \
    -cpu host \
    -smp "$cpus" \
    -m "$memory" \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -drive "if=virtio,file=$disk,format=qcow2" \
    "${extra_drives[@]}" \
    -netdev "$netdev" \
    -device virtio-net-pci,netdev=net0 \
    -boot order="$boot_order" \
    -display cocoa,show-cursor=on
fi
