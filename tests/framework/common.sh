# framework/common.sh — TAP result primitives
# Every assertion records a structured marker into a per-test log file. The
# runner (execution.sh) parses those markers to emit TAP and, crucially,
# reconciles a *plan* of declared functions against the functions that actually
# reported — so a function that silently exits can never turn into a phantom
# green test.

GIM_TEST_LOG="${GIM_TEST_LOG:-}"

# Append one structured marker to the current test's log.
__record() {
  local kind="$1" msg="$2"
  if [ -n "$GIM_TEST_LOG" ]; then
    printf '%s\t%s\n' "$kind" "$msg" >> "$GIM_TEST_LOG"
  fi
}

pass()  { __record "PASS" "${1:-}"; }
fail()  { __record "FAIL" "${1:-}"; }
skip()  { __record "SKIP" "${1:-}"; }
todo()  { __record "TODO" "${1:-}"; }

bail_out() {
  printf 'Bail out! %s\n' "${1:-unknown reason}" >&2
  exit 1
}

# --- Small shared utilities -------------------------------------------------

# True if the given value is non-empty.
is_set() { [ -n "${1:-}" ]; }

# Glob-safe membership: is needle present, one per line, in haystack?
line_includes() {
  local haystack="$1" needle="$2"
  printf '%s\n' "$haystack" | grep -Fxq -- "$needle"
}
