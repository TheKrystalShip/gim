#!/usr/bin/env bash
# integration/test_run.sh — run_editor: latest selection, explicit version,
# mono auto-detect, mono flag, invocation recording, and the B4 log-label fix.

function test_run_latest_picks_newest() {
  make_fake_editor "4.1.0-stable" >/dev/null
  make_fake_editor "4.3.0-stable" >/dev/null
  run_gim run
  assert_exit_code 0 "run (latest) exits 0"
  # run_editor backgrounds the binary, so wait for the invocation to be logged.
  wait_for_editor_run
  assert_file_exists "$GIM_EDITOR_RUN_LOG" "run log created"
  local log
  log=$(cat "$GIM_EDITOR_RUN_LOG")
  assert_not_null "$log" "editor was actually invoked"
  assert_stderr_contains "Running latest editor: 4.3.0" "log names the latest version"
}

function test_run_explicit_logs_resolved_version() {
  # B4: `gim run 4.7` must name the resolved editor, not a bare "Running editor".
  make_fake_editor "4.7.2-stable" >/dev/null
  run_gim run 4.7
  assert_exit_code 0 "run 4.7 exits 0"
  assert_stderr_contains "Running editor: 4.7.2" "log names the resolved version"
  # Guard against regression to the bare string with no version (regex).
  assert_matches "$GIM_STDERR" "Running editor: [0-9]" "version is numeric (not the bare word)"
}

function test_run_explicit_does_not_say_latest() {
  make_fake_editor "4.7.2-stable" >/dev/null
  run_gim run 4.7
  assert_not_contains "$GIM_STDERR" "latest editor" "explicit run is not labelled latest"
}

function test_run_latest_still_says_latest() {
  make_fake_editor "4.7.2-stable" >/dev/null
  run_gim run
  assert_stderr_contains "Running latest editor: 4.7.2" "latest run keeps its label"
}

function test_run_mono_autodetect() {
  # A mono build's --version contains ".mono."; plain run must auto-select it.
  make_fake_editor "4.5.0-stable" --mono >/dev/null
  run_gim run
  assert_exit_code 0 "run picks mono build"
  assert_stderr_contains "Running latest editor: 4.5.0.stable.mono" "mono auto-detected"
}

function test_run_mono_flag_selects_mono() {
  make_fake_editor "4.5.0-stable" >/dev/null
  make_fake_editor "4.5.0-stable" --mono >/dev/null
  run_gim run 4.5 -m
  assert_exit_code 0 "run -m exits 0"
  wait_for_editor_run
  local log
  log=$(cat "$GIM_EDITOR_RUN_LOG")
  assert_not_null "$log" "editor invoked"
}

function test_run_explicit_falls_back_to_mono_and_names_it() {
  # B4 + fallback: only a mono build installed, `gim run 4.7` (no -m) should
  # fall back to mono AND name the mono build it launched.
  make_fake_editor "4.7.2-stable" --mono >/dev/null
  run_gim run 4.7
  assert_exit_code 0 "run falls back to mono"
  assert_stderr_contains "using mono build" "fallback message shown"
  assert_stderr_contains "Running editor: 4.7.2.stable.mono" "log names the mono build actually launched"
}

function test_run_no_editors_errors() {
  run_gim run
  assert_exit_code 1 "run with nothing installed exits 1"
  assert_stderr_contains "No Godot editors found" "clear error"
}

function test_run_missing_version_errors() {
  run_gim run 9.9
  assert_exit_code 1 "run <missing> exits 1"
}
