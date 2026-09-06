#!/usr/bin/env bash

set -uo pipefail

default_repeats=3
default_timeout_seconds=30
max_timeout_seconds=120
default_build_timeout_seconds=120

print_usage() {
    cat >&2 <<'USAGE'
Usage: scripts/swift-test-hang-guard.sh [options] [--] [swift test arguments...]

Options:
  --repeats N          Number of guarded runs (default: 3)
  --timeout N          Warm-run timeout in seconds, 1-120 (default: 30)
  --build-timeout N    First-run timeout in seconds, 1-120 (default: 120)
USAGE
}

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

validate_timeout() {
    local label="$1"
    local value="$2"

    if ! is_positive_integer "$value" || [ "$value" -gt "$max_timeout_seconds" ]; then
        echo "ERROR: $label must be an integer from 1 through $max_timeout_seconds seconds" >&2
        exit 2
    fi
}

repeats="$default_repeats"
timeout_seconds="$default_timeout_seconds"
build_timeout_seconds="$default_build_timeout_seconds"
test_arguments=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repeats)
            [ "$#" -ge 2 ] || { print_usage; exit 2; }
            repeats="$2"
            shift 2
            ;;
        --timeout)
            [ "$#" -ge 2 ] || { print_usage; exit 2; }
            timeout_seconds="$2"
            shift 2
            ;;
        --build-timeout)
            [ "$#" -ge 2 ] || { print_usage; exit 2; }
            build_timeout_seconds="$2"
            shift 2
            ;;
        --)
            shift
            test_arguments=("$@")
            break
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown option: $1" >&2
            print_usage
            exit 2
            ;;
    esac
done

if ! is_positive_integer "$repeats"; then
    echo "ERROR: repeats must be a positive integer" >&2
    exit 2
fi
validate_timeout "timeout" "$timeout_seconds"
validate_timeout "build-timeout" "$build_timeout_seconds"

artifact_root="$PWD/.test-artifacts/hang-guard"
lock_dir="$artifact_root/.lock"
mkdir -p "$artifact_root" || {
    echo "ERROR: cannot create diagnostics directory: $artifact_root" >&2
    exit 2
}

lock_owned=0
acquire_lock() {
    if mkdir "$lock_dir" 2>/dev/null; then
        printf '%s\n' "$$" > "$lock_dir/pid"
        lock_owned=1
        return 0
    fi

    local owner_pid=""
    if [ -f "$lock_dir/pid" ]; then
        owner_pid="$(<"$lock_dir/pid")"
    fi
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
        rm -rf "$lock_dir"
        if mkdir "$lock_dir" 2>/dev/null; then
            printf '%s\n' "$$" > "$lock_dir/pid"
            lock_owned=1
            return 0
        fi
    fi

    if [ -n "$owner_pid" ]; then
        echo "ERROR: another swift test hang-guard is active (pid $owner_pid)" >&2
    else
        echo "ERROR: another swift test hang-guard is active (lock: $lock_dir)" >&2
    fi
    exit 3
}

release_lock() {
    if [ "$lock_owned" -eq 1 ]; then
        rm -rf "$lock_dir"
    fi
}
trap release_lock EXIT INT TERM
acquire_lock

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
run_directory="$artifact_root/$(date -u '+%Y%m%dT%H%M%SZ')-$$"
mkdir -p "$run_directory" || {
    echo "ERROR: cannot create run diagnostics directory: $run_directory" >&2
    exit 2
}

helper_pids() {
    pgrep -f '[s]wiftpm-testing-helper' 2>/dev/null || true
}

pid_was_present() {
    local pid="$1"
    local baseline="$2"
    case " $baseline " in
        *" $pid "*) return 0 ;;
        *) return 1 ;;
    esac
}

write_diagnostics() {
    local run_number="$1"
    local reason="$2"
    local log_file="$run_directory/run-$run_number.log"
    local diagnostics_file="$run_directory/run-$run_number.diag.txt"

    {
        echo "reason: $reason"
        echo "working directory: $PWD"
        echo "timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "log: $log_file"
        echo "active Swift-related processes:"
        ps -axo pid=,ppid=,stat=,command= | awk '/swift|swiftpm-testing-helper/ { print }'
        echo "swiftpm-testing-helper processes:"
        helper_pids
        if [ -e ".build/.lock" ]; then
            echo ".build/.lock exists"
        else
            echo ".build/.lock is absent"
        fi
    } > "$diagnostics_file"
    echo "ERROR: run $run_number failed: $reason" >&2
    echo "ERROR: diagnostics: $diagnostics_file" >&2
    if [ -f "$log_file" ]; then
        echo "ERROR: last 80 log lines:" >&2
        tail -n 80 "$log_file" >&2 || true
    fi
}

run_once() {
    local run_number="$1"
    local run_timeout="$2"
    local log_file="$run_directory/run-$run_number.log"
    local baseline_helpers
    local current_helper_pid
    local stale_helpers=""
    local test_status

    baseline_helpers="$(helper_pids | tr '\n' ' ')"
    echo "Running guarded Swift test $run_number/$repeats (timeout: ${run_timeout}s)"
    if [ "${#test_arguments[@]}" -eq 0 ]; then
        bash "$script_directory/swift-test-timeout.sh" "$run_timeout" > "$log_file" 2>&1
    else
        bash "$script_directory/swift-test-timeout.sh" "$run_timeout" -- "${test_arguments[@]}" > "$log_file" 2>&1
    fi
    test_status=$?

    for current_helper_pid in $(helper_pids); do
        if ! pid_was_present "$current_helper_pid" "$baseline_helpers"; then
            stale_helpers="$stale_helpers $current_helper_pid"
        fi
    done
    stale_helpers="${stale_helpers# }"

    if [ "$test_status" -ne 0 ]; then
        write_diagnostics "$run_number" "swift test exited with status $test_status"
        return 1
    fi
    if [ -n "$stale_helpers" ]; then
        write_diagnostics "$run_number" "stale swiftpm-testing-helper process(es):$stale_helpers"
        return 1
    fi
    return 0
}

for run_number in $(seq 1 "$repeats"); do
    if [ "$run_number" -eq 1 ]; then
        run_timeout="$build_timeout_seconds"
    else
        run_timeout="$timeout_seconds"
    fi
    if ! run_once "$run_number" "$run_timeout"; then
        exit 1
    fi
done

echo "OK: $repeats guarded runs completed without timeout or stale helper"
