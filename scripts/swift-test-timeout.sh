#!/usr/bin/env bash

set -uo pipefail

default_timeout_seconds=30
max_timeout_seconds=120

print_usage() {
    cat >&2 <<'USAGE'
Usage: scripts/swift-test-timeout.sh [timeout-seconds] [--] [swift test arguments...]

The timeout must be an integer from 1 through 120 seconds. The default is 30.
USAGE
}

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

print_failure_diagnostics() {
    local reason="$1"

    {
        echo "DIAGNOSTICS: $reason"
        echo "DIAGNOSTICS: working directory: $PWD"
        echo "DIAGNOSTICS: active Swift-related processes:"
        ps -axo pid=,ppid=,stat=,command= | awk '/swift|swiftpm-testing-helper/ { print }'
        if [ -e ".build/.lock" ]; then
            echo "DIAGNOSTICS: .build/.lock exists"
        else
            echo "DIAGNOSTICS: .build/.lock is absent"
        fi
    } >&2
}

timeout_seconds="$default_timeout_seconds"
if [ "$#" -gt 0 ] && [ "${1#-}" != "$1" ]; then
    print_usage
    exit 2
fi
if [ "$#" -gt 0 ] && [ "$1" != "--" ]; then
    timeout_seconds="$1"
    shift
fi
if [ "${1:-}" = "--" ]; then
    shift
fi

if ! is_positive_integer "$timeout_seconds" || [ "$timeout_seconds" -gt "$max_timeout_seconds" ]; then
    echo "ERROR: timeout must be an integer from 1 through $max_timeout_seconds seconds" >&2
    exit 2
fi

swift test "$@" &
test_pid=$!
deadline=$((SECONDS + timeout_seconds))
timed_out=0

cleanup_child() {
    if kill -0 "$test_pid" 2>/dev/null; then
        kill -TERM "$test_pid" 2>/dev/null || true
    fi
}
trap cleanup_child INT TERM

while kill -0 "$test_pid" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
        timed_out=1
        kill -TERM "$test_pid" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            if ! kill -0 "$test_pid" 2>/dev/null; then
                break
            fi
            sleep 0.2
        done
        if kill -0 "$test_pid" 2>/dev/null; then
            kill -KILL "$test_pid" 2>/dev/null || true
        fi
        break
    fi
    sleep 0.2
done

if wait "$test_pid"; then
    test_status=0
else
    test_status=$?
fi
trap - INT TERM

if [ "$timed_out" -eq 1 ]; then
    print_failure_diagnostics "swift test exceeded ${timeout_seconds}-second timeout"
    exit 124
fi

if [ "$test_status" -ne 0 ]; then
    print_failure_diagnostics "swift test exited with status $test_status"
    exit "$test_status"
fi

exit 0
