# framework/logging.sh — human-facing test progress on stderr
# These are NOT TAP markers; they never pollute the machine-readable stream.

_log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*" >&2
}

log_test_step() { _log "STEP" "$*"; }
log_debug()     { [ "${GIM_TEST_VERBOSE:-0}" = "1" ] && _log "DEBUG" "$*"; return 0; }
log_error()     { _log "ERROR" "$*"; }
log_warn()      { _log "WARN" "$*"; }
