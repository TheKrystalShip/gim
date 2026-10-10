# framework/execution.sh — run one test file: source, hooks, reconcile, TAP
#
# The core safety property (borrowed from KGSM): a *plan* of declared test
# functions is captured BEFORE the file is sourced, then every planned function
# must report a result. A function that calls `exit` (GIM helpers do) or dies
# mid-body is reconciled into an explicit FAIL — never a silent pass.
#
# Isolation model: gim.sh and the test file are sourced in the PARENT process
# (safe because gim.sh has a main guard and test files only define functions),
# but each individual test_* body runs in its OWN subshell so a bare `exit`
# inside a helper cannot kill the runner or leak state between tests.
# Counters therefore live in the parent and are trustworthy.

# run_gim <args...> — invoke gim.sh as a subprocess in the sandbox, capturing
# stdout/stderr/exit code into GIM_STDOUT / GIM_STDERR / GIM_RC. Assertions
# that read those globals (assert_exit_code, assert_stdout_contains, ...) rely
# on this. stdin is /dev/null so interactive prompts see EOF.
run_gim() {
  local out_file="$SANDBOX/.stdout" err_file="$SANDBOX/.stderr"
  GIM_STDOUT=""
  GIM_STDERR=""
  GIM_RC=0
  bash "$GIM_SCRIPT" "$@" > "$out_file" 2> "$err_file" < /dev/null
  GIM_RC=$?
  GIM_STDOUT="$(cat "$out_file")"
  GIM_STDERR="$(cat "$err_file")"
}

# run_gim_stdin <input> <args...> — as run_gim but feeds <input> to stdin
# (for interactive prompts like delete's y/N confirm).
run_gim_stdin() {
  local input="$1"; shift
  local out_file="$SANDBOX/.stdout" err_file="$SANDBOX/.stderr"
  GIM_STDOUT=""
  GIM_STDERR=""
  GIM_RC=0
  printf '%s' "$input" | bash "$GIM_SCRIPT" "$@" > "$out_file" 2> "$err_file"
  GIM_RC=$?
  GIM_STDOUT="$(cat "$out_file")"
  GIM_STDERR="$(cat "$err_file")"
}

# run_gim_eval <snippet> — source gim.sh in a subshell and run an arbitrary
# snippet against it, capturing stdout/stderr/exit code. Used by unit tests to
# exercise individual helpers in isolation.
run_gim_eval() {
  local snippet="$1"
  local out_file="$SANDBOX/.stdout" err_file="$SANDBOX/.stderr"
  GIM_STDOUT=""
  GIM_STDERR=""
  GIM_RC=0
  bash -c "source '$GIM_SCRIPT'; $snippet" > "$out_file" 2> "$err_file" < /dev/null
  GIM_RC=$?
  GIM_STDOUT="$(cat "$out_file")"
  GIM_STDERR="$(cat "$err_file")"
}

# discover_test_functions <file> — echo test_* names in declaration order.
discover_test_functions() {
  grep -E '^[[:space:]]*(function[[:space:]]+)?test_[A-Za-z0-9_]+[[:space:]]*(\(\))?[[:space:]]*\{' "$1" 2>/dev/null \
    | sed -E 's/^[[:space:]]*(function[[:space:]]+)?(test_[A-Za-z0-9_]+).*/\2/'
}

# run_test_file <file> <logdir> — execute a file, emit one TAP point per test.
# Prints TAP lines to stdout. Increments GIM_TEST_TOTAL / GIM_TEST_FAILED.
run_test_file() {
  local file="$1" logdir="$2"
  local fname; fname="$(basename "$file" .sh)"

  # --- PLAN: capture declared functions BEFORE sourcing ---
  local -a plan=()
  mapfile -t plan < <(discover_test_functions "$file")

  # Apply --function filter (regex) if provided.
  if [ -n "${GIM_TEST_FUNCTION_FILTER:-}" ]; then
    local -a filtered=()
    local _n
    for _n in "${plan[@]}"; do
      if printf '%s' "$_n" | grep -Eq -- "$GIM_TEST_FUNCTION_FILTER"; then
        filtered+=("$_n")
      fi
    done
    plan=("${filtered[@]}")
  fi

  if [ "${#plan[@]}" -eq 0 ]; then
    log_error "no test_* functions discovered in $file"
    return 1
  fi

  local file_log="$logdir/$fname.file.log"
  : > "$file_log"
  export GIM_TEST_LOG="$file_log"

  # Source gim.sh in the parent (main guard prevents the CLI from running).
  # shellcheck source=/dev/null
  if ! source "$GIM_SCRIPT"; then
    log_error "failed to source $GIM_SCRIPT"
    __reconcile_missing "$fname" "${plan[@]}"
    return 1
  fi

  # Source the test file (defines setup/teardown + test_* functions).
  # shellcheck source=/dev/null
  if ! source "$file"; then
    log_error "failed to source $file"
    __reconcile_missing "$fname" "${plan[@]}"
    return 1
  fi

  # setup_file — once, before any test. Isolated so a bare exit is contained.
  if declare -F setup_file >/dev/null; then
    if ! ( set +e; setup_file ) >> "$file_log" 2>&1; then
      log_warn "setup_file failed for $fname (continuing)"
    fi
  fi

  local name
  for name in "${plan[@]}"; do
    __run_one_test "$fname" "$name" "$logdir"
  done

  # teardown_file — once, after all tests.
  if declare -F teardown_file >/dev/null; then
    ( set +e; teardown_file ) >> "$file_log" 2>&1 || true
  fi

  return 0
}

# __run_one_test <fname> <name> <logdir> — run one test, emit its TAP point.
__run_one_test() {
  local fname="$1" name="$2" logdir="$3"
  local test_log="$logdir/$fname.$name.log"
  : > "$test_log"
  export GIM_TEST_LOG="$test_log"

  # Per-test hermetic state: clear installed editors + cache so nothing leaks
  # between tests sharing the same file-level sandbox.
  reset_gim_state

  # setup — before each test (isolated).
  if declare -F setup >/dev/null; then
    ( set +e; setup ) >> "$test_log" 2>&1
  fi

  # Run the test body in its OWN subshell so `exit` is contained. Capture
  # stdout+stderr to the test log for diagnostics.
  local test_rc=0
  ( set +e; "$name"; exit $? ) >> "$test_log" 2>&1
  test_rc=$?

  # teardown — after each test (isolated).
  if declare -F teardown >/dev/null; then
    ( set +e; teardown ) >> "$test_log" 2>&1
  fi

  # Aggregate PASS/FAIL/SKIP markers into one TAP point.
  local passes fails skips
  passes=$(grep -c '^PASS' "$test_log" 2>/dev/null); passes=${passes:-0}
  fails=$(grep -c '^FAIL' "$test_log" 2>/dev/null);  fails=${fails:-0}
  skips=$(grep -c '^SKIP' "$test_log" 2>/dev/null);  skips=${skips:-0}

  local failed=0
  if [ "$fails" -gt 0 ]; then
    failed=1
    printf 'not ok %d - %s::%s\n' "$TAP_INDEX" "$fname" "$name"
    grep '^FAIL' "$test_log" | sed 's/^FAIL/    # FAIL/' || true
  elif [ "$test_rc" -ne 0 ] && [ "$passes" -eq 0 ] && [ "$skips" -eq 0 ]; then
    # Reconciliation: exited non-zero WITHOUT recording a result (bare `exit`).
    failed=1
    printf 'not ok %d - %s::%s\n' "$TAP_INDEX" "$fname" "$name"
    printf '    # FAIL: test exited with code %d before recording a result (possible bare exit)\n' "$test_rc"
  elif [ "$passes" -eq 0 ] && [ "$skips" -eq 0 ]; then
    # Reconciliation: declared but recorded nothing.
    failed=1
    printf 'not ok %d - %s::%s\n' "$TAP_INDEX" "$fname" "$name"
    printf '    # FAIL: test recorded no result (planned but produced no PASS/FAIL/SKIP)\n'
  elif [ "$skips" -gt 0 ]; then
    printf 'ok %d - %s::%s # SKIP %s\n' "$TAP_INDEX" "$fname" "$name" \
      "$(grep -m1 '^SKIP' "$test_log" | sed 's/^SKIP: \{0,1\}//')"
  else
    printf 'ok %d - %s::%s\n' "$TAP_INDEX" "$fname" "$name"
  fi

  TAP_INDEX=$((TAP_INDEX + 1))
  GIM_TEST_TOTAL=$((GIM_TEST_TOTAL + 1))
  if [ "$failed" -ne 0 ]; then
    GIM_TEST_FAILED=$((GIM_TEST_FAILED + 1))
  fi
}

# __reconcile_missing <fname> <names...> — emit a FAIL point for each planned
# test that could not run (used when sourcing the file or gim.sh fails).
__reconcile_missing() {
  local fname="$1"; shift
  local name
  for name in "$@"; do
    printf 'not ok %d - %s::%s\n' "$TAP_INDEX" "$fname" "$name"
    printf '    # FAIL: could not run (file failed to load)\n'
    TAP_INDEX=$((TAP_INDEX + 1))
    GIM_TEST_TOTAL=$((GIM_TEST_TOTAL + 1))
    GIM_TEST_FAILED=$((GIM_TEST_FAILED + 1))
  done
}
