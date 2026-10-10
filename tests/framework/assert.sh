# framework/assert.sh — assertions
# Each assertion records PASS/FAIL (via common.sh) with a descriptive message.
# The runner aggregates markers per test function into a single TAP point.
#
# Assertions that operate on a command's output read the GIM_STDOUT /
# GIM_STDERR / GIM_RC globals set by run_gim / run_gim_eval (execution.sh).

__msg_or() { # __msg_or <provided> <default>
  if [ -n "${1:-}" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi
}

# --- Equality ---------------------------------------------------------------

assert_equals() { # <expected> <actual> [msg]
  local expected="$1" actual="$2"
  local msg; msg=$(__msg_or "${3:-}" "expected '$expected', got '$actual'")
  if [ "$expected" = "$actual" ]; then pass "$msg"; else fail "$msg (expected '$expected', got '$actual')"; fi
}

assert_not_equals() { # <unexpected> <actual> [msg]
  local unexpected="$1" actual="$2"
  local msg; msg=$(__msg_or "${3:-}" "value should not be '$unexpected'")
  if [ "$unexpected" != "$actual" ]; then pass "$msg"; else fail "$msg (got '$actual')"; fi
}

# --- Null / emptiness -------------------------------------------------------

assert_null() { # <value> [msg]
  local msg; msg=$(__msg_or "${2:-}" "value is empty")
  if [ -z "${1:-}" ]; then pass "$msg"; else fail "$msg (got '$1')"; fi
}

assert_not_null() { # <value> [msg]
  local msg; msg=$(__msg_or "${2:-}" "value is non-empty")
  if [ -n "${1:-}" ]; then pass "$msg"; else fail "$msg (expected non-empty)"; fi
}

# --- Substring / regex ------------------------------------------------------

assert_contains() { # <haystack> <needle> [msg]
  local haystack="$1" needle="$2"
  local msg; msg=$(__msg_or "${3:-}" "output contains '$needle'")
  case "$haystack" in
    *"$needle"*) pass "$msg" ;;
    *) fail "$msg (missing '$needle' in: $haystack)" ;;
  esac
}

assert_not_contains() { # <haystack> <needle> [msg]
  local haystack="$1" needle="$2"
  local msg; msg=$(__msg_or "${3:-}" "output does not contain '$needle'")
  case "$haystack" in
    *"$needle"*) fail "$msg (found '$needle' in: $haystack)" ;;
    *) pass "$msg" ;;
  esac
}

assert_matches() { # <value> <regex> [msg]
  local value="$1" regex="$2"
  local msg; msg=$(__msg_or "${3:-}" "value matches /$regex/")
  if printf '%s' "$value" | grep -Eq -- "$regex"; then pass "$msg"; else fail "$msg (value '$value' does not match /$regex/)"; fi
}

# --- Filesystem -------------------------------------------------------------

assert_file_exists() { # <path> [msg]
  local msg; msg=$(__msg_or "${2:-}" "file exists: $1")
  if [ -f "$1" ]; then pass "$msg"; else fail "$msg"; fi
}

assert_file_not_exists() { # <path> [msg]
  local msg; msg=$(__msg_or "${2:-}" "file does not exist: $1")
  if [ ! -f "$1" ]; then pass "$msg"; else fail "$msg"; fi
}

assert_dir_exists() { # <path> [msg]
  local msg; msg=$(__msg_or "${2:-}" "dir exists: $1")
  if [ -d "$1" ]; then pass "$msg"; else fail "$msg"; fi
}

assert_dir_not_exists() { # <path> [msg]
  local msg; msg=$(__msg_or "${2:-}" "dir does not exist: $1")
  if [ ! -d "$1" ]; then pass "$msg"; else fail "$msg"; fi
}

assert_file_executable() { # <path> [msg]
  local msg; msg=$(__msg_or "${2:-}" "file is executable: $1")
  if [ -x "$1" ]; then pass "$msg"; else fail "$msg"; fi
}

# --- Commands ---------------------------------------------------------------

assert_command_succeeds() { # <cmd> [args...]
  local msg="command succeeds: $*"
  if "$@" >/dev/null 2>&1; then pass "$msg"; else fail "$msg (exit $?)"; fi
}

assert_command_fails() { # <cmd> [args...]
  local msg="command fails: $*"
  if "$@" >/dev/null 2>&1; then fail "$msg (unexpectedly succeeded)"; else pass "$msg"; fi
}

# --- Exit code --------------------------------------------------------------
# Reads GIM_RC (set by run_gim / run_gim_eval).

assert_exit_code() { # <expected> [msg]
  local msg; msg=$(__msg_or "${2:-}" "exit code == $1")
  if [ "${GIM_RC:-}" = "$1" ]; then pass "$msg"; else fail "$msg (got ${GIM_RC:-unset}; stderr: ${GIM_STDERR:-})"; fi
}

# --- Output-routing invariant (stdout = data, stderr = logs) ----------------
# Encodes CLAUDE.md:28-35. assert_stdout_only pins that a value is emitted on
# stdout and NOT echoed to stderr; assert_stderr_contains pins log/error text.

assert_stdout_only() { # <value> [msg]  — value on stdout, absent from stderr
  local value="$1"
  local msg; msg=$(__msg_or "${2:-}" "'$value' goes to stdout only")
  if [[ "${GIM_STDOUT:-}" != *"$value"* ]]; then
    fail "$msg (missing from stdout: ${GIM_STDOUT:-})"
  elif [[ "${GIM_STDERR:-}" == *"$value"* ]]; then
    fail "$msg (also leaked to stderr: ${GIM_STDERR:-})"
  else
    pass "$msg"
  fi
}

assert_stderr_contains() { # <needle> [msg]
  local needle="$1"
  local msg; msg=$(__msg_or "${2:-}" "stderr contains '$needle'")
  if [[ "${GIM_STDERR:-}" == *"$needle"* ]]; then pass "$msg"; else fail "$msg (stderr was: ${GIM_STDERR:-})"; fi
}

assert_stdout_contains() { # <needle> [msg]
  local needle="$1"
  local msg; msg=$(__msg_or "${2:-}" "stdout contains '$needle'")
  if [[ "${GIM_STDOUT:-}" == *"$needle"* ]]; then pass "$msg"; else fail "$msg (stdout was: ${GIM_STDOUT:-})"; fi
}

assert_stderr_empty() { # [msg]
  local msg; msg=$(__msg_or "${1:-}" "stderr is empty")
  if [ -z "${GIM_STDERR:-}" ]; then pass "$msg"; else fail "$msg (stderr was: $GIM_STDERR)"; fi
}
