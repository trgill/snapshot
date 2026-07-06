# Virt-Framework Integration Tests

This directory contains integration tests for the snapshot role using [virt-framework](https://github.com/trgill/virt-framework), a VM-based end-to-end testing tool.

## Overview

Virt-framework automates the complete testing lifecycle by:
1. Provisioning a VM using libvirt/qemu with kickstart automation
2. Installing snapm (Snapshot Manager) and the snapshot role from git
3. Running comprehensive tests for snapshot operations
4. Validating bootable snapshots and revert functionality
5. Verifying the new safety checks for mount and revert operations

## Prerequisites

### System Requirements

- **libvirt** and **qemu-kvm** installed and configured
- **virtinst** (virt-install command)
- **libosinfo-bin** for OS information
- **BIOS firmware**: seabios
- **UEFI firmware**: ovmf
- Python 3.9 or later
- Sufficient disk space (10-20GB per VM)
- Network connectivity for downloading installation media

### Installation

#### Install virt-framework

```bash
# From PyPI (when available)
pip install virt-framework

# From source
git clone https://github.com/trgill/virt-framework.git
pip install ./virt-framework
```

#### Install system dependencies

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install -y \
    libvirt-daemon-kvm \
    libvirt-daemon-config-network \
    libvirt-client \
    qemu-kvm \
    virt-install \
    libosinfo \
    seabios \
    edk2-ovmf \
    wget \
    expect
```

**Debian/Ubuntu:**
```bash
sudo apt-get install -y \
    libvirt-daemon-system \
    libvirt-clients \
    qemu-kvm \
    virtinst \
    libosinfo-bin \
    seabios \
    ovmf \
    wget \
    expect
```

#### Configure libvirt

```bash
# Start and enable libvirt
sudo systemctl enable --now libvirtd

# Add your user to the libvirt group (optional, to avoid sudo)
sudo usermod -a -G libvirt $USER
newgrp libvirt
```

## Available Tests

### 1. Bootable Snapshot Tests

Tests the creation and boot functionality of bootable snapshots.

```bash
./test_bootable_snapshots.sh [OPTIONS]
```

**What it validates:**
- Creation of bootable snapshots
- Boot entry generation
- Booting into snapshots
- System state preservation
- Rollback to updated system

**Example usage:**
```bash
# Basic test with default configuration (Fedora 42, LVM, BIOS)
./test_bootable_snapshots.sh

# Test with UEFI firmware and LVM-thin
./test_bootable_snapshots.sh --firmware uefi --storage lvm-thin

# Test CentOS Stream 9 and keep VM for debugging
./test_bootable_snapshots.sh --os centos-stream9 --keep
```

### 2. Snapshot Revert Tests

Tests snapshot revert functionality and the new safety checks.

```bash
./test_revert_snapshots.sh [OPTIONS]
```

**What it validates:**
- Snapshot creation and verification
- System state modifications
- **NEW:** Safety checks preventing revert of non-snapshot volumes
- **NEW:** Validation that all volumes in a snapset are actual snapshots
- Snapshot revert to restore original state
- State consistency after revert

**Example usage:**
```bash
# Basic revert test
./test_revert_snapshots.sh

# Test with specific OS and configuration
./test_revert_snapshots.sh --os fedora43 --storage lvm-thin

# Run with JSON output for CI/CD
./test_revert_snapshots.sh --json
```

## Common Options

Both test scripts support the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --os OS` | Operating system to test | `fedora42` |
| `-s, --storage TYPE` | Storage configuration (`lvm` or `lvm-thin`) | `lvm` |
| `-f, --firmware TYPE` | Firmware mode (`bios` or `uefi`) | `bios` |
| `-k, --keep` | Keep VM running after tests | (disabled) |
| `-j, --json` | Output results in JSON format | (disabled) |
| `-r, --allow-root` | Allow running as root user | (disabled) |
| `-h, --help` | Show help message | - |

### Supported Operating Systems

- `fedora42` - Fedora 42
- `fedora43` - Fedora 43
- `centos-stream9` - CentOS Stream 9
- `centos-stream10` - CentOS Stream 10

## Test Workflow

The virt-framework executes an 11-step test workflow:

1. **System Verification** - Validate VM configuration and LVM setup
2. **Baseline Creation** - Establish initial system state
3. **Snapshot Creation** - Create snapshots with safety validation
4. **System Mutation** - Make modifications to test state changes
5. **Snapshot Verification** - Verify snapshot integrity
6. **Boot Testing** - Test booting into snapshots (bootable tests only)
7. **State Validation** - Confirm system state in snapshot
8. **Return to Updated** - Boot back to modified system
9. **Rollback Initiation** - Begin revert process
10. **Revert Validation** - Verify revert completed successfully
11. **Final State Check** - Confirm original state restored

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Virt-Framework Tests

on: [push, pull_request]

jobs:
  test-bootable:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libvirt-daemon-system qemu-kvm virtinst
          pip install virt-framework
      
      - name: Run bootable snapshot tests
        run: |
          cd tests/virt_framework
          sudo ./test_bootable_snapshots.sh --json --os fedora42

  test-revert:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libvirt-daemon-system qemu-kvm virtinst
          pip install virt-framework
      
      - name: Run revert snapshot tests
        run: |
          cd tests/virt_framework
          sudo ./test_revert_snapshots.sh --json --os fedora42
```

## Troubleshooting

### VM Provisioning Fails

**Issue:** VM fails to start or provision

**Solutions:**
- Check libvirt is running: `sudo systemctl status libvirtd`
- Verify nested virtualization is enabled (for cloud VMs): `cat /sys/module/kvm_*/parameters/nested`
- Ensure sufficient disk space: `df -h`
- Check network connectivity for downloading ISO images

### Tests Hang or Timeout

**Issue:** Tests appear to hang

**Solutions:**
- Use `--keep` to preserve the VM and investigate manually
- Check VM console: `virsh console <vm-name>`
- Review libvirt logs: `sudo journalctl -u libvirtd`

### Permission Errors

**Issue:** Permission denied errors when running tests

**Solutions:**
- Add user to libvirt group: `sudo usermod -a -G libvirt $USER && newgrp libvirt`
- Or run with sudo: `sudo ./test_bootable_snapshots.sh --allow-root`

### Snapshot Safety Check Failures

**Issue:** New safety checks fail in tests

**Expected behavior:** These failures validate the new safety checks are working correctly. The tests should:
- Successfully create snapshots
- Fail when attempting to mount/revert non-snapshot volumes
- Provide clear error messages

## Test Matrix

For comprehensive coverage, run tests across multiple configurations:

```bash
# Test matrix example
for os in fedora42 fedora43 centos-stream9; do
  for storage in lvm lvm-thin; do
    for firmware in bios uefi; do
      echo "Testing: $os with $storage on $firmware"
      ./test_bootable_snapshots.sh --os "$os" --storage "$storage" --firmware "$firmware"
    done
  done
done
```

## Additional Resources

- [virt-framework repository](https://github.com/trgill/virt-framework)
- [Snapshot Manager (snapm)](https://github.com/snapshotmanager/snapm)
- [libvirt documentation](https://libvirt.org/docs.html)
- [Snapshot role documentation](../../README.md)

## Contributing

When adding new tests:
1. Follow the existing script structure
2. Add comprehensive help documentation
3. Include example usage
4. Update this README with the new test
5. Test across multiple OS configurations

## License

These tests are part of the snapshot role project and follow the same license.
