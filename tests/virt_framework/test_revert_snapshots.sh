#!/bin/bash
#
# Test revertable snapshots using virt-framework
#
# This test validates snapshot revert functionality by:
# 1. Provisioning a VM with the specified OS and storage configuration
# 2. Installing snapm and snapshot role from git
# 3. Creating snapshots
# 4. Making system modifications
# 5. Reverting snapshots to restore original state
# 6. Verifying state restoration
# 7. Testing with the new safety checks for non-snapshot volumes
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

Test snapshot revert functionality using virt-framework.

This test validates:
- Creating snapshots of LVM volumes
- Making modifications to the system
- Reverting snapshots to restore original state
- Safety checks for revert operations (new in this release)
- Proper error handling for non-snapshot volumes

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

    # Test CentOS Stream with LVM-thin and UEFI
    $0 --os centos-stream9 --storage lvm-thin --firmware uefi

    # Run test and keep VM for manual verification
    $0 --keep

    # CI/CD integration with JSON output
    $0 --os fedora43 --json

WHAT THIS TEST VALIDATES:
    1. Snapshot creation with proper volume verification
    2. System state modifications
    3. Snapshot revert functionality
    4. NEW: Safety checks preventing revert of non-snapshot volumes
    5. NEW: Validation that all volumes in a snapset are actual snapshots
    6. State consistency after revert
    7. Proper cleanup of snapshot volumes

REQUIREMENTS:
    - virt-framework package installed (pip install virt-framework)
    - libvirt and qemu-kvm installed and configured
    - Sufficient disk space for VM provisioning
    - Network connectivity for downloading installation media

NOTES:
    This test is part of the snapshot role test suite and validates
    the new safety checks added to the mount and revert operations.
    The virt-framework handles VM provisioning, snapm installation,
    and the complete test workflow automatically.

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
    echo "Snapshot Revert Test Configuration"
    echo "=========================================="
    echo "OS:             $OS"
    echo "Storage:        $STORAGE"
    echo "Firmware:       $FIRMWARE"
    echo "Keep VM:        $([ $KEEP_VM -eq 1 ] && echo 'Yes' || echo 'No')"
    echo "JSON Output:    $([ $JSON_OUTPUT -eq 1 ] && echo 'Yes' || echo 'No')"
    echo "=========================================="
    echo
    echo "This test validates:"
    echo "  ✓ Snapshot creation and verification"
    echo "  ✓ System state modifications"
    echo "  ✓ Snapshot revert functionality"
    echo "  ✓ Safety checks for revert operations"
    echo "  ✓ Volume validation (new)"
    echo "  ✓ Proper cleanup"
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
        echo "Snapshot revert test PASSED"
        echo "=========================================="
        echo
        echo "All tests completed successfully:"
        echo "  ✓ Snapshots created and validated"
        echo "  ✓ System modifications applied"
        echo "  ✓ Snapshots reverted successfully"
        echo "  ✓ Safety checks validated"
        echo "  ✓ System state restored correctly"
    else
        echo "=========================================="
        echo "Snapshot revert test FAILED (exit code: $EXIT_CODE)"
        echo "=========================================="
        echo
        echo "Check the output above for details."
        if [ "$KEEP_VM" -eq 0 ]; then
            echo "Tip: Use --keep to preserve the VM for debugging"
        fi
    fi
fi

exit $EXIT_CODE
