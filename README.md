# Windows Gaming VM for macOS

This repository provides a starter workflow for creating a Windows desktop virtual machine on Apple Silicon Macs, including M1 and M4 Pro machines, for game streaming, launchers, and lightweight/compatible PC games.

> **Licensing note:** this project does not bypass Windows licensing, paid game ownership, or anti-cheat restrictions. The user must provide a legitimate Windows ISO and comply with Microsoft and game publisher terms. If the user is eligible for a free evaluation, trial, education, or existing license, they can use that; otherwise Windows may require activation.

## What this creates

- A Windows VM with a normal desktop experience.
- A QEMU launch script focused on Apple Silicon Macs, with an Intel fallback.
- A persistent virtual disk for Windows installation.
- Optional VirtIO driver ISO attachment for better storage/network/display drivers.

## What this cannot guarantee

- GPU passthrough on macOS hosts. Most modern games need GPU acceleration, and macOS virtualization limits direct Windows GPU access.
- Compatibility with kernel-level anti-cheat systems.
- Free Windows activation. You must use a license, entitlement, or evaluation that you are allowed to use.

## Prerequisites

Install QEMU on each Mac:

```bash
brew install qemu
```

Download the correct Windows ISO for your Mac CPU:

- M1 and M4 Pro Macs: use an ARM64 Windows ISO.
- Intel Mac: use an x64 Windows ISO.

Optionally download VirtIO drivers and provide the ISO path when launching. QEMU user-mode networking is enabled by default, so Windows should have outbound internet access after its network driver is installed.

## Quick start

Create and boot a VM installer on each Apple Silicon Mac:

```bash
./scripts/create-windows-gaming-vm.sh \
  --name windows-gaming \
  --windows-iso /path/to/windows.iso \
  --disk-size 128G \
  --memory 8G \
  --cpus 6 \
  --rdp-port 33890
```

With VirtIO drivers attached:

```bash
./scripts/create-windows-gaming-vm.sh \
  --name windows-gaming \
  --windows-iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --disk-size 128G \
  --memory 8G \
  --cpus 6 \
  --rdp-port 33890
```

After Windows is installed, boot from the virtual disk without the installer ISO. If you enable Remote Desktop in Windows, connect from macOS to `127.0.0.1:33890`:

```bash
./scripts/create-windows-gaming-vm.sh \
  --name windows-gaming \
  --boot-installed \
  --memory 8G \
  --cpus 6 \
  --rdp-port 33890
```

## Gaming recommendations

For the best experience on macOS, consider using the Windows VM as a desktop for:

- Game launchers and older/lighter games.
- Streaming from a cloud PC or another gaming PC.
- Mod managers, save editors, or Windows-only companion tools.

For demanding titles, native macOS ports, CrossOver/Game Porting Toolkit, cloud gaming, or a dedicated Windows PC may perform better than a VM. On M1 and M4 Pro Macs, expect the VM to be best for Windows desktop access, launchers, streaming clients, and less demanding games rather than GPU-heavy multiplayer games.
