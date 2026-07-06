#!/bin/bash
#
# Run all virt-framework tests
#
# This script runs both bootable and revert snapshot tests with
# the specified configuration.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
DEFAULT_OS="fedora42"
DEFAULT_STORAGE="lvm"
DEFAULT_FIRMWARE="bios"
KEEP_VM=0
JSON_OUTPUT=0
RUN_BOOTABLE=1
RUN_REVERT=1

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Run all virt-framework integration tests.

OPTIONS:
    -o, --os OS             Operating system to test (default: $DEFAULT_OS)
    -s, --storage TYPE      Storage configuration (default: $DEFAULT_STORAGE)
    -f, --firmware TYPE     Firmware mode (default: $DEFAULT_FIRMWARE)
    -b, --bootable-only     Run only bootable snapshot tests
    -r, --revert-only       Run only revert snapshot tests
    -k, --keep             Keep VM running after tests
    -j, --json             Output results in JSON format
    -h, --help             Show this help message

EXAMPLES:
    # Run all tests with default configuration
    $0

    # Run only revert tests on CentOS Stream 9
    $0 --revert-only --os centos-stream9

    # Run all tests with UEFI and LVM-thin
    $0 --firmware uefi --storage lvm-thin

EOF
    exit 1
}

# Parse arguments
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
        -b|--bootable-only)
            RUN_REVERT=0
            shift
            ;;
        -r|--revert-only)
            RUN_BOOTABLE=0
            shift
            ;;
        -k|--keep)
            KEEP_VM=1
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=1
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

# Build common arguments
COMMON_ARGS=(--os "$OS" --storage "$STORAGE" --firmware "$FIRMWARE")

if [ "$KEEP_VM" -eq 1 ]; then
    COMMON_ARGS+=(--keep)
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
    COMMON_ARGS+=(--json)
fi

# Track results
BOOTABLE_RESULT=0
REVERT_RESULT=0

# Run bootable tests
if [ "$RUN_BOOTABLE" -eq 1 ]; then
    echo "=========================================="
    echo "Running Bootable Snapshot Tests"
    echo "=========================================="
    if "$SCRIPT_DIR/test_bootable_snapshots.sh" "${COMMON_ARGS[@]}"; then
        echo "✓ Bootable snapshot tests PASSED"
        BOOTABLE_RESULT=0
    else
        echo "✗ Bootable snapshot tests FAILED"
        BOOTABLE_RESULT=1
    fi
    echo
fi

# Run revert tests
if [ "$RUN_REVERT" -eq 1 ]; then
    echo "=========================================="
    echo "Running Snapshot Revert Tests"
    echo "=========================================="
    if "$SCRIPT_DIR/test_revert_snapshots.sh" "${COMMON_ARGS[@]}"; then
        echo "✓ Snapshot revert tests PASSED"
        REVERT_RESULT=0
    else
        echo "✗ Snapshot revert tests FAILED"
        REVERT_RESULT=1
    fi
    echo
fi

# Summary
if [ "$JSON_OUTPUT" -eq 0 ]; then
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="

    if [ "$RUN_BOOTABLE" -eq 1 ]; then
        if [ "$BOOTABLE_RESULT" -eq 0 ]; then
            echo "✓ Bootable snapshot tests: PASSED"
        else
            echo "✗ Bootable snapshot tests: FAILED"
        fi
    fi

    if [ "$RUN_REVERT" -eq 1 ]; then
        if [ "$REVERT_RESULT" -eq 0 ]; then
            echo "✓ Snapshot revert tests: PASSED"
        else
            echo "✗ Snapshot revert tests: FAILED"
        fi
    fi

    echo "=========================================="
fi

# Exit with failure if any test failed
if [ "$BOOTABLE_RESULT" -ne 0 ] || [ "$REVERT_RESULT" -ne 0 ]; then
    exit 1
fi

exit 0
