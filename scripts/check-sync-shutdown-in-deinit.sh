#!/usr/bin/env bash

set -uo pipefail

if [ "$#" -eq 0 ]; then
    echo "Usage: scripts/check-sync-shutdown-in-deinit.sh <source-or-test-path>..." >&2
    exit 2
fi

for input_path in "$@"; do
    if [ ! -e "$input_path" ]; then
        echo "ERROR: path does not exist: $input_path" >&2
        exit 2
    fi
done

scan_file() {
    local file_path="$1"

    awk '
        BEGIN {
            in_deinit = 0
            brace_depth = 0
            violation = 0
        }
        {
            if (!in_deinit && $0 ~ /(^|[[:space:]])deinit[[:space:]]*\{/) {
                in_deinit = 1
                deinit_line = FNR
                brace_depth = 0
            }
            if (in_deinit && $0 ~ /(syncShutdownGracefully|shutdownSynchronously|synchronousShutdown|DispatchSemaphore|semaphore[.]wait|dispatchGroup[.]wait|dispatch_group_wait|[.]wait\(\))/) {
                printf "%s:%d: synchronous shutdown or wait in deinit: %s\n", FILENAME, FNR, $0
                violation = 1
            }
            if (in_deinit) {
                opening = gsub(/\{/, "{", $0)
                closing = gsub(/\}/, "}", $0)
                brace_depth += opening - closing
                if (brace_depth <= 0) {
                    in_deinit = 0
                    brace_depth = 0
                }
            }
        }
        END {
            exit violation
        }
    ' "$file_path"
}

violation=0
for input_path in "$@"; do
    if [ -f "$input_path" ]; then
        case "$input_path" in
            *.swift) scan_file "$input_path" || violation=1 ;;
        esac
        continue
    fi

    while IFS= read -r -d '' file_path; do
        scan_file "$file_path" || violation=1
    done < <(find "$input_path" -type f -name '*.swift' -print0)
done

if [ "$violation" -ne 0 ]; then
    echo "ERROR: synchronous shutdown in deinit was detected" >&2
    exit 1
fi

echo "OK: no synchronous shutdown in deinit found"
