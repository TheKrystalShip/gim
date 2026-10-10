#!/usr/bin/env bash
# tests/run.sh — TAP-producing test runner for GIM.
#
# Usage:
#   ./tests/run.sh                      # run everything
#   ./tests/run.sh unit                 # only unit tests
#   ./tests/run.sh integration          # only integration tests
#   ./tests/run.sh --pattern '*version*'    # only files matching glob
#   ./tests/run.sh --function version_gt    # only tests whose name matches
#   ./tests/run.sh --list               # list discovered tests, don't run
#
# Exit code: 0 if all tests passed, 1 otherwise.

set -uo pipefail

RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=framework/bootstrap.sh
source "$RUNNER_DIR/framework/bootstrap.sh"

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- Argument parsing -------------------------------------------------------
TIER="all"
PATTERN=""
FUNCTION_FILTER=""
LIST_ONLY=0
TIMEOUT="${GIM_TEST_TIMEOUT:-30}"

while [ $# -gt 0 ]; do
  case "$1" in
    unit|integration) TIER="$1"; shift ;;
    --pattern) PATTERN="${2:-}"; shift 2 ;;
    --function) FUNCTION_FILTER="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-30}"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# --- Discovery --------------------------------------------------------------
declare -a test_files=()
discover() {
  local dir="$RUNNER_DIR/$TIER"
  [ "$TIER" = "all" ] && dir="$RUNNER_DIR"
  local f
  # shellcheck disable=SC2044
  for f in $(find "$dir" -type f -name 'test_*.sh' | sort); do
    if [ -n "$PATTERN" ]; then
      # shellcheck disable=SC2254
      case "$(basename "$f")" in
        $PATTERN) ;;
        *) continue ;;
      esac
    fi
    test_files+=("$f")
  done
}
discover

if [ "${#test_files[@]}" -eq 0 ]; then
  echo "No test files found (tier=$TIER pattern='${PATTERN:-}')" >&2
  exit 1
fi

if [ "$LIST_ONLY" = "1" ]; then
  for f in "${test_files[@]}"; do
    echo "== $(basename "$f")"
    discover_test_functions "$f" | sed 's/^/  /'
  done
  exit 0
fi

# --- Plan: pre-count tests so the TAP plan line is accurate -----------------
declare -a planned_files=()
total=0
for f in "${test_files[@]}"; do
  names="$(discover_test_functions "$f")"
  if [ -n "$FUNCTION_FILTER" ]; then
    names="$(printf '%s\n' "$names" | grep -E -- "$FUNCTION_FILTER" || true)"
  fi
  n="$(printf '%s' "$names" | grep -c . || true)"
  if [ "${n:-0}" -gt 0 ]; then
    planned_files+=("$f")
    total=$((total + n))
  fi
done

if [ "$total" -eq 0 ]; then
  echo "No tests matched (tier=$TIER pattern='${PATTERN:-}' function='${FUNCTION_FILTER:-}')" >&2
  exit 1
fi

# --- Run --------------------------------------------------------------------
LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/gim-test-logs.XXXXXX")"
trap 'cleanup' EXIT

cleanup() {
  if [ "${GIM_TEST_KEEP_SANDBOX:-0}" != "1" ]; then
    rm -rf "$LOGDIR"
  else
    echo "Logs kept at: $LOGDIR" >&2
  fi
}

# TAP header + plan.
echo "TAP version 14"
echo "1..$total"

TAP_INDEX=1
GIM_TEST_TOTAL=0
GIM_TEST_FAILED=0

for f in "${planned_files[@]}"; do
  # Per-file sandbox: create shims/env, run the file, tear down. Each file runs
  # in its OWN subshell so sourced functions/vars never leak between files, but
  # TAP output is captured so the parent can keep a continuous index and counts.
  file_out="$LOGDIR/$(basename "$f" .sh).tap"
  (
    create_sandbox
    mocks_install
    export GIM_TEST_FUNCTION_FILTER="$FUNCTION_FILTER"
    export TAP_INDEX
    run_test_file "$f" "$LOGDIR"
    destroy_sandbox
  ) > "$file_out"

  cat "$file_out"
  # Advance the shared index and tally from the emitted TAP lines.
  n_run="$(grep -cE '^(ok|not ok) ' "$file_out" || true)"
  n_fail="$(grep -cE '^not ok ' "$file_out" || true)"
  GIM_TEST_TOTAL=$((GIM_TEST_TOTAL + n_run))
  GIM_TEST_FAILED=$((GIM_TEST_FAILED + n_fail))
  TAP_INDEX=$((TAP_INDEX + n_run))
done

# --- Summary ----------------------------------------------------------------
if [ "$GIM_TEST_FAILED" -gt 0 ]; then
  echo "# FAILED $GIM_TEST_FAILED of $GIM_TEST_TOTAL tests" >&2
  exit 1
fi
echo "# passed $GIM_TEST_TOTAL/$GIM_TEST_TOTAL tests" >&2
exit 0
