#!/usr/bin/env bash
# integration/test_help_and_version.sh — top-level CLI surface: -h/-v/no-args,
# unknown command, missing VERSION, and combined-flag decomposition.

function test_help_flag_exits_zero() {
  run_gim -h
  assert_exit_code 0 "-h exits 0"
  assert_stdout_contains "Godot Install Manager" "-h prints the title to stdout"
  assert_stdout_contains "Usage: gim <command>" "-h prints usage"
}

function test_help_long_flag() {
  run_gim --help
  assert_exit_code 0 "--help exits 0"
  assert_stdout_contains "Usage: gim <command>" "--help prints usage"
}

function test_no_args_prints_help() {
  run_gim
  assert_exit_code 0 "no args exits 0"
  assert_stdout_contains "Usage: gim <command>" "no args prints usage"
}

function test_version_flag() {
  run_gim -v
  assert_exit_code 0 "-v exits 0"
  assert_stdout_contains "GIM" "-v prints short name"
}

function test_version_long_flag() {
  run_gim --version
  assert_exit_code 0 "--version exits 0"
}

function test_unknown_command_errors() {
  run_gim frobnicate
  assert_exit_code 1 "unknown command exits 1"
  assert_stderr_contains "Unknown command 'frobnicate'" "names the bad command"
  assert_stderr_contains "Run 'gim --help'" "points at --help"
}

function test_install_requires_version_arg() {
  run_gim install
  assert_exit_code 1 "install without VERSION exits 1"
  assert_stderr_contains "install requires a VERSION argument" "clear error message"
}

function test_delete_requires_version_arg() {
  run_gim delete
  assert_exit_code 1 "delete without VERSION exits 1"
  assert_stderr_contains "delete requires a VERSION argument" "clear error message"
}

function test_unknown_option_errors() {
  run_gim list -z
  assert_exit_code 1 "unknown option exits 1"
  assert_stderr_contains "Unknown option '-z'" "names the bad option"
}

function test_combined_flag_equivalence() {
  # list -oe must behave identically to list -o -e.
  local out_a out_b
  run_gim list -oe
  out_a="$GIM_STDOUT"
  run_gim list -o -e
  out_b="$GIM_STDOUT"
  assert_equals "$out_a" "$out_b" "list -oe == list -o -e"
}
