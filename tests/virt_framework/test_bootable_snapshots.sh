#!/bin/bash
#
# Test bootable snapshots using virt-framework
#
# This test validates bootable snapshot functionality by:
# 1. Provisioning a VM with the specified OS and storage configuration
# 2. Installing snapm and snapshot role from git
# 3. Creating bootable snapshots
# 4. Verifying snapshot boot entries
# 5. Booting into snapshots
# 6. Validating system state
# 7. Testing rollback functionality
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OS="fedora42"
DEFAULT_STORAGE="lvm"
DEFAULT_FIRMWARE="bios"
KEEP_VM=0
JSON_OUTPUT=0
ALLOW_ROOT=0

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Test bootable snapshots using virt-framework.

OPTIONS:
    -o, --os OS             Operating system to test (default: $DEFAULT_OS)
                           Options: fedora42, fedora43, centos-stream9, centos-stream10
    -s, --storage TYPE      Storage configuration (default: $DEFAULT_STORAGE)
                           Options: lvm, lvm-thin
    -f, --firmware TYPE     Firmware mode (default: $DEFAULT_FIRMWARE)
                           Options: bios, uefi
    -k, --keep             Keep VM running after tests
    -j, --json             Output results in JSON format
    -r, --allow-root       Allow running as root user
    -h, --help             Show this help message

EXAMPLES:
    # Test with default configuration (Fedora 42, LVM, BIOS)
    $0

    # Test Fedora 43 with UEFI and LVM-thin
    $0 --os fedora43 --firmware uefi --storage lvm-thin

    # Test CentOS Stream 9 and keep VM for debugging
    $0 --os centos-stream9 --keep

    # Run with JSON output for CI/CD integration
    $0 --os fedora42 --json

REQUIREMENTS:
    - virt-framework package installed (pip install virt-framework)
    - libvirt and qemu-kvm installed and configured
    - Sufficient disk space for VM provisioning
    - Network connectivity for downloading installation media

EOF
    exit 1
}

# Parse command-line arguments
OS="$DEFAULT_OS"
STORAGE="$DEFAULT_STORAGE"
FIRMWARE="$DEFAULT_FIRMWARE"

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--os)
            OS="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE="$2"
            shift 2
            ;;
        -f|--firmware)
            FIRMWARE="$2"
            shift 2
            ;;
        -k|--keep)
            KEEP_VM=1
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=1
            shift
            ;;
        -r|--allow-root)
            ALLOW_ROOT=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate OS choice
case "$OS" in
    fedora42|fedora43|centos-stream9|centos-stream10)
        ;;
    *)
        echo "Error: Invalid OS '$OS'"
        echo "Valid options: fedora42, fedora43, centos-stream9, centos-stream10"
        exit 1
        ;;
esac

# Validate storage type
case "$STORAGE" in
    lvm|lvm-thin)
        ;;
    *)
        echo "Error: Invalid storage type '$STORAGE'"
        echo "Valid options: lvm, lvm-thin"
        exit 1
        ;;
esac

# Validate firmware mode
case "$FIRMWARE" in
    bios|uefi)
        ;;
    *)
        echo "Error: Invalid firmware '$FIRMWARE'"
        echo "Valid options: bios, uefi"
        exit 1
        ;;
esac

# Check for virt-framework installation
if ! command -v virt-framework &> /dev/null; then
    echo "Error: virt-framework is not installed"
    echo "Install it with: pip install virt-framework"
    exit 1
fi

# Build virt-framework command
VIRT_CMD="virt-framework"
VIRT_ARGS=()

# Add firmware flag
if [ "$FIRMWARE" = "uefi" ]; then
    VIRT_ARGS+=(--uefi)
else
    VIRT_ARGS+=(--bios)
fi

# Add storage configuration
VIRT_ARGS+=(--storage "$STORAGE")

# Add keep flag if requested
if [ "$KEEP_VM" -eq 1 ]; then
    VIRT_ARGS+=(--keep)
fi

# Add JSON output flag if requested
if [ "$JSON_OUTPUT" -eq 1 ]; then
    VIRT_ARGS+=(--json)
fi

# Add allow-root flag if requested
if [ "$ALLOW_ROOT" -eq 1 ]; then
    VIRT_ARGS+=(--allow-root)
fi

# Add the OS
VIRT_ARGS+=("$OS")

# Print test configuration
if [ "$JSON_OUTPUT" -eq 0 ]; then
    echo "=========================================="
    echo "Bootable Snapshot Test Configuration"
    echo "=========================================="
    echo "OS:             $OS"
    echo "Storage:        $STORAGE"
    echo "Firmware:       $FIRMWARE"
    echo "Keep VM:        $([ $KEEP_VM -eq 1 ] && echo 'Yes' || echo 'No')"
    echo "JSON Output:    $([ $JSON_OUTPUT -eq 1 ] && echo 'Yes' || echo 'No')"
    echo "=========================================="
    echo
    echo "Running: $VIRT_CMD ${VIRT_ARGS[*]}"
    echo
fi

# Run virt-framework
"$VIRT_CMD" "${VIRT_ARGS[@]}"

# Capture exit code
EXIT_CODE=$?

if [ "$JSON_OUTPUT" -eq 0 ]; then
    echo
    if [ $EXIT_CODE -eq 0 ]; then
        echo "=========================================="
        echo "Bootable snapshot test PASSED"
        echo "=========================================="
    else
        echo "=========================================="
        echo "Bootable snapshot test FAILED (exit code: $EXIT_CODE)"
        echo "=========================================="
    fi
fi

exit $EXIT_CODE
